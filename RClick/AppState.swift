//
//  AppState.swift
//  RClick
//
//  Created by 李旭 on 2024/9/26.
//

import Combine
import Foundation
import SwiftUI
import SwiftData
import OSLog


@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @AppLog(category: "AppState")
    private var logger

    @Published var apps: [OpenWithApp] = []
    @Published var actions: [RCAction] = []
    @Published var newFiles: [NewFile] = []
    @Published var cdirs: [CommonDir] = []
    @Published var inExt: Bool
    @Published var hasFullDiskAccess: Bool = false
    @Published var locale: Locale

    // 折叠开关状态 - 每个分类独立控制
    @AppStorage("foldAppsMenu") var foldAppsMenu: Bool = false
    @AppStorage("foldActionsMenu") var foldActionsMenu: Bool = false
    @AppStorage("foldNewFileMenu") var foldNewFileMenu: Bool = true
    @AppStorage("foldCommonDirMenu") var foldCommonDirMenu: Bool = true
    // 常用文件夹总开关（默认关闭）
    @AppStorage("showCommonDirs") var showCommonDirs: Bool = false

    // 菜单栏显示
    @AppStorage(Key.showMenuBarExtra) var showMenuBar: Bool = true
    @AppStorage(Key.selectedLanguage, store: .group) private var selectedLanguageRawValue = AppLanguage.automatic.rawValue

    // SwiftData ModelContext（lazy 复用单个实例）
    private lazy var modelContext = ModelContext(SharedDataManager.sharedModelContainer)

    init(inExt: Bool = false) {
        self.inExt = inExt
        self.locale = AppLocalization.currentLocale
        Task { @MainActor in
            logger.debug("start load")
            try? load()
            checkFullDiskAccess()
        }

        NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.selectedLanguage == .automatic else { return }
                self.locale = AppLocalization.currentLocale
            }
        }
    }

    var selectedLanguage: AppLanguage {
        get { AppLanguage(rawValue: selectedLanguageRawValue) ?? .automatic }
        set {
            selectedLanguageRawValue = newValue.rawValue
            locale = Locale(identifier: newValue.localeIdentifier)
            NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
        }
    }

    func checkFullDiskAccess() {
        hasFullDiskAccess = PermissionChecker.hasFullDiskAccess()
        logger.debug("Full Disk Access status: \(self.hasFullDiskAccess)")
    }
    
    // Apps
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
    func updateApp(id: String, itemName: String, arguments: [String], environment: [String: String]) {
        if let index = apps.firstIndex(where: { $0.id == id }) {
            var updatedApp = apps[index]
            updatedApp.itemName = itemName
            updatedApp.arguments = arguments
            updatedApp.environment = environment
            apps[index] = updatedApp
            try? save()
        }
    }
    
    func getAppItem(rid: String) -> OpenWithApp? {
        return apps.first { rid.contains($0.id) }
    }
    
    func getFileType(rid: String) -> NewFile? {
        return newFiles.first(where: { nf in
            rid == nf.id
        })
    }
    
    @MainActor func addNewFile(_ item: NewFile) {
        logger.debug("start add new file type")
        newFiles.append(item)
        
        do {
            try save()
            // 使用 result
        } catch {
            // 处理错误
            logger.info("save error: \(error.localizedDescription)")
        }
    }

    @MainActor func moveNewFiles(from source: IndexSet, to destination: Int) {
        newFiles.move(fromOffsets: source, toOffset: destination)
        persistMenuOrder()
    }
    
    func getActionItem(rid: String) -> RCAction? {
        actions.first(where: { rcAtion in
            rcAtion.id == rid
        })
    }
    
    // Action
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
        try? load()
    }

    @MainActor func sync() {
        try? save()
    }

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
        let context = modelContext
        reindexMenuItems()

        // 保存 Apps
        try context.delete(model: AppEntity.self)
        for (index, app) in apps.enumerated() {
            context.insert(AppEntity(from: app, sortOrder: index))
        }

        // 保存 Actions
        try context.delete(model: ActionEntity.self)
        for action in actions {
            context.insert(ActionEntity(from: action))
        }

        // 保存 NewFiles
        try context.delete(model: NewFileTypeEntity.self)
        for newFile in newFiles {
            context.insert(NewFileTypeEntity(from: newFile))
        }

        // 保存 CommonDirs
        try context.delete(model: CommonDirEntity.self)
        for commonDir in cdirs {
            context.insert(CommonDirEntity(from: commonDir))
        }

        try context.save()
    }

    @MainActor
    private func load() throws {
        let context = modelContext

        // 加载 Apps
        let appDescriptor = FetchDescriptor<AppEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        apps = (try? context.fetch(appDescriptor))?.map { entity in
            var app = OpenWithApp(id: entity.id, appURL: entity.url)
            app.itemName = entity.itemName
            app.inheritFromGlobalArguments = entity.inheritFromGlobalArguments
            app.inheritFromGlobalEnvironment = entity.inheritFromGlobalEnvironment
            app.arguments = entity.arguments
            app.environment = entity.environment
            return app
        } ?? []

        // 加载 Actions
        let actionDescriptor = FetchDescriptor<ActionEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        actions = (try? context.fetch(actionDescriptor))?.map { entity in
            RCAction(
                id: entity.id,
                name: entity.name,
                enabled: entity.isEnabled,
                idx: entity.sortOrder,
                icon: entity.icon
            )
        } ?? []

        // 加载 NewFiles
        let newFileDescriptor = FetchDescriptor<NewFileTypeEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        newFiles = (try? context.fetch(newFileDescriptor))?.map { entity in
            NewFile(
                ext: entity.fileExtension,
                name: entity.name,
                idx: entity.sortOrder,
                icon: entity.icon
            )
        } ?? []

        // 加载 CommonDirs
        let commonDirDescriptor = FetchDescriptor<CommonDirEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        var needSaveCommonDirs = false
        cdirs = (try? context.fetch(commonDirDescriptor))?.map { entity in
            // 自动修复旧的通用图标
            let resolvedIcon: String
            if entity.icon == "folder" || entity.icon.isEmpty {
                let newIcon = iconForDirectory(url: entity.path)
                entity.icon = newIcon
                needSaveCommonDirs = true
                resolvedIcon = newIcon
            } else {
                resolvedIcon = entity.icon
            }
            return CommonDir(
                id: entity.id,
                name: entity.name,
                url: entity.path,
                icon: resolvedIcon
            )
        } ?? []
        if needSaveCommonDirs {
            try? context.save()
        }

        logger.debug("Load from SwiftData: \(self.apps.count) apps, \(self.actions.count) actions, \(self.newFiles.count) newFiles, \(self.cdirs.count) commonDirs")
    }
}
