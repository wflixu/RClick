//
//  AppState.swift
//  RClick
//
//  运行时状态：持有配置数据的内存快照、折叠开关、权限管理器。
//  配置持久化（SwiftData load/save）已抽到 ConfigService。
//

import Combine
import Foundation
import SwiftUI
import SwiftData
import OSLog


@MainActor
class AppState: ObservableObject, ActionStateProviding {
    static let shared = AppState()

    @AppLog(category: "AppState")
    private var logger

    @Published var apps: [OpenWithApp] = []
    @Published var actions: [RCAction] = []
    @Published var newFiles: [NewFile] = []
    @Published var cdirs: [CommonDir] = []
    @Published var inExt: Bool

    let bookmarkManager = BookmarkManager()

    // 折叠开关状态 - 每个分类独立控制
    //
    // 全部存在 App Group 里，和 showMenuBarExtra 一致，全项目只剩一个 store。
    // 注意收益仅止于"不再有两个 store"：扩展并不读这些键，它拿到的是 MenuService
    // 算好的 MenuConfigPayload，所以这不是功能性改进，别高估它。
    //
    // 它们原本在 UserDefaults.standard，靠 init 里那一次 migrateLayoutToggles 搬过来。
    @AppStorage("foldAppsMenu", store: .group) var foldAppsMenu: Bool = false
    @AppStorage("foldActionsMenu", store: .group) var foldActionsMenu: Bool = false
    @AppStorage("foldNewFileMenu", store: .group) var foldNewFileMenu: Bool = true
    @AppStorage("foldCommonDirMenu", store: .group) var foldCommonDirMenu: Bool = true
    // 常用文件夹总开关（默认关闭）
    @AppStorage("showCommonDirs", store: .group) var showCommonDirs: Bool = false

    // 菜单栏显示走 RClickApp / GeneralSettingsTabView 里的那份（store: .group）。
    // 这里曾有一份重复声明，没有任何地方读它；两份 store 不同，留着就是个陷阱。

    /// 配置持久化服务
    let configService = ConfigService()

    /// Layout toggles that used to live in `UserDefaults.standard`.
    ///
    /// Listed by name because the migration has to find them in the old store, and
    /// because renaming one without updating this list would silently strand the
    /// user's value there.
    nonisolated static let layoutToggleKeys = [
        "foldAppsMenu", "foldActionsMenu", "foldNewFileMenu", "foldCommonDirMenu", "showCommonDirs",
    ]

    /// Moves the layout toggles into the shared group, once.
    ///
    /// Splitting these across two stores is the defect this fixes. It needs a
    /// migration rather than a plain store swap because the old values would
    /// otherwise become invisible and every switch would fall back to its
    /// declaration default. "Enable common folders" going back to off is the one
    /// that bites: it empties `payload.commonDirs`, so any custom menu referencing a
    /// common folder stops resolving and the whole custom layout reverts.
    ///
    /// Takes both stores explicitly so a test can drive it with throwaway suites
    /// rather than the real ones.
    nonisolated static func migrateLayoutToggles(from old: UserDefaults, to new: UserDefaults) {
        for key in layoutToggleKeys {
            guard new.object(forKey: key) == nil, let existing = old.object(forKey: key) else { continue }
            new.set(existing, forKey: key)
            old.removeObject(forKey: key)
        }
    }

    init(inExt: Bool = false) {
        // Before anything reads the switches above.
        Self.migrateLayoutToggles(from: .standard, to: .group)
        self.inExt = inExt
        Task { @MainActor in
            logger.debug("start load")
            refresh()
            bookmarkManager.restoreBookmarks(context: configService.modelContext)
        }
    }

    // MARK: - Apps

    @MainActor func deleteApp(index: Int) {
        apps.remove(at: index)
        persist()
    }

    @MainActor func addApp(item: OpenWithApp) {
        logger.debug("start add app")
        apps.append(item)

        persist()
    }

    @MainActor func moveApps(from source: IndexSet, to destination: Int) {
        apps.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    @MainActor
    func updateApp(id: String, itemName: String, arguments: [String], environment: [String: String], opensNewInstance: Bool = false) {
        if let index = apps.firstIndex(where: { $0.id == id }) {
            var updatedApp = apps[index]
            updatedApp.itemName = itemName
            updatedApp.arguments = arguments
            updatedApp.environment = environment
            updatedApp.opensNewInstance = opensNewInstance
            apps[index] = updatedApp
            persist()
        }
    }

    func getAppItem(rid: String) -> OpenWithApp? {
        return apps.first { rid == $0.id }
    }

    func getFileType(rid: String) -> NewFile? {
        return newFiles.first(where: { nf in
            rid == nf.id
        })
    }

    // MARK: - NewFiles

    @MainActor func deleteNewFile(id: String) {
        newFiles.removeAll { $0.id == id }
        persist()
    }

    @MainActor func addNewFile(_ item: NewFile) {
        logger.debug("start add new file type")
        newFiles.append(item)

        persist()
    }

    @MainActor func moveNewFiles(from source: IndexSet, to destination: Int) {
        newFiles.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    // MARK: - Actions

    func getActionItem(rid: String) -> RCAction? {
        actions.first(where: { rcAtion in
            rcAtion.id == rid
        })
    }

    @MainActor func toggleActionItem() {
        persist()
    }

    @MainActor func moveActions(from source: IndexSet, to destination: Int) {
        actions.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    @MainActor func resetActionItems() {
        actions = RCAction.all
        persist()
    }

    @MainActor func resetFiletypeItems() {
        newFiles = NewFile.all
        persist()
    }

    @MainActor func refresh() {
        let data = configService.load()
        apps = data.apps
        actions = data.actions
        newFiles = data.newFiles
        cdirs = data.commonDirs
    }

    @MainActor func sync() {
        persist()
    }

    // MARK: - 持久化

    /// Set when the last write to SwiftData failed, cleared on the next success.
    ///
    /// Persistence failures used to be logged at `.info`, which never reaches the
    /// log store: a failed save looked exactly like a successful one, and the only
    /// symptom was a setting that had silently not been kept.
    @Published private(set) var lastSaveError: String?

    /// Dismisses the alert in the settings window and arms it for the next failure.
    @MainActor
    func clearSaveError() {
        lastSaveError = nil
    }

    /// Writes the in-memory configuration to SwiftData and tells the app to rebuild
    /// the menu from it.
    ///
    /// One entry point on purpose. Every mutation used to persist and notify by
    /// hand and the call sites disagreed about both halves: most dropped the error,
    /// and several skipped the notification entirely - adding an app, adding a file
    /// type, resetting either list and syncing common folders all stayed invisible
    /// until the next heartbeat. Doing both here means a mutation cannot get one
    /// without the other.
    ///
    /// Deliberately non-throwing; a failure lands in `lastSaveError` for the
    /// settings window to show, and is logged at `.error`.
    @MainActor
    private func persist() {
        reindexMenuItems()
        do {
            try configService.save(AppConfigData(apps: apps, actions: actions, newFiles: newFiles, commonDirs: cdirs))
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
            logger.error("save error: \(error.localizedDescription)")
        }
        // Posted even when persisting failed: the menu is built from these in-memory
        // arrays, so suppressing it would leave the app and the menu disagreeing
        // about what is configured.
        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
    }

    @MainActor
    private func reindexMenuItems() {
        actions = actions.enumerated().map { index, action in
            var action = action
            action.idx = index
            return action
        }
        newFiles = newFiles.enumerated().map { index, newFile in
            var newFile = newFile
            newFile.idx = index
            return newFile
        }
    }
}
