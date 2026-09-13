//
//  MenuService.swift
//  RClick
//
//  菜单配置构建服务：从 AppState 生成发往 Finder Extension 的 MenuConfigPayload。
//  版本号在这里维护，用于防重复和防乱序。
//

import Foundation
import OSLog

/// What the settings page reports about the custom menu.
///
/// Two axes rather than one, because the menu and the file can disagree: an
/// external editor can change the file without it taking effect, and a change in
/// Settings can invalidate an applied file without the file itself changing.
struct CustomMenuStatus: Equatable {
    /// What the Finder menu is rendering right now.
    enum Applied: Equatable {
        /// The App Group container is unavailable (signing or entitlement problem).
        case unavailable
        /// The default categorized layout. Not a problem.
        case defaultLayout
        /// An empty array is in effect: an intentionally empty menu. Not a problem.
        case empty
        /// In effect, carrying the number of top-level entries.
        case custom(topLevelItems: Int)
    }

    /// How the file on disk relates to what is in effect.
    enum Notice: Equatable {
        /// Nothing to report.
        case none
        /// Edited since it was applied, so the menu still shows the old layout.
        case edited
        /// Unusable: it does not parse, or no longer matches the enabled items.
        case broken(reason: String)
    }

    var applied: Applied
    var notice: Notice

    /// Whether this state is worth flagging as something going wrong.
    ///
    /// `.edited` is deliberately not one: an edit waiting to be applied is the
    /// normal working state this whole screen is built around, not a fault.
    var isProblem: Bool {
        if applied == .unavailable { return true }
        if case .broken = notice { return true }
        return false
    }
}

@MainActor
final class MenuService {
    /// 菜单版本号（防重复 / 防乱序）
    private var menuVersion = 0

    /// Bytes of the custom menu currently in effect; `nil` means the default layout.
    ///
    /// Raw bytes rather than resolved nodes, because `AppState` keeps moving
    /// underneath: disabling an app, or turning common folders off, empties part of
    /// the payload and the layout has to be re-resolved against it. Bytes also turn
    /// "has the file been edited since?" into a comparison instead of a re-read.
    private var appliedCustomMenuData: Data?

    /// Separate from the data being `nil`, because "nothing is applied" must not
    /// re-read the disk on every one of the three build triggers.
    private var hasLoadedAppliedCustomMenu = false

    /// Copy kept beside the live file when the custom layout is removed.
    static let customMenuBackupName = "custom_menu.backup.json"

    /// The file the menu is built from. `nil` means there is no container at all,
    /// so the default layout always applies.
    ///
    /// Explicitly injectable so tests can point at a temporary file: nothing in this
    /// type may reach the real App Group container while a test runs. There is
    /// deliberately no default argument, because `nil` is a meaningful value here
    /// and would otherwise be indistinguishable from "use the real container".
    let customMenuURL: URL?

    init(customMenuURL: URL?) {
        self.customMenuURL = customMenuURL
    }

