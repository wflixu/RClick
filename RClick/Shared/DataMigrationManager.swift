//
//  DataMigrationManager.swift
//  RClick
//
//  Created by Claude on 2026/01/16.
//

import Foundation
import SwiftData
import OSLog

enum SettingsBackupError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Unsupported settings backup version: \(version)"
        }
    }
}

struct SettingsBackup: Codable {
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var appVersion: String
    var apps: [SettingsBackupApp]
    var actions: [SettingsBackupAction]
    var newFiles: [SettingsBackupNewFile]
    var commonDirs: [SettingsBackupCommonDir]
    var preferences: SettingsBackupPreferences

    @MainActor
    init(appState: AppState) {
        self.version = Self.currentVersion
        self.exportedAt = Date()
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        self.apps = appState.apps.map { SettingsBackupApp(from: $0) }
        self.actions = appState.actions.map { SettingsBackupAction(from: $0) }
        self.newFiles = appState.newFiles.map { SettingsBackupNewFile(from: $0) }
        self.commonDirs = appState.cdirs.map { SettingsBackupCommonDir(from: $0) }
        self.preferences = SettingsBackupPreferences(appState: appState)
    }
}

struct SettingsBackupApp: Codable {
    var id: String
    var path: String
    var itemName: String
    var inheritFromGlobalArguments: Bool
    var inheritFromGlobalEnvironment: Bool
    var arguments: [String]
    var environment: [String: String]

    @MainActor
    init(from app: OpenWithApp) {
        self.id = app.id
        self.path = app.url.path(percentEncoded: false)
        self.itemName = app.itemName
        self.inheritFromGlobalArguments = app.inheritFromGlobalArguments
        self.inheritFromGlobalEnvironment = app.inheritFromGlobalEnvironment
        self.arguments = app.arguments
        self.environment = app.environment
    }

    @MainActor
    func toModel() -> OpenWithApp {
        var app = OpenWithApp(id: id, appURL: URL(fileURLWithPath: path))
        app.itemName = itemName
        app.inheritFromGlobalArguments = inheritFromGlobalArguments
        app.inheritFromGlobalEnvironment = inheritFromGlobalEnvironment
        app.arguments = arguments
        app.environment = environment
        return app
    }
}

struct SettingsBackupAction: Codable {
    var id: String
    var name: String
    var enabled: Bool
    var idx: Int
    var icon: String

    @MainActor
    init(from action: RCAction) {
        self.id = action.id
        self.name = action.name
        self.enabled = action.enabled
        self.idx = action.idx
        self.icon = action.icon
    }

    @MainActor
    func toModel() -> RCAction {
        RCAction(id: id, name: name, enabled: enabled, idx: idx, icon: icon)
    }
}

struct SettingsBackupNewFile: Codable {
    var id: String
    var ext: String
    var name: String
    var enabled: Bool
    var idx: Int
    var icon: String
    var openAppPath: String?
    var templatePath: String?

    @MainActor
    init(from newFile: NewFile) {
        self.id = newFile.id
        self.ext = newFile.ext
        self.name = newFile.name
        self.enabled = newFile.enabled
        self.idx = newFile.idx
        self.icon = newFile.icon
        self.openAppPath = newFile.openApp?.path(percentEncoded: false)
        self.templatePath = newFile.template?.path(percentEncoded: false)
    }

    @MainActor
    func toModel() -> NewFile {
        var newFile = NewFile(ext: ext, name: name, enabled: enabled, idx: idx, icon: icon, id: id)
        if let openAppPath, !openAppPath.isEmpty {
            newFile.openApp = URL(fileURLWithPath: openAppPath)
        }
        if let templatePath, !templatePath.isEmpty {
            newFile.template = URL(fileURLWithPath: templatePath)
        }
        return newFile
    }
}

struct SettingsBackupCommonDir: Codable {
    var id: String
    var name: String
    var path: String
    var icon: String

    @MainActor
    init(from commonDir: CommonDir) {
        self.id = commonDir.id
        self.name = commonDir.name
        self.path = commonDir.url.path(percentEncoded: false)
        self.icon = commonDir.icon
    }

    @MainActor
    func toModel() -> CommonDir {
        CommonDir(id: id, name: name, url: URL(fileURLWithPath: path), icon: icon)
    }
}

