//
//  ConfigService.swift
//  RClick
//
//  配置持久化服务：负责配置数据的读取、保存（SwiftData）。
//  与 AppState 分离：AppState 持有运行时状态（内存数组），ConfigService 负责持久化。
//

import Foundation
import SwiftData
import os.log

/// 配置数据快照（AppState 持有的内存配置）
struct AppConfigData {
    var apps: [OpenWithApp] = []
    var actions: [RCAction] = []
    var newFiles: [NewFile] = []
    var commonDirs: [CommonDir] = []
}

@MainActor
final class ConfigService {
    @AppLog(category: "ConfigService")
    private var logger

    let modelContext: ModelContext

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext ?? ModelContext(SharedDataManager.sharedModelContainer)
    }

    /// 从 SwiftData 读取全部配置
    func load() -> AppConfigData {
        var data = AppConfigData()

        // Apps
        let appDescriptor = FetchDescriptor<AppEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        data.apps = (try? modelContext.fetch(appDescriptor))?.map { entity in
            var app = OpenWithApp(id: entity.id, appURL: entity.url)
            app.itemName = entity.itemName
            app.inheritFromGlobalArguments = entity.inheritFromGlobalArguments
            app.inheritFromGlobalEnvironment = entity.inheritFromGlobalEnvironment
            app.arguments = entity.arguments
            app.environment = entity.environment
            app.opensNewInstance = entity.opensNewInstance
            return app
        } ?? []

        // Actions
        let actionDescriptor = FetchDescriptor<ActionEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        data.actions = (try? modelContext.fetch(actionDescriptor))?.map { entity in
            RCAction(
                id: entity.id,
                name: entity.name,
                enabled: entity.isEnabled,
                idx: entity.sortOrder,
                icon: entity.icon
            )
        } ?? []

        // NewFiles
        let newFileDescriptor = FetchDescriptor<NewFileTypeEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        data.newFiles = (try? modelContext.fetch(newFileDescriptor))?.map { entity in
            var file = NewFile(
                ext: entity.fileExtension,
                name: entity.name,
                enabled: entity.isEnabled,
                idx: entity.sortOrder,
                icon: entity.icon,
                id: entity.id
            )
            file.template = entity.templatePath.map { URL(fileURLWithPath: $0) }
            file.openApp = entity.openAppPath.map { URL(fileURLWithPath: $0) }
            return file
        } ?? []

        // CommonDirs（含旧图标自动修复）
        let commonDirDescriptor = FetchDescriptor<CommonDirEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        var needSaveCommonDirs = false
        data.commonDirs = (try? modelContext.fetch(commonDirDescriptor))?.map { entity in
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
            try? modelContext.save()
        }

        logger.debug("Load from SwiftData: \(data.apps.count) apps, \(data.actions.count) actions, \(data.newFiles.count) newFiles, \(data.commonDirs.count) commonDirs")
        return data
    }

    /// 将配置数据写回 SwiftData（全量替换）
    func save(_ data: AppConfigData) throws {
        // Apps
        try modelContext.delete(model: AppEntity.self)
        for (index, app) in data.apps.enumerated() {
            modelContext.insert(AppEntity(from: app, sortOrder: index))
        }

        // Actions
        try modelContext.delete(model: ActionEntity.self)
        for action in data.actions {
            modelContext.insert(ActionEntity(from: action))
        }

        // NewFiles
        try modelContext.delete(model: NewFileTypeEntity.self)
        for newFile in data.newFiles {
            modelContext.insert(NewFileTypeEntity(from: newFile))
        }

        // CommonDirs
        try modelContext.delete(model: CommonDirEntity.self)
        for commonDir in data.commonDirs {
            modelContext.insert(CommonDirEntity(from: commonDir))
        }

        try modelContext.save()
    }
}
