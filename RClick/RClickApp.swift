//
//  RClickApp.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//
import AppKit
import Foundation
import SwiftUI
import SwiftData

import FinderSync
import os.log

extension NSNotification.Name {
    static let menuConfigShouldUpdate = NSNotification.Name("RClick.menuConfigShouldUpdate")
}

@main
struct RClickApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(Key.showMenuBarExtra, store: .group) private var showMenuBarExtra = true

    @Environment(\.openWindow) var openWindow

    @AppLog(category: "main")
    private var logger
    let messager = Messager.shared

    @StateObject var appState = AppState.shared

    @StateObject private var updateManager = UpdateManager(
        owner: "wflixu",
        repo: "RClick",
        currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    )

    var body: some Scene {
        SettingsWindow(appState: appState, onAppear: {})
            .defaultAppStorage(.group)
            .environmentObject(updateManager)
            .modelContainer(SharedDataManager.sharedModelContainer)

        // showMenuBarExtra 为 true 时显示菜单条
        MenuBarExtra(
            "RClick", image: "MenuBar", isInserted: $showMenuBarExtra
        ) {
            MenuBarView()
        }.defaultAppStorage(.group)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    @AppLog(category: "AppDelegate")
    private var logger

    var appState: AppState = .shared
    var pluginRunning: Bool = false
    var heartBeatCount = 0

    let messager = Messager.shared
    var showMenuBarExtra = UserDefaults.group.bool(forKey: Key.showMenuBarExtra)
    var showInDock = UserDefaults.group.bool(forKey: Key.showInDock)
    var settingsWindow: NSWindow!

    // MARK: - 重连机制状态

    /// 菜单配置快照（真相源）
    private var lastMenuSnapshot: Data?
    /// 菜单版本号，用于防重复和防乱序
    private var menuVersion: Int = 0
    /// 最大重试次数
    private let maxRunningMessageRetryCount: Int = 6

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("applicationDidFinishLaunching called")

        // 监听菜单配置更新通知（设置页 toggle 动作时触发）
        NotificationCenter.default.addObserver(
            forName: .menuConfigShouldUpdate,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.sendMenuConfigurationUpdate()
            }
        }

        // 在 app 启动后执行的函数

        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }

        // 执行数据迁移
        // TODO: 需要在 Xcode 中将 DataMigrationManager.swift 添加到 RClick target 后取消注释
        Task { @MainActor in
            do {
//                if DataMigrationManager.shared.needsMigration() {
//                    logger.info("检测到旧数据，开始迁移...")
//
//                    // 备份现有数据
//                    if let backupURL = DataMigrationManager.shared.backupUserDefaults() {
//                        logger.info("数据已备份到：\(backupURL.path)")
//                    }
//
//                    // 执行迁移
//                    let context = ModelContext(SharedDataManager.sharedModelContainer)
//                    try await DataMigrationManager.shared.migrateFromUserDefaults(context: context)
//
//                    logger.info("数据迁移成功完成")
//                } else {
//                    logger.info("无需数据迁移")
//                }

                // 初始化默认数据
                let context = ModelContext(SharedDataManager.sharedModelContainer)
                await SharedDataManager.initializeDefaultData(context: context)
            }

            // Preload icons for all apps to improve performance
            Task { @MainActor in
                IconCache.shared.preloadIcons(for: appState.apps.map { $0.url })
            }

            // Register message handlers using type-safe API
            logger.info("Registering message handlers")
            messager.onExtensionMessage(.click) { [weak self] data in
                guard let self = self else { return }
                if let event: ClickEventPayload = messager.decodeSignedData(data) {
                    self.handleClickEvent(event)
                } else {
                    logger.warning("Invalid click event data")
                }
            }

            messager.onExtensionMessage(.heartbeat) { [weak self] _ in
                guard let self = self else { return }
                logger.debug("Received heartbeat from extension")
                pluginRunning = true
                sendMenuConfigurationUpdate()
            }

            // 处理 Extension 请求菜单配置
            messager.onExtensionMessage(.requestConfig) { [weak self] _ in
                guard let self = self else { return }
                logger.info("Received menu config request from extension")
                self.sendMenuConfigurationUpdate()
            }

            // 启动心跳超时检测
            startHeartbeatMonitoring()
            // 启动 running 消息重试机制
            startRunningMessageRetry()

            sendObserveDirMessage()
            checkFDAAndGuideIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        messager.sendQuitNotification()
        logger.info("applicationWillTerminate")
    }

    // MARK: - Message Handlers

    func sendObserveDirMessage() {
        let directories: [String] = []
        messager.sendRunningNotification(directories: directories)
        if !pluginRunning {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                sendObserveDirMessage()
            }
        }
    }

    func sendMenuConfigurationUpdate() {
        // Build menu config from AppState
        let actionMenuItems = appState.actions.filter(\.enabled).map { $0.toActionMenuItem() }
        let appMenuItems = appState.apps.map { $0.toAppMenuItem() }
        let newFileMenuItems = appState.newFiles.map { NewFileMenuItem(id: $0.id, name: $0.name, ext: $0.ext, icon: $0.icon) }
        let commonDirMenuItems = appState.cdirs.map { CommonDirMenuItem(id: $0.id, name: $0.name, icon: $0.icon, url: $0.url.path) }

        // 更新版本号
        menuVersion += 1

        let config = MenuConfigPayload(
            version: menuVersion,
            actions: actionMenuItems,
            apps: appMenuItems,
            newFiles: newFileMenuItems,
            commonDirs: commonDirMenuItems,
            actionsCollapsed: appState.foldActionsMenu,
            appsCollapsed: appState.foldAppsMenu,
            newFilesCollapsed: appState.foldNewFileMenu,
            commonDirsCollapsed: appState.foldCommonDirMenu
        )

        // 更新快照
        lastMenuSnapshot = try? JSONEncoder().encode(config)
        logger.debug("Menu config version updated to \(self.menuVersion)")

        // Send using type-safe API
        messager.sendMenuConfig(config)
        logger.debug("Sent menu configuration to extension: \(actionMenuItems.count) actions, \(appMenuItems.count) apps")
    }

    func handleClickEvent(_ event: ClickEventPayload) {
        logger.debug("Handling click event: \(event.itemId) type=\(event.itemType.rawValue) trigger=\(event.trigger.rawValue) target=\(event.target)")

        switch event.itemType {
        case .app:
            self.openApp(rid: event.itemId, target: event.target)
        case .action:
            self.actionHandler(rid: event.itemId, target: event.target, trigger: event.trigger.rawValue)
        case .newFile:
            self.createFile(rid: event.itemId, target: event.target)
        case .commonDir:
            self.openCommonDirs(target: event.target)
        }
    }

    // MARK: - 重连机制

    /// 心跳监控 Task（可取消）
    private var heartbeatMonitorTask: Task<Void, Never>?

    /// 启动心跳监控（15 秒超时检测）
    private func startHeartbeatMonitoring() {
        heartbeatMonitorTask?.cancel()
        heartbeatMonitorTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }
                if pluginRunning {
                    pluginRunning = false
                } else {
                    logger.warning("Heartbeat timeout detected, triggering reconnection")
                    performReconnection()
                }
            }
        }
    }

    /// 启动 running 消息重试机制（每 5 秒发送一次，持续 30 秒）
    private func startRunningMessageRetry() {
        Task { @MainActor in
            for retryCount in 0..<self.maxRunningMessageRetryCount {
                try? await Task.sleep(for: .seconds(5))
                guard !self.pluginRunning else { break }
                self.messager.sendRunningNotification()
                self.logger.debug("Sending running message retry \(retryCount + 1)/\(self.maxRunningMessageRetryCount)")
            }
            logger.debug("Running message retry completed")
        }
    }

    // MARK: - FDA Permission Guide

    private func checkFDAAndGuideIfNeeded() {
        let hasSeenGuide = UserDefaults.group.bool(forKey: Key.hasSeenFDAGuide)
        guard !hasSeenGuide else { return }

        let hasFDA = PermissionChecker.hasFullDiskAccess()
        appState.hasFullDiskAccess = hasFDA
        guard !hasFDA else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            let alert = NSAlert()
            alert.messageText = String(localized: "Enable Full Disk Access")
            alert.informativeText = String(localized: "RClick needs Full Disk Access to create files, delete files, and manage hidden files in protected folders (like Desktop, Documents, and Downloads).\n\nWithout this permission, some operations may fail on protected directories.\n\nTo enable:\n1. Click \"Open Settings\" below\n2. Click the lock icon and authenticate\n3. Click \"+\" and add RClick from your Applications folder\n4. Toggle the switch next to RClick to ON")
            alert.alertStyle = .informational
            alert.addButton(withTitle: String(localized: "Open Settings"))
            alert.addButton(withTitle: String(localized: "Later"))
            alert.addButton(withTitle: String(localized: "Don't Ask Again"))

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                PermissionChecker.openFullDiskAccessSettings()
            case .alertThirdButtonReturn:
                UserDefaults.group.set(true, forKey: Key.hasSeenFDAGuide)
            default:
                break
            }
        }
    }

    /// 执行重连：发送菜单配置请求
    @MainActor private func performReconnection() {
        logger.debug("Performing reconnection: requesting menu config from main app")
        // 重置 pluginRunning 状态，等待心跳恢复
        pluginRunning = false
    }

    // MARK: - Helper Methods

    func openCommonDirs(target: [String]) {
        logger.debug("开始打开常用目录，目标路径：\(target)")

        for dirPath in target {
            let path = dirPath.removingPercentEncoding ?? dirPath
            let url = URL(fileURLWithPath: path, isDirectory: true)

            logger.debug("正在打开目录：\(path)")
            NSWorkspace.shared.open(url)
        }

        logger.debug("常用目录打开操作完成")
    }

    func openApp(rid: String, target: [String]) {
        guard let rcitem = appState.getAppItem(rid: rid) else {
            logger.warning("when openapp, but not have app \(rid)")
            return
        }

        let appUrl = rcitem.url
        logger.debug("openApp: rid=\(rid) app=\(appUrl.path) target=\(target)")

        for dirPath in target {
            let dir = URL(fileURLWithPath: dirPath.removingPercentEncoding ?? dirPath, isDirectory: true)

            // 特殊处理：WezTerm
            if appUrl.path.hasSuffix("WezTerm.app") {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/Users/lixu/play/rpm/target/debug/rpm")
                process.arguments = ["--name", "arg2"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        print("Output: \(output)")
                    }
                } catch {
                    print("Error: \(error)")
                }
            }
            // 通用处理：使用 NSWorkspace 打开目录
            else {
                let config = NSWorkspace.OpenConfiguration()
                let logger = self.logger  // 捕获 Sendable logger
                NSWorkspace.shared.open([dir], withApplicationAt: appUrl, configuration: config) { runningApp, error in
                    if let error = error {
                        logger.error("Error opening with application: \(error.localizedDescription)")
                        logger.error("Error code: \((error as NSError).code), domain: \((error as NSError).domain)")
                    } else if let runningApp = runningApp {
                        logger.debug("Successfully opened with application: \(runningApp.localizedName ?? "Unknown")")
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    func getUniqueFilePath(dir: String, ext: String) -> String {
        let fileManager = FileManager.default
        let dirURL = URL(fileURLWithPath: dir.hasSuffix("/") ? String(dir.dropLast()) : dir)
        let baseFileName = String(localized: "Untitled")
        var filePath = dirURL.appendingPathComponent("\(baseFileName)\(ext)").path
        var counter = 1

        while fileManager.fileExists(atPath: filePath) {
            let newFileName = "\(baseFileName)\(counter)"
            filePath = dirURL.appendingPathComponent("\(newFileName)\(ext)").path
            counter += 1
        }

        return filePath
    }

    func actionHandler(rid: String, target: [String], trigger: String) {
        guard let rcitem = appState.getActionItem(rid: rid) else {
            logger.warning("when createFile, but not have fileType ")
            return
        }

        switch rcitem.id {
        case "copy-path":
            copyPath(target)
        case "delete-direct":
            deleteFoldorFile(target, trigger)
        case "unhide":
            unhideFilesAndDirs(target, trigger)
        case "hide":
            hideFilesAndDirs(target, trigger)
        case "airdrop":
            showAirDrop(target, trigger)
        default:
            logger.warning("no action id matched")
        }
    }

    func showAirDrop(_ target: [String], _ trigger: String) {
        logger.info("---- showAirDrop trigger:\(trigger)")
        let fm = FileManager.default
        var fileURLs: [URL] = []

        if trigger == "ctx-container" {
            let alert = NSAlert()
            alert.messageText = "警告"
            alert.informativeText = "无法共享当前文件夹，请选择文件或子文件夹进行共享。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }

        for item in target {
            let decodedPath = item.removingPercentEncoding ?? item
            logger.info("airdrop path \(decodedPath)")

            if Utils.isProtectedFolder(decodedPath) {
                let alert = NSAlert()
                alert.messageText = "警告"
                alert.informativeText = "无法分享系统保护文件夹：\(decodedPath)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                alert.runModal()
                logger.warning("试图分享受保护的系统文件夹，操作已被阻止：\(decodedPath)")
                continue
            }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: decodedPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    logger.warning("不能通过 AirDrop 分享文件夹：\(decodedPath)")
                    let alert = NSAlert()
                    alert.messageText = "提示"
                    alert.informativeText = "不能通过 AirDrop 分享文件夹：\(decodedPath)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "确定")
                    alert.runModal()
                    continue
                } else {
                    fileURLs.append(URL(fileURLWithPath: decodedPath))
                }
            }
        }

        if !fileURLs.isEmpty {
            if let airDropService = NSSharingService(named: .sendViaAirDrop) {
                airDropService.perform(withItems: fileURLs)
                logger.info("已通过 AirDrop 分享文件：\(fileURLs.map { $0.path }.joined(separator: ", "))")
            } else {
                logger.warning("无法获取 AirDrop 服务")
            }
        }
    }

    func unhideFilesAndDirs(_ target: [String], _ trigger: String) {
        logger.info("开始取消隐藏文件和目录，目标路径：\(target)")
        if let dirPath = target.first {
            let fileManager = FileManager.default
            let path = dirPath.removingPercentEncoding ?? dirPath
            logger.info("处理主目录：\(path)")
            var url = URL(fileURLWithPath: path)

            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isHiddenKey], options: [.skipsPackageDescendants])
                for case var fileURL in contents {
                    do {
                        var resourceValues = URLResourceValues()
                        resourceValues.isHidden = false
                        try fileURL.setResourceValues(resourceValues)
                        logger.info("成功取消隐藏：\(fileURL.path)")
                    } catch {
                        logger.error("取消隐藏失败：\(fileURL.path): \(error)")
                    }
                }
            } catch {
                logger.error("获取目录内容失败：\(error)")
            }

            do {
                var resourceValues = URLResourceValues()
                resourceValues.isHidden = false
                try url.setResourceValues(resourceValues)
                logger.info("成功取消隐藏主目录：\(path)")
            } catch {
                logger.error("取消隐藏主目录失败：\(path): \(error)")
            }
            logger.info("取消隐藏操作完成，共处理目录：\(path)")
        }
    }

    func hideFilesAndDirs(_ target: [String], _ trigger: String) {
        logger.info("开始隐藏文件和目录，目标路径：\(target), 触发器：\(trigger)")
        let fileManager = FileManager.default

        if trigger == "ctx-container", let dirPath = target.first {
            let path = dirPath.removingPercentEncoding ?? dirPath
            logger.info("处理主目录：\(path)")
            let url = URL(fileURLWithPath: path)

            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsPackageDescendants])
                for case var fileURL in contents {
                    if Utils.isProtectedFolder(fileURL.path) {
                        logger.warning("跳过受保护的文件路径：\(fileURL.path)")
                        continue
                    }
                    do {
                        var resourceValues = URLResourceValues()
                        resourceValues.isHidden = true
                        try fileURL.setResourceValues(resourceValues)
                        logger.info("成功隐藏：\(fileURL.path)")
                    } catch {
                        logger.error("隐藏失败：\(fileURL.path): \(error)")
                    }
                }
            } catch {
                logger.error("获取目录内容失败：\(error)")
            }
        } else if trigger == "ctx-items" {
            for dirPath in target {
                let path = dirPath.removingPercentEncoding ?? dirPath
                logger.info("处理路径：\(path)")
                var url = URL(fileURLWithPath: path)

                if Utils.isProtectedFolder(path) {
                    logger.warning("跳过受保护的文件路径：\(path)")
                    continue
                }
                do {
                    var resourceValues = URLResourceValues()
                    resourceValues.isHidden = true
                    try url.setResourceValues(resourceValues)
                    logger.info("成功隐藏：\(path)")
                } catch {
                    logger.error("隐藏失败：\(path): \(error)")
                }
            }
        }
        logger.info("隐藏操作完成")
    }

    func copyPath(_ target: [String]) {
        if let dirPath = target.first {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(dirPath.removingPercentEncoding ?? dirPath, forType: .string)
        }
    }

    func deleteFoldorFile(_ target: [String], _ trigger: String) {
        logger.info("---- deleteFoldorFile trigger:\(trigger)")
        let fm = FileManager.default

        if trigger == "ctx-container" {
            let alert = NSAlert()
            alert.messageText = "警告"
            alert.informativeText = "无法删除当前文件夹，请选择文件或子文件夹进行删除。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }

        for item in target {
            let decodedPath = item.removingPercentEncoding ?? item

            if Utils.isProtectedFolder(decodedPath) {
                let alert = NSAlert()
                alert.messageText = "警告"
                alert.informativeText = "无法删除系统保护文件夹：\(decodedPath)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                alert.runModal()
                logger.warning("试图删除受保护的系统文件夹，操作已被阻止：\(decodedPath)")
                continue
            }

            // 使用完全磁盘访问权限，直接删除
            do {
                try fm.removeItem(atPath: item.removingPercentEncoding ?? item)
            } catch {
                logger.error("delete \(target) file run error \(error)")
            }
        }
    }

    func createFile(rid: String, target: [String]) {
        guard let rcitem = appState.getFileType(rid: rid), let dirPath = target.first else {
            logger.warning("when createFile, but not have fileType \(rid) ")
            return
        }

        let ext = rcitem.ext
        logger.info("create file dir:\(dirPath) -- ext \(ext)")
        let filePath = getUniqueFilePath(dir: dirPath.removingPercentEncoding ?? dirPath, ext: ext)
        let fileURL = URL(fileURLWithPath: filePath)

        // 使用完全磁盘访问权限，直接创建文件
        do {
            let fileManager = FileManager.default

            if let templateUrl = rcitem.template {
                try fileManager.copyItem(at: templateUrl, to: fileURL)
                logger.info("已成功复制模板到目标路径：\(fileURL.path)")
            } else {
                if let defaultTemplateURL = Bundle.main.url(forResource: "template", withExtension: ext.replacingOccurrences(of: ".", with: "")) {
                    logger.info("使用模板创建文件，模板路径：\(defaultTemplateURL.path)")
                    try fileManager.copyItem(at: defaultTemplateURL, to: fileURL)
                    logger.info("已成功复制模板到目标路径：\(fileURL.path)")
                } else {
                    logger.warning("模板文件不存在：\(ext)")
                    try Data().write(to: fileURL)
                }
            }
        } catch let error as NSError {
            switch error.domain {
            case NSCocoaErrorDomain:
                switch error.code {
                case NSFileNoSuchFileError:
                    logger.error("文件不存在：\(filePath)")
                case NSFileWriteOutOfSpaceError:
                    logger.error("磁盘空间不足")
                case NSFileWriteNoPermissionError:
                    logger.error("没有写入权限：\(filePath)")
                default:
                    logger.error("创建文件错误：\(error.localizedDescription) (错误码：\(error.code))")
                }
            default:
                logger.error("未处理的错误：\(error.localizedDescription) (错误码：\(error.code))")
            }
        }
    }
}