struct SettingsBackupPreferences: Codable {
    var launchAtLogin: Bool
    var foldAppsMenu: Bool
    var foldActionsMenu: Bool
    var foldNewFileMenu: Bool
    var foldCommonDirMenu: Bool
    var showCommonDirs: Bool
    var showCopyToCommonDirs: Bool
    var showMoveToCommonDirs: Bool
    var showMenuBarExtra: Bool
    var showInDock: Bool
    var showDockIcon: Bool
    var showContextualMenuForItem: Bool
    var showContextualMenuForContainer: Bool
    var showContextualMenuForSidebar: Bool
    var showToolbarItemMenu: Bool
    var globalApplicationArgumentsString: String
    var globalApplicationEnvironmentString: String
    var copySeparator: String
    var newFileName: String
    var newFileExtension: String
    var showSubMenuForApplication: Bool
    var showSubMenuForAction: Bool
    var hasSeenFullDiskAccessGuide: Bool
    var selectedLanguage: String
    var ignoredVersionDataBase64: String?

    @MainActor
    init(appState: AppState) {
        let group = UserDefaults.group
        let standard = UserDefaults.standard

        self.launchAtLogin = LaunchAtLogin.isEnabled
        self.foldAppsMenu = appState.foldAppsMenu
        self.foldActionsMenu = appState.foldActionsMenu
        self.foldNewFileMenu = appState.foldNewFileMenu
        self.foldCommonDirMenu = appState.foldCommonDirMenu
        self.showCommonDirs = appState.showCommonDirs
        self.showCopyToCommonDirs = appState.showCopyToCommonDirs
        self.showMoveToCommonDirs = appState.showMoveToCommonDirs
        self.showMenuBarExtra = group.backupBool(forKey: Key.showMenuBarExtra, default: true)
        self.showInDock = group.backupBool(forKey: Key.showInDock, default: false)
        self.showDockIcon = group.backupBool(forKey: Key.showDockIcon, default: false)
        self.showContextualMenuForItem = group.backupBool(forKey: Key.showContextualMenuForItem, default: true)
        self.showContextualMenuForContainer = group.backupBool(forKey: Key.showContextualMenuForContainer, default: true)
        self.showContextualMenuForSidebar = group.backupBool(forKey: Key.showContextualMenuForSidebar, default: true)
        self.showToolbarItemMenu = group.backupBool(forKey: Key.showToolbarItemMenu, default: true)
        self.globalApplicationArgumentsString = group.backupString(forKey: Key.globalApplicationArgumentsString, default: "")
        self.globalApplicationEnvironmentString = group.backupString(forKey: Key.globalApplicationEnvironmentString, default: "")
        self.copySeparator = group.backupString(forKey: Key.copySeparator, default: "")
        self.newFileName = group.backupString(forKey: Key.newFileName, default: "Untitled")
        self.newFileExtension = group.backupString(forKey: Key.newFileExtension, default: "")
        self.showSubMenuForApplication = group.backupBool(forKey: Key.showSubMenuForApplication, default: false)
        self.showSubMenuForAction = group.backupBool(forKey: Key.showSubMenuForAction, default: false)
        self.hasSeenFullDiskAccessGuide = group.backupBool(forKey: Key.hasSeenFDAGuide, default: false)
        self.selectedLanguage = appState.selectedLanguage.rawValue

        if let ignoredVersionData = standard.data(forKey: "ignoredVersion"), !ignoredVersionData.isEmpty {
            self.ignoredVersionDataBase64 = ignoredVersionData.base64EncodedString()
        }
    }

