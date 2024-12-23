//
//  RClickApp.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//
import AppKit
import Foundation
import SwiftUI

import FinderSync
import os.log

@main
struct RClickApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    @Environment(\.openWindow) var openWindow

    @AppLog(category: "main")
    private var logger
    let messager = Messager.shared

    @StateObject var appState = AppState.shared

    var body: some Scene {
        SettingsWindow(appState: appState, onAppear: {})
            .defaultAppStorage(.group)

        MenuBarExtra(
            "RClick", image: "MenuBar", isInserted: $showMenuBarExtra
        ) {
            MenuBarView()
        }
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
    var showDockIcon = UserDefaults.group.bool(forKey: Key.showDockIcon)
    var settingsWindow: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 在 app 启动后执行的函数

        messager.on(name: Key.messageFromFinder) { payload in

            self.logger.info("recive mess from finder by app \(payload.description)")
            switch payload.action {
            case "open":
                self.openApp(rid: payload.rid, target: payload.target)
            case "actioning":
                self.actionHandler(rid: payload.rid, target: payload.target)
            case "Create File":
                self.createFile(rid: payload.rid, target: payload.target)
            case "heartbeat":
                self.logger.warning("message from finder plugin heartbeat")
                self.pluginRunning = true
            default:
                self.logger.warning("actioning payload no matched")
            }
        }

        sendObserveDirMessage()
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

    func actionHandler(rid: String, target: [String]) {
        guard let rcitem = appState.getActionItem(rid: rid) else {
            logger.warning("when createFile,but not have fileType ")
            return
        }

        switch rcitem.id {
        case "copy-path":
            copyPath(target)
        case "delete-direct":
            deleteFoldorFile(target)
        default:
            logger.warning("no action id matched")
        }
    }

    func copyPath(_ target: [String]) {
        if let dirPath = target.first {
            let pasteboard = NSPasteboard.general
            // must do to fix bug
            pasteboard.clearContents()

            pasteboard.setString(dirPath.removingPercentEncoding ?? dirPath, forType: .string)
        }
    }

    func deleteFoldorFile(_ target: [String]) {
        logger.info("---- deleteFoldorFile")

        let fm = FileManager.default

        for item in target {
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
                        if ext == ".xlsx" {
                            let _ = try XLSXFile(filepath: filePath)
                        } else {
                            let emptyDocxData = Data()
                            try emptyDocxData.write(to: fileURL)
                        }

                        print("Empty DOCX file created successfully at \(filePath)")
                    } catch let error as NSError {
                        switch error.domain {
                        case NSCocoaErrorDomain:
                            switch error.code {
                            case NSFileNoSuchFileError:
                                print("Error: No such file exists at \(filePath)")
                            case NSFileWriteOutOfSpaceError:
                                print("Error: Not enough disk space to write the file")
                            case NSFileWriteNoPermissionError:
                                print("Error: No permission to write the file at \(filePath)")
                            default:
                                print("Error: \(error.localizedDescription) (\(error.code))")
                            }
                        default:
                            print("Unhandled error: \(error.localizedDescription) (\(error.code))")
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
        messager.sendMessage(name: "quit", data: MessagePayload(action: "quit"))
        logger.info("applicationWillTerminate")
    }
}
