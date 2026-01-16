//
//  ModelContainer.swift
//  RClick
//
//  Created by 李旭 on 2025/10/3.
//

import Foundation
import SwiftData
import OSLog

let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RClick", category: "ModelContainer")

// 共享 ModelContainer 配置工具类
class SharedDataManager {
    static let appGroupIdentifier = Constants.suitName

    static var sharedModelContainer: ModelContainer = {
        do {
            // 获取 App Group 共享目录
            let storeURL: URL

            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
                fatalError("无法获取 App Group 共享目录。请检查 App Group 配置: \(appGroupIdentifier)")
            }
            storeURL = containerURL.appendingPathComponent("RClickDatabase.sqlite")

            // 创建 ModelConfiguration 使用共享路径
            let configuration = ModelConfiguration(
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )

            // 创建 ModelContainer，注册所有模型
            let container = try ModelContainer(
                for: AppEntity.self,
                     ActionEntity.self,
                     NewFileTypeEntity.self,
                     CommonDirEntity.self,
                     PermDir.self,
                     DataVersion.self,
                configurations: configuration
            )

            return container
        } catch {
            fatalError("创建共享 ModelContainer 失败: \(error)")
        }
    }()

    /// 初始化默认数据
    @MainActor
    static func initializeDefaultData(context: ModelContext) async {
        // 检查是否已有数据
        let actionDescriptor = FetchDescriptor<ActionEntity>()
        let actionCount = try? context.fetchCount(actionDescriptor) ?? 0

        if actionCount == 0 {
            // 插入默认动作
            for action in ActionEntity.createDefaultActions() {
                context.insert(action)
            }
            logger.info("已初始化默认动作")
        }

        let fileTypeDescriptor = FetchDescriptor<NewFileTypeEntity>()
        let fileTypeCount = try? context.fetchCount(fileTypeDescriptor) ?? 0

        if fileTypeCount == 0 {
            // 插入默认文件类型
            for fileType in NewFileTypeEntity.createDefaultFileTypes() {
                context.insert(fileType)
            }
            logger.info("已初始化默认文件类型")
        }

        let commonDirDescriptor = FetchDescriptor<CommonDirEntity>()
        let commonDirCount = try? context.fetchCount(commonDirDescriptor) ?? 0

        if commonDirCount == 0 {
            // 插入默认常用目录
            for dir in CommonDirEntity.createDefaultCommonDirs() {
                context.insert(dir)
            }
            logger.info("已初始化默认常用目录")
        }

        try? context.save()
    }
}
