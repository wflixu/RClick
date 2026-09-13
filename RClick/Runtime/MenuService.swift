//
//  MenuService.swift
//  RClick
//
//  菜单配置构建服务：从 AppState 生成发往 Finder Extension 的 MenuConfigPayload。
//  版本号在这里维护，用于防重复和防乱序。
//

import Foundation
import OSLog

/// What the on-disk custom menu file means for this installation right now.
enum CustomMenuStatus: Equatable {
    /// The App Group container is unavailable (signing or entitlement problem).
    case unavailable
    /// No file: the default categorized layout applies. Not a problem.
    case defaultLayout
    /// An empty array: the user asked for an intentionally empty menu. Not a problem.
    case empty
    /// Parsed and resolved; carries the number of top-level entries.
    case active(topLevelItems: Int)
    /// Present but unusable, so the default layout applies instead.
    case invalid(reason: String)

    /// Whether this state is worth telling the user about.
    var isProblem: Bool {
        switch self {
        case .unavailable, .invalid: true
        case .defaultLayout, .empty, .active: false
        }
    }
}

@MainActor
final class MenuService {
    /// 菜单版本号（防重复 / 防乱序）
    private var menuVersion = 0

    /// Copy kept beside the live file when the custom layout is removed.
    static let customMenuBackupName = "custom_menu.backup.json"

    static var customMenuURL: URL? {
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
        if !nodes.isEmpty { nodes.append(MenuNode(type: .separator)) }
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
        let newFileMenuItems = state.newFiles.filter(\.enabled).map { NewFileMenuItem(id: $0.id, name: $0.name, ext: $0.ext, icon: $0.icon) }
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

        if let url = Self.customMenuURL {
            do {
                config.customMenu = try CustomMenu.load(from: url, config: config)
            } catch {
                // Fall back to the default layout, but keep the reason readable in
                // the log. `.private` because messages can quote user paths.
                Logger(subsystem: "RClick", category: "MenuService")
                    .error("Invalid custom_menu.json; using default menu: \(CustomMenuDiagnostics.message(for: error), privacy: .private)")
            }
        }

        return config
    }

    // MARK: - Custom menu status

    /// Reports what the custom menu file currently means for this installation.
    ///
    /// Derived on demand rather than cached inside `buildConfig`: that method only
    /// runs when the extension asks for a config, which never happens while the
    /// extension is disabled - exactly when someone opens Settings to investigate.
    static func customMenuStatus(at url: URL?, config: MenuConfigPayload) -> CustomMenuStatus {
        guard let url else { return .unavailable }
        do {
            guard let nodes = try CustomMenu.load(from: url, config: config) else { return .defaultLayout }
            return nodes.isEmpty ? .empty : .active(topLevelItems: nodes.count)
        } catch {
            return .invalid(reason: CustomMenuDiagnostics.message(for: error))
        }
    }

    func customMenuStatus(from state: AppState) -> CustomMenuStatus {
        Self.customMenuStatus(at: Self.customMenuURL, config: Self.makePayload(from: state))
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