    /// The real location, in the shared App Group container.
    static var defaultCustomMenuURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.suitName)?
            .appendingPathComponent("custom_menu.json")
    }

    /// Seed only once, using configured IDs so the example works on this installation.
    static func prepareCustomMenu(at url: URL, config: MenuConfigPayload) throws {
        if FileManager.default.fileExists(atPath: url.path) { return }
        var nodes = config.apps.map { MenuNode(type: .item, itemType: .app, id: $0.id) }
        nodes += config.actions.map { MenuNode(type: .item, itemType: .action, id: $0.id) }
        var groups: [MenuNode] = []
        if !config.newFiles.isEmpty {
            groups.append(MenuNode(type: .submenu, title: AppLocalization.localized("New File"),
                                   icon: "doc.badge.plus", children: config.newFiles.map {
                MenuNode(type: .item, itemType: .newFile, id: $0.id)
            }))
        }
        if !config.commonDirs.isEmpty {
            groups.append(MenuNode(type: .submenu, title: AppLocalization.localized("Common Dirs"),
                                   icon: "folder", children: config.commonDirs.map {
                MenuNode(type: .item, itemType: .commonDir, id: $0.id)
            }))
        }
        nodes.append(MenuNode(type: .submenu, title: AppLocalization.localized("More"),
                              icon: "ellipsis.circle", children: groups))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(nodes)
        do {
            // Exclusive creation also protects edits if another writer wins the race.
            try data.write(to: url, options: .withoutOverwriting)
        } catch CocoaError.fileWriteFileExists {
            return
        }
    }

    /// Builds the payload from `AppState` without touching the version counter or
    /// the disk.
    ///
    /// Status checks use this so that merely inspecting the custom menu cannot
    /// perturb the configuration that gets sent to the extension.
    static func makePayload(from state: AppState, version: Int = 0) -> MenuConfigPayload {
        let actionMenuItems = state.actions.filter(\.enabled).map { $0.toActionMenuItem() }
        let appMenuItems = state.apps.map { $0.toAppMenuItem() }
        let newFileMenuItems = state.newFiles.filter(\.enabled).map { NewFileMenuItem(id: $0.id, name: $0.displayName, ext: $0.ext, icon: $0.icon) }
        let commonDirMenuItems = state.showCommonDirs ? state.cdirs.map { CommonDirMenuItem(id: $0.id, name: $0.displayName, icon: $0.icon, url: $0.url.path) } : []

        return MenuConfigPayload(
            version: version,
            actions: actionMenuItems,
            apps: appMenuItems,
            newFiles: newFileMenuItems,
            commonDirs: commonDirMenuItems,
            actionsCollapsed: state.foldActionsMenu,
            appsCollapsed: state.foldAppsMenu,
            newFilesCollapsed: state.foldNewFileMenu,
            commonDirsCollapsed: state.foldCommonDirMenu
        )
    }

    /// 从 AppState 实时构建菜单配置
    func buildConfig(from state: AppState) -> MenuConfigPayload {
        menuVersion += 1
        var config = Self.makePayload(from: state, version: menuVersion)
        config.customMenu = customMenu(for: config)
        return config
    }

    /// The custom layout to render for `config`, or `nil` for the default one.
    ///
    /// Takes the payload rather than reading `AppState`, so tests can drive it
    /// against a temporary file instead of the real SwiftData store.
    func customMenu(for config: MenuConfigPayload) -> [MenuNode]? {
        guard let data = currentAppliedCustomMenuData() else { return nil }
        do {
            return try CustomMenu.decode(data, config: config)
        } catch {
            // Fall back to the default layout, but keep the reason readable in the
            // log. `.private` because messages can quote user paths.
            Logger(subsystem: "RClick", category: "MenuService")
                .error("Invalid custom_menu.json; using default menu: \(CustomMenuDiagnostics.message(for: error), privacy: .private)")
            return nil
        }
    }

    /// The bytes to render from, or `nil` for the default layout.
    ///
    /// The file is read only on first use and when the user applies it. Edits made
    /// in an external editor are deliberately ignored until then, so a
    /// half-written file cannot take the menu down mid-edit. Deleting the file is
    /// the one exception: that is unambiguous and non-transient, so it still means
    /// "back to the default layout" right away.
    private func currentAppliedCustomMenuData() -> Data? {
        ensureAppliedCustomMenuLoaded()
        guard let url = customMenuURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return appliedCustomMenuData
    }

    // MARK: - Custom menu status

    /// Reports what the custom menu means for this installation right now.
    ///
    /// Takes the applied snapshot as a parameter rather than reading the property,
    /// so tests can drive it without an App Group container.
    static func customMenuStatus(at url: URL?, appliedData: Data?, config: MenuConfigPayload) -> CustomMenuStatus {
        guard let url else { return CustomMenuStatus(applied: .unavailable, notice: .none) }

        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch CocoaError.fileReadNoSuchFile {
            // No file, so nothing is in effect and there is nothing to apply.
            return CustomMenuStatus(applied: .defaultLayout, notice: .none)
        } catch {
            // Unreadable for some other reason - a folder where a file was expected,
            // say. That is not a missing file, and sending the user off to fix the
            // JSON syntax of something that has none would be a wrong turn.
            return CustomMenuStatus(applied: .defaultLayout,
                                    notice: .broken(reason: CustomMenuDiagnostics.message(for: error)))
        }

        // The snapshot only counts while the file is still there: deleting the file
        // is the documented way back to the default layout.
        var appliedReason: String?
        let applied: CustomMenuStatus.Applied
        if let appliedData {
            switch resolve(appliedData, config: config) {
            case .unusable(let reason):
                applied = .defaultLayout
                appliedReason = reason
            case .usable(let nodes):
                applied = nodes.isEmpty ? .empty : .custom(topLevelItems: nodes.count)
            }
        } else {
            applied = .defaultLayout
        }

        switch resolve(fileData, config: config) {
        case .unusable(let reason):
            return CustomMenuStatus(applied: applied, notice: .broken(reason: reason))
        case .usable:
            guard fileData == appliedData else {
                return CustomMenuStatus(applied: applied, notice: .edited)
            }
            // Same bytes. If they no longer resolve, the menu fell back anyway and
            // this reason is the only explanation the user is going to get.
            return CustomMenuStatus(applied: applied,
                                    notice: appliedReason.map { .broken(reason: $0) } ?? .none)
        }
    }

    func customMenuStatus(from state: AppState) -> CustomMenuStatus {
        ensureAppliedCustomMenuLoaded()
        return Self.customMenuStatus(at: customMenuURL,
                                     appliedData: appliedCustomMenuData,
                                     config: Self.makePayload(from: state))
    }

    /// Deliberately not named `.none`: that would shadow `Optional.none` and make
    /// every use site ambiguous.
    private enum Resolution {
        case unusable(reason: String)
        case usable([MenuNode])
    }

    private static func resolve(_ data: Data, config: MenuConfigPayload) -> Resolution {
        do {
            return .usable(try CustomMenu.decode(data, config: config))
        } catch {
            return .unusable(reason: CustomMenuDiagnostics.message(for: error))
        }
    }

    // MARK: - Custom menu application

    /// Re-reads the file, validates it against `config`, and only then makes it the
    /// layout in effect.
    ///
    /// Throws without touching the snapshot, so a bad edit leaves the menu exactly
    /// as it was instead of falling back to the default layout behind the user's back.
    func applyCustomMenu(at url: URL, config: MenuConfigPayload) throws {
        let data = try Data(contentsOf: url)
        // Validate against the payload the extension will actually receive, so a
        // reference that no longer matches enabled items is rejected here instead
        // of quietly dropping out of the menu.
        _ = try CustomMenu.decode(data, config: config)
        appliedCustomMenuData = data
        hasLoadedAppliedCustomMenu = true
    }

    /// Applies whatever is at `customMenuURL`, or throws when there is no container.
    func applyCustomMenu(config: MenuConfigPayload) throws {
        guard let url = customMenuURL else {
            throw CustomMenuError.containerUnavailable
        }
        try applyCustomMenu(at: url, config: config)
    }

    func applyCustomMenu(from state: AppState) throws {
        try applyCustomMenu(config: Self.makePayload(from: state))
    }

    /// Forgets the applied layout so a stale snapshot cannot bring it back.
    func discardAppliedCustomMenu() {
        appliedCustomMenuData = nil
        hasLoadedAppliedCustomMenu = true
    }

    private func ensureAppliedCustomMenuLoaded() {
        guard !hasLoadedAppliedCustomMenu else { return }
        hasLoadedAppliedCustomMenu = true
        guard let url = customMenuURL else { return }
        appliedCustomMenuData = try? Data(contentsOf: url)
    }

    // MARK: - Custom menu removal

    /// Deletes the custom layout, keeping a copy so the action stays reversible.
    static func removeCustomMenu(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let backup = url.deletingLastPathComponent().appendingPathComponent(customMenuBackupName)
        try? FileManager.default.removeItem(at: backup)
        // A failed backup must never block a request the user explicitly made.
        try? FileManager.default.copyItem(at: url, to: backup)
        try FileManager.default.removeItem(at: url)
    }
}
