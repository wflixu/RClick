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

    func applicationDidFinishLaunching(_ aNotification: Notification) {
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
            Task {
                IconCache.shared.preloadIcons(for: appState.apps.map { $0.url })
            }

            // Register message handlers using new type-safe API
            messager.onExtensionMessage(.click) { [weak self] data in
                guard let self = self else { return }
                if let event: ClickEventPayload = messager.decode(data) {
                    // New type-safe ClickEventPayload
                    self.handleClickEvent(event)
                } else if let payload: MessagePayload = messager.decode(data),
                          payload.action == "click" {
                    // Legacy MessagePayload compatibility
                    self.handleClickEvent(payload)
                } else {
                    logger.warning("Invalid click event data")
                }
            }

            messager.onExtensionMessage(.heartbeat) { [weak self] _ in
                guard let self = self else { return }
                logger.warning("message from finder plugin heartbeat")
                pluginRunning = true
                sendMenuConfigurationUpdate()
            }

            sendObserveDirMessage()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        messager.sendMessage(name: "quit", data: MessagePayload(action: "quit", target: [], trigger: "unknown"))
        logger.info("applicationWillTerminate")
    }

    // MARK: - Message Handlers

    func sendObserveDirMessage() {
        let target: [String] = appState.dirs.map { $0.url.path() }

        messager.sendMessage(name: "running", data: MessagePayload(action: "running", target: target))
        if !pluginRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.sendObserveDirMessage()
            }
        }
    }

    func sendMenuConfigurationUpdate() {
        // Build menu config from AppState
        let actionMenuItems = appState.actions.map { $0.toActionMenuItem() }
        let appMenuItems = appState.apps.map { $0.toAppMenuItem() }
        let newFileMenuItems = appState.newFiles.map { NewFileMenuItem(id: $0.id, name: $0.name, ext: $0.ext, icon: $0.icon) }
        let commonDirMenuItems = appState.cdirs.map { CommonDirMenuItem(id: $0.id, name: $0.name, icon: $0.icon) }

        let config = MenuConfigPayload(
            actions: actionMenuItems,
            apps: appMenuItems,
            newFiles: newFileMenuItems,
            commonDirs: commonDirMenuItems
        )

        // Send using type-safe API
        messager.sendMenuConfig(config)
        logger.info("Sent menu configuration to extension: \(actionMenuItems.count) actions, \(appMenuItems.count) apps")
    }

    func handleClickEvent(_ payload: MessagePayload) {
        logger.info("Handling click event: \(payload.action)")

        switch payload.action {
        case "open":
            self.openApp(rid: payload.rid, target: payload.target)
        case "actioning":
            self.actionHandler(rid: payload.rid, target: payload.target, trigger: payload.trigger)
        case "Create File":
            self.createFile(rid: payload.rid, target: payload.target)
        case "common-dirs":
            self.openCommonDirs(target: payload.target)
        default:
            self.logger.warning("Unknown click event action: \(payload.action)")
        }
    }

    func handleClickEvent(_ event: ClickEventPayload) {
        logger.info("Handling click event: \(event.itemId) type=\(event.itemType.rawValue)")

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

    // MARK: - File Operations

    func openCommonDirs(target: [String]) {
        logger.info("开始打开常用目录，目标路径：\(target)")

        for dirPath in target {
            let path = dirPath.removingPercentEncoding ?? dirPath
            let url = URL(fileURLWithPath: path, isDirectory: true)

            logger.info("正在打开目录：\(path)")
            NSWorkspace.shared.open(url)
        }

        logger.info("常用目录打开操作完成")
    }

    func openApp(rid: String, target: [String]) {
        guard let rcitem = appState.getAppItem(rid: rid) else {
            logger.warning("when openapp, but not have app \(rid)")
            return
        }

        let appUrl = rcitem.url
        let config = NSWorkspace.OpenConfiguration()
        config.promptsUserIfNeeded = false

        for dirPath in target {
            let dir = URL(fileURLWithPath: dirPath.removingPercentEncoding ?? dirPath, isDirectory: true)

            config.arguments = rcitem.arguments
            config.environment = rcitem.environment

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
            } else {
                logger.info("starting open dir .........\(dir.path), app:\(appUrl.path())")
                NSWorkspace.shared.open([dir], withApplicationAt: appUrl, configuration: config) { runningApp, error in
                    if let error = error {
                        print("Error opening application: \(error.localizedDescription)")
                    } else if let runningApp = runningApp {
                        print("Successfully opened application: \(runningApp.localizedName ?? "Unknown")")
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    func getUniqueFilePath(dir: String, ext: String) -> String {
        let fileManager = FileManager.default
        let baseFileName = String(localized: "Untitled")
        var filePath = "\(dir)\(baseFileName)\(ext)"
        var counter = 1

        while fileManager.fileExists(atPath: filePath) {
            let newFileName = "\(baseFileName)\(counter)"
            filePath = "\(dir)\(newFileName)\(ext)"
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

            if let permDir = appState.dirs.first(where: { permd in
                item.contains(permd.url.path())
            }) {
                var isStale = false
                do {
                    let folderURL = try URL(resolvingBookmarkData: permDir.bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

                    if isStale {
                        // 重新创建 bookmarkData
                    }

                    let success = folderURL.startAccessingSecurityScopedResource()
                    if success {
                        try fm.removeItem(atPath: item.removingPercentEncoding ?? item)
                        folderURL.stopAccessingSecurityScopedResource()
                    } else {
                        logger.warning("fail access scope \(permDir.url.path)")
                    }
                } catch {
                    logger.error("delete \(target) file run error \(error)")
                }
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

        if let dir = appState.dirs.first(where: {
            dirPath.contains($0.url.path)
        }) {
            var isStale = false
            do {
                let folderURL = try URL(resolvingBookmarkData: dir.bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

                let success = folderURL.startAccessingSecurityScopedResource()
                if success {
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
                    folderURL.stopAccessingSecurityScopedResource()
                } else {
                    logger.warning("fail access scope \(dir.url.path)")
                }
            } catch {
                print("解析 bookmark 失败：\(error)")
            }
        }
    }
}
