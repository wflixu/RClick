//
//  DataMigrationManager.swift
//  RClick
//
//  Created by Claude on 2026/01/16.
//

import Foundation
import SwiftData
import OSLog

/// 数据迁移管理器 - 负责将UserDefaults中的数据迁移到SwiftData
@MainActor
class DataMigrationManager {
    static let shared = DataMigrationManager()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "RClick",
        category: "DataMigration"
    )

    private init() {}

    /// 检查是否需要迁移
    func needsMigration() -> Bool {
        // 检查是否有旧数据需要迁移
        let hasAppsData = UserDefaults.group.data(forKey: Key.apps) != nil
        let hasActionsData = UserDefaults.group.data(forKey: Key.actions) != nil
        let hasFileTypesData = UserDefaults.group.data(forKey: Key.fileTypes) != nil
        let hasCommonDirsData = UserDefaults.group.data(forKey: Key.commonDirs) != nil

        return hasAppsData || hasActionsData || hasFileTypesData || hasCommonDirsData
    }

    /// 执行数据迁移
    func migrateFromUserDefaults(context: ModelContext) async throws {
        logger.info("开始数据迁移...")

        var migrationCount = 0

        // 1. 迁移 OpenWithApp -> AppEntity
        if let appData = UserDefaults.group.data(forKey: Key.apps) {
            do {
                let apps = try JSONDecoder().decode([OpenWithApp].self, from: appData)

                for app in apps {
                    let entity = AppEntity(
                        id: app.id,
                        url: app.url,
                        itemName: app.name,
                        inheritFromGlobalArguments: app.inheritFromGlobalArguments,
                        inheritFromGlobalEnvironment: app.inheritFromGlobalEnvironment,
                        arguments: app.arguments,
                        environment: app.environment,
                        sortOrder: 0
                    )
                    context.insert(entity)
                }

                logger.info("已迁移 \(apps.count) 个应用")
                migrationCount += apps.count
            } catch {
                logger.error("迁移应用数据失败: \(error)")
                throw error
            }
        }

        // 2. 迁移 RCAction -> ActionEntity
        if let actionData = UserDefaults.group.data(forKey: Key.actions) {
            do {
                let actions = try JSONDecoder().decode([RCAction].self, from: actionData)

                for (_, action) in actions.enumerated() {
                    let entity = ActionEntity(
                        id: action.id,
                        name: action.name,
                        icon: action.icon,
                        isEnabled: action.enabled,
                        sortOrder: action.idx
                    )
                    context.insert(entity)
                }

                logger.info("已迁移 \(actions.count) 个动作")
                migrationCount += actions.count
            } catch {
                logger.error("迁移动作数据失败: \(error)")
                throw error
            }
        }

        // 3. 迁移 NewFile -> NewFileTypeEntity
        if let fileTypeData = UserDefaults.group.data(forKey: Key.fileTypes) {
            do {
                let fileTypes = try JSONDecoder().decode([NewFile].self, from: fileTypeData)

                for fileType in fileTypes {
                    let entity = NewFileTypeEntity(
                        id: fileType.id,
                        fileExtension: fileType.ext,
                        name: fileType.name,
                        icon: fileType.icon,
                        isEnabled: fileType.enabled,
                        sortOrder: fileType.idx
                    )
                    context.insert(entity)
                }

                logger.info("已迁移 \(fileTypes.count) 个文件类型")
                migrationCount += fileTypes.count
            } catch {
                logger.error("迁移文件类型数据失败: \(error)")
                throw error
            }
        }

        // 4. 迁移 CommonDir -> CommonDirEntity
        if let commonDirData = UserDefaults.group.data(forKey: Key.commonDirs) {
            do {
                let dirs = try JSONDecoder().decode([CommonDir].self, from: commonDirData)

                for dir in dirs {
                    let entity = CommonDirEntity(
                        id: dir.id,
                        name: dir.name,
                        path: dir.url,
                        icon: dir.icon
                    )
                    context.insert(entity)
                }

                logger.info("已迁移 \(dirs.count) 个常用目录")
                migrationCount += dirs.count
            } catch {
                logger.error("迁移常用目录数据失败: \(error)")
                throw error
            }
        }

        // 5. PermissiveDir 已删除，不再需要迁移

        // 保存所有更改
        try context.save()

        logger.info("数据迁移完成，共迁移 \(migrationCount) 条记录")

        // 清除旧数据（可选，建议先备份）
        // cleanupUserDefaults()
    }

    /// 清理UserDefaults中的旧数据
    private func cleanupUserDefaults() {
        logger.info("清理UserDefaults中的旧数据...")

        UserDefaults.group.removeObject(forKey: Key.apps)
        UserDefaults.group.removeObject(forKey: Key.actions)
        UserDefaults.group.removeObject(forKey: Key.fileTypes)
        UserDefaults.group.removeObject(forKey: Key.commonDirs)
        UserDefaults.group.removeObject(forKey: Key.actionMenuItems)
        UserDefaults.group.removeObject(forKey: Key.appMenuItems)

        logger.info("旧数据已清理")
    }

    /// 备份UserDefaults数据到文件
    func backupUserDefaults() -> URL? {
        let dateFormatter = ISO8601DateFormatter()
        let timestamp = dateFormatter.string(from: Date())

        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            logger.error("无法获取文档目录")
            return nil
        }

        let backupURL = documentsURL
            .appendingPathComponent("RClick_UserDefaults_Backup_\(timestamp).json")

        do {
            let data = try JSONSerialization.data(
                withJSONObject: [
                    "apps": UserDefaults.group.data(forKey: Key.apps) as Any,
                    "actions": UserDefaults.group.data(forKey: Key.actions) as Any,
                    "fileTypes": UserDefaults.group.data(forKey: Key.fileTypes) as Any,
                    "commonDirs": UserDefaults.group.data(forKey: Key.commonDirs) as Any,
                ],
                options: .prettyPrinted
            )

            try data.write(to: backupURL)
            logger.info("UserDefaults数据已备份到: \(backupURL.path)")
            return backupURL
        } catch {
            logger.error("备份UserDefaults数据失败: \(error)")
            return nil
        }
    }
}