    @MainActor
    func apply(to appState: AppState) {
        let group = UserDefaults.group
        let standard = UserDefaults.standard

        standard.set(launchAtLogin, forKey: "launchAtLogin")
        LaunchAtLogin.isEnabled = launchAtLogin

        appState.foldAppsMenu = foldAppsMenu
        appState.foldActionsMenu = foldActionsMenu
        appState.foldNewFileMenu = foldNewFileMenu
        appState.foldCommonDirMenu = foldCommonDirMenu
        appState.showCommonDirs = showCommonDirs
        appState.showCopyToCommonDirs = showCopyToCommonDirs
        appState.showMoveToCommonDirs = showMoveToCommonDirs
        appState.showMenuBar = showMenuBarExtra

        group.set(showMenuBarExtra, forKey: Key.showMenuBarExtra)
        group.set(showInDock, forKey: Key.showInDock)
        group.set(showDockIcon, forKey: Key.showDockIcon)
        group.set(showContextualMenuForItem, forKey: Key.showContextualMenuForItem)
        group.set(showContextualMenuForContainer, forKey: Key.showContextualMenuForContainer)
        group.set(showContextualMenuForSidebar, forKey: Key.showContextualMenuForSidebar)
        group.set(showToolbarItemMenu, forKey: Key.showToolbarItemMenu)
        group.set(globalApplicationArgumentsString, forKey: Key.globalApplicationArgumentsString)
        group.set(globalApplicationEnvironmentString, forKey: Key.globalApplicationEnvironmentString)
        group.set(copySeparator, forKey: Key.copySeparator)
        group.set(newFileName, forKey: Key.newFileName)
        group.set(newFileExtension, forKey: Key.newFileExtension)
        group.set(showSubMenuForApplication, forKey: Key.showSubMenuForApplication)
        group.set(showSubMenuForAction, forKey: Key.showSubMenuForAction)
        group.set(hasSeenFullDiskAccessGuide, forKey: Key.hasSeenFDAGuide)

        if let language = AppLanguage(rawValue: selectedLanguage) {
            appState.selectedLanguage = language
        } else {
            group.set(selectedLanguage, forKey: Key.selectedLanguage)
        }

        if let ignoredVersionDataBase64,
           let ignoredVersionData = Data(base64Encoded: ignoredVersionDataBase64) {
            standard.set(ignoredVersionData, forKey: "ignoredVersion")
        } else {
            standard.removeObject(forKey: "ignoredVersion")
        }

        standard.synchronize()
        group.synchronize()
    }
}

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

    func exportSettings(to url: URL, appState: AppState = .shared) throws {
        var targetURL = url
        if targetURL.pathExtension.isEmpty {
            targetURL.appendPathExtension("json")
        }

        let backup = SettingsBackup(appState: appState)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        try data.write(to: targetURL, options: .atomic)
        logger.info("Settings exported to: \(targetURL.path)")
    }

    @discardableResult
    func importSettings(from url: URL, appState: AppState = .shared) throws -> SettingsBackup {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(SettingsBackup.self, from: data)

        guard backup.version <= SettingsBackup.currentVersion else {
            throw SettingsBackupError.unsupportedVersion(backup.version)
        }

        try appState.replaceAllSettings(
            apps: backup.apps.map { $0.toModel() },
            actions: backup.actions.map { $0.toModel() },
            newFiles: backup.newFiles.map { $0.toModel() },
            commonDirs: backup.commonDirs.map { $0.toModel() }
        )
        backup.preferences.apply(to: appState)
        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
        logger.info("Settings imported from: \(url.path)")

        return backup
    }

    func resetSettings(appState: AppState = .shared) throws {
        let defaultCommonDirs = CommonDirEntity.createDefaultCommonDirs().map {
            CommonDir(id: $0.id, name: $0.name, url: $0.path, icon: $0.icon)
        }
        try appState.replaceAllSettings(
            apps: OpenWithApp.defaultApps,
            actions: RCAction.all,
            newFiles: NewFile.all,
            commonDirs: defaultCommonDirs
        )

        appState.foldAppsMenu = false
        appState.foldActionsMenu = false
        appState.foldNewFileMenu = true
        appState.foldCommonDirMenu = true
        appState.showCommonDirs = false
        appState.showCopyToCommonDirs = true
        appState.showMoveToCommonDirs = true
        appState.showMenuBar = true
        appState.selectedLanguage = .automatic

        let standard = UserDefaults.standard
        standard.removeObject(forKey: "launchAtLogin")
        standard.removeObject(forKey: "ignoredVersion")
        LaunchAtLogin.isEnabled = false

        let group = UserDefaults.group
        let keysToRemove = [
            Key.showContextualMenuForItem,
            Key.showContextualMenuForContainer,
            Key.showContextualMenuForSidebar,
            Key.showToolbarItemMenu,
            Key.showDockIcon,
            Key.globalApplicationArgumentsString,
            Key.globalApplicationEnvironmentString,
            Key.copySeparator,
            Key.newFileName,
            Key.newFileExtension,
            Key.showSubMenuForApplication,
            Key.showSubMenuForAction,
            Key.showInDock,
            Key.hasSeenFDAGuide,
            Key.actionMenuItems,
            Key.appMenuItems,
        ]
        keysToRemove.forEach { group.removeObject(forKey: $0) }
        group.set(true, forKey: Key.showMenuBarExtra)

        if let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let templatesURL = applicationSupport.appendingPathComponent("RClick/Templates")
            if FileManager.default.fileExists(atPath: templatesURL.path) {
                try FileManager.default.removeItem(at: templatesURL)
            }
        }

        standard.synchronize()
        group.synchronize()
        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
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

private extension UserDefaults {
    func backupBool(forKey key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) as? Bool ?? defaultValue
    }

    func backupString(forKey key: String, default defaultValue: String) -> String {
        object(forKey: key) as? String ?? defaultValue
    }
}
