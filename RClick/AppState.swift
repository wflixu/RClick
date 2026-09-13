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
    @AppStorage("foldAppsMenu") var foldAppsMenu: Bool = false
    @AppStorage("foldActionsMenu") var foldActionsMenu: Bool = false
    @AppStorage("foldNewFileMenu") var foldNewFileMenu: Bool = true
    @AppStorage("foldCommonDirMenu") var foldCommonDirMenu: Bool = true
    // 常用文件夹总开关（默认关闭）
    @AppStorage("showCommonDirs") var showCommonDirs: Bool = false

    // 菜单栏显示
    @AppStorage(Key.showMenuBarExtra) var showMenuBar: Bool = true

    /// 配置持久化服务
    let configService = ConfigService()

    init(inExt: Bool = false) {
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
        do {
            try save()
        } catch {
            logger.info("save error: \(error.localizedDescription)")
        }
    }

    @MainActor func addApp(item: OpenWithApp) {
        logger.debug("start add app")
        apps.append(item)

        do {
            try save()
        } catch {
            logger.info("save error: \(error.localizedDescription)")
        }
    }

    @MainActor func moveApps(from source: IndexSet, to destination: Int) {
        apps.move(fromOffsets: source, toOffset: destination)
        persistMenuOrder()
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
            try? save()
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
        do {
            try save()
        } catch {
            logger.info("save error: \(error.localizedDescription)")
        }
        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
    }

    @MainActor func addNewFile(_ item: NewFile) {
        logger.debug("start add new file type")
        newFiles.append(item)

        do {
            try save()
        } catch {
            logger.info("save error: \(error.localizedDescription)")
        }
    }

    @MainActor func moveNewFiles(from source: IndexSet, to destination: Int) {
        newFiles.move(fromOffsets: source, toOffset: destination)
        persistMenuOrder()
    }

    // MARK: - Actions

    func getActionItem(rid: String) -> RCAction? {
        actions.first(where: { rcAtion in
            rcAtion.id == rid
        })
    }

    @MainActor func toggleActionItem() {
        try? save()
        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
    }

    @MainActor func moveActions(from source: IndexSet, to destination: Int) {
        actions.move(fromOffsets: source, toOffset: destination)
        persistMenuOrder()
    }

    @MainActor func resetActionItems() {
        actions = RCAction.all
        try? save()
    }

    @MainActor func resetFiletypeItems() {
        newFiles = NewFile.all
        try? save()
    }

    @MainActor func refresh() {
        let data = configService.load()
        apps = data.apps
        actions = data.actions
        newFiles = data.newFiles
        cdirs = data.commonDirs
    }

    @MainActor func sync() {
        try? save()
    }

    // MARK: - 持久化

    @MainActor
    private func persistMenuOrder() {
        reindexMenuItems()
        do {
            try save()
            NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
        } catch {
            logger.info("save error: \(error.localizedDescription)")
        }
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

    @MainActor
    private func save() throws {
        reindexMenuItems()
        try configService.save(AppConfigData(apps: apps, actions: actions, newFiles: newFiles, commonDirs: cdirs))
    }
}
