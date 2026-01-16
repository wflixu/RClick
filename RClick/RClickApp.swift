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

        // Preload icons for all apps to improve performance
        Task {
            IconCacheManager.shared.preloadIcons(for: appState.apps.map { $0.url })
        }

        messager.on(name: Key.messageFromFinder) { payload in

            self.logger.info("recive mess from finder by app \(payload.description)")
            switch payload.action {
            case "open":
                self.openApp(rid: payload.rid, target: payload.target)
            case "actioning":
                self.actionHandler(rid: payload.rid, target: payload.target, trigger: payload.trigger)
            case "Create File":
                self.createFile(rid: payload.rid, target: payload.target)
            case "common-dirs":
                self.openCommonDirs(target: payload.target)
            case "heartbeat":
                self.logger.warning("message from finder plugin heartbeat")
                self.pluginRunning = true
                // Send menu configuration when extension connects
                self.sendMenuConfigurationUpdate()
            default:
                self.logger.warning("actioning payload no matched")
            }
        }
        sendObserveDirMessage()

    }
    
    func openCommonDirs(target: [String]) {
        logger.info("开始打开常用目录，目标路径: \(target)")

        for dirPath in target {
            let path = dirPath.removingPercentEncoding ?? dirPath
            let url = URL(fileURLWithPath: path, isDirectory: true)

            logger.info("正在打开目录: \(path)")
            NSWorkspace.shared.open(url)
        }

        logger.info("常用目录打开操作完成")
    }

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
        // Convert actions and apps to menu items and store in UserDefaults
        let actionMenuItems = appState.actions.map { $0.toActionMenuItem() }
        let appMenuItems = appState.apps.map { $0.toAppMenuItem() }

        // Store in UserDefaults for extension to access
        if let actionData = try? JSONEncoder().encode(actionMenuItems) {
            UserDefaults.group.set(actionData, forKey: Key.actionMenuItems)
            logger.info("Sent \(actionMenuItems.count) action menu items to extension")
        }

        if let appData = try? JSONEncoder().encode(appMenuItems) {
            UserDefaults.group.set(appData, forKey: Key.appMenuItems)
            logger.info("Sent \(appMenuItems.count) app menu items to extension")
        }

        // Notify extension to reload menu configuration
        messager.sendMessage(name: Key.messageFromMain, data: MessagePayload(action: "update-menu", target: [], rid: ""))
        logger.info("Notified extension of menu configuration update")
    }

    // 创建一个当前文件夹下的不存在的新建文件名
    func getUniqueFilePath(dir: String, ext: String) -> String {
        // 创建文件管理器
        let fileManager = FileManager.default

        // 基础文件名
        let baseFileName = String(localized: "Untitled")

        // 初始文件路径
        var filePath = "\(dir)\(baseFileName)\(ext)"

        // 文件计数器
        var counter = 1

        // 查询文件是否存在，直到找到一个不存在的路径
        while fileManager.fileExists(atPath: filePath) {
            // 更新文件名和路径，使用计数器递增
            let newFileName = "\(baseFileName)\(counter)"
            filePath = "\(dir)\(newFileName)\(ext)"
            counter += 1
        }

        return filePath
    }

    func actionHandler(rid: String, target: [String], trigger: String) {
        guard let rcitem = appState.getActionItem(rid: rid) else {
            logger.warning("when createFile,but not have fileType ")
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
        logger.info("---- showAirDrop  trigger:\(trigger)")
        let fm = FileManager.default
        var fileURLs: [URL] = []

        if trigger == "ctx-container" {
            // 显示警告对话框
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
                // 显示警告对话框
                let alert = NSAlert()
                alert.messageText = "警告"
                alert.informativeText = "无法分享系统保护文件夹：\(decodedPath)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                alert.runModal()

                logger.warning("试图分享受保护的系统文件夹，操作已被阻止: \(decodedPath)")
                continue
            }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: decodedPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    logger.warning("不能通过 AirDrop 分享文件夹: \(decodedPath)")
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
                logger.info("已通过 AirDrop 分享文件: \(fileURLs.map { $0.path }.joined(separator: ", "))")
            } else {
                logger.warning("无法获取 AirDrop 服务")
            }
        }
    }

    // 显示目标文件夹下的隐藏的所有文件和文件夹
    func unhideFilesAndDirs(_ target: [String], _ trigger: String) {
        logger.info("开始取消隐藏文件和目录，目标路径: \(target)")
        if let dirPath = target.first {
            let fileManager = FileManager.default
            let path = dirPath.removingPercentEncoding ?? dirPath
            logger.info("处理主目录: \(path)")
            var url = URL(fileURLWithPath: path)

            // 仅处理目录下一级的内容
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isHiddenKey], options: [.skipsPackageDescendants])
                for case var fileURL in contents {
                    do {
                        var resourceValues = URLResourceValues()
                        resourceValues.isHidden = false
                        try fileURL.setResourceValues(resourceValues)
                        logger.info("成功取消隐藏: \(fileURL.path)")
                    } catch {
                        logger.error("取消隐藏失败: \(fileURL.path): \(error)")
                    }
                }
            } catch {
                logger.error("获取目录内容失败: \(error)")
            }

            // 处理目录本身
            do {
                var resourceValues = URLResourceValues()
                resourceValues.isHidden = false
                try url.setResourceValues(resourceValues)
                logger.info("成功取消隐藏主目录: \(path)")
            } catch {
                logger.error("取消隐藏主目录失败: \(path): \(error)")
            }
            logger.info("取消隐藏操作完成，共处理目录: \(path)")
        }
    }

    // 隐藏目标文件或文件夹
    func hideFilesAndDirs(_ target: [String], _ trigger: String) {
        logger.info("开始隐藏文件和目录，目标路径: \(target), 触发器: \(trigger)")
        let fileManager = FileManager.default

        if trigger == "ctx-container", let dirPath = target.first {
            let path = dirPath.removingPercentEncoding ?? dirPath
            logger.info("处理主目录: \(path)")
            let url = URL(fileURLWithPath: path)

            // 仅处理目录下一级的内容
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsPackageDescendants])
                for case var fileURL in contents {
                    // 如果是受保护的文件路径，跳过
                    if Utils.isProtectedFolder(fileURL.path) {
                        logger.warning("跳过受保护的文件路径: \(fileURL.path)")
                        continue
                    }
                    do {
                        var resourceValues = URLResourceValues()
                        resourceValues.isHidden = true
                        try fileURL.setResourceValues(resourceValues)
                        logger.info("成功隐藏: \(fileURL.path)")
                    } catch {
                        logger.error("隐藏失败: \(fileURL.path): \(error)")
                    }
                }
            } catch {
                logger.error("获取目录内容失败: \(error)")
            }
        } else if trigger == "ctx-items" {
            for dirPath in target {
                let path = dirPath.removingPercentEncoding ?? dirPath
                logger.info("处理路径: \(path)")
                var url = URL(fileURLWithPath: path)

                // 处理单个文件或目录
                if Utils.isProtectedFolder(path) {
                    logger.warning("跳过受保护的文件路径: \(path)")
                    continue
                }
                do {
                    var resourceValues = URLResourceValues()
                    resourceValues.isHidden = true
                    try url.setResourceValues(resourceValues)
                    logger.info("成功隐藏: \(path)")
                } catch {
                    logger.error("隐藏失败: \(path): \(error)")
                }
            }
        }
        logger.info("隐藏操作完成")
    }

    func copyPath(_ target: [String]) {
        if let dirPath = target.first {
            let pasteboard = NSPasteboard.general
            // must do to fix bug
            pasteboard.clearContents()

            pasteboard.setString(dirPath.removingPercentEncoding ?? dirPath, forType: .string)
        }
    }

    func deleteFoldorFile(_ target: [String], _ trigger: String) {
        logger.info("---- deleteFoldorFile  trigger:\(trigger)")
        let fm = FileManager.default
        // 如果是容器，无法删除
        if trigger == "ctx-container" {
            // 显示警告对话框
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
                // 显示警告对话框
                let alert = NSAlert()
                alert.messageText = "警告"
                alert.informativeText = "无法删除系统保护文件夹：\(decodedPath)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                alert.runModal()

                logger.warning("试图删除受保护的系统文件夹，操作已被阻止: \(decodedPath)")
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
                        // createBookmark(for: folderURL) // 这里可以调用之前的函数
                    }

                    // 进入安全范围
                    let success = folderURL.startAccessingSecurityScopedResource()
                    if success {
                        try fm.removeItem(atPath: item.removingPercentEncoding ?? item)
                        // 完成后释放资源
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
            logger.warning("when createFile,but not have fileType \(rid) ")
            return
        }

        let ext = rcitem.ext
        logger.info("create file dir:\(dirPath) -- ext \(ext)")
        // 完整的文件路径
        let filePath = getUniqueFilePath(dir: dirPath.removingPercentEncoding ?? dirPath, ext: ext)

        let fileURL = URL(fileURLWithPath: filePath)

        if let dir = appState.dirs.first(where: {
            dirPath.contains($0.url.path)
        }) {
            var isStale = false
            do {
                let folderURL = try URL(resolvingBookmarkData: dir.bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

                // 进入安全范围
                let success = folderURL.startAccessingSecurityScopedResource()
                if success {
                    do {
                        let fileManager = FileManager.default

                        // 检查是否有有效的模板URL
                        if let templateUrl = rcitem.template {
                            try fileManager.copyItem(at: templateUrl, to: fileURL)
                            logger.info("已成功复制模板到目标路径: \(fileURL.path)")

                        } else {
                            // 从Bundle中获取模板文件
                            if let defaultTemplateURL = Bundle.main.url(forResource: "template", withExtension: ext.replacingOccurrences(of: ".", with: "")) {
                                logger.info("使用模板创建文件，模板路径: \(defaultTemplateURL.path)")
                                try fileManager.copyItem(at: defaultTemplateURL, to: fileURL)
                                logger.info("已成功复制模板到目标路径: \(fileURL.path)")
                            } else {
                                logger.warning("模板文件不存在: \(ext)")
                                // 模板不存在时创建空文件
                                try Data().write(to: fileURL)
                            }
                        }
                    } catch let error as NSError {
                        switch error.domain {
                        case NSCocoaErrorDomain:
                            switch error.code {
                            case NSFileNoSuchFileError:
                                logger.error("文件不存在: \(filePath)")
                            case NSFileWriteOutOfSpaceError:
                                logger.error("磁盘空间不足")
                            case NSFileWriteNoPermissionError:
                                logger.error("没有写入权限: \(filePath)")
                            default:
                                logger.error("创建文件错误: \(error.localizedDescription) (错误码: \(error.code))")
                            }
                        default:
                            logger.error("未处理的错误: \(error.localizedDescription) (错误码: \(error.code))")
                        }
                    }
                    // 完成后释放资源
                    folderURL.stopAccessingSecurityScopedResource()
                } else {
                    logger.warning("fail access scope \(dir.url.path)")
                }
            } catch {
                print("解析 bookmark 失败：\(error)")
            }
        }
    }

    func openApp(rid: String, target: [String]) {
        guard let rcitem = appState.getAppItem(rid: rid) else {
            logger.warning("when openapp,but not have app \(rid)")
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
                // 创建一个 Process 实例
                let process = Process()

                // 设置要运行的二进制文件路径
                process.executableURL = URL(fileURLWithPath: "/Users/lixu/play/rpm/target/debug/rpm")

                // 设置命令行参数（如果有）
                process.arguments = ["--name", "arg2"]

                // 设置标准输出和标准错误
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    // 启动进程
                    try process.run()

                    // 等待进程完成
                    process.waitUntilExit()

                    // 读取输出
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        messager.sendMessage(name: "quit", data: MessagePayload(action: "quit", target: [], trigger: "unknown"))
        logger.info("applicationWillTerminate")
    }
}
