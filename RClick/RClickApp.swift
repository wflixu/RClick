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

//
// let channel = AppCommChannel()

@main
struct RClickApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    @Environment(\.openWindow) var openWindow

    @AppLog(category: "main")
    private var logger
    let messager = Messager.shared

    @StateObject var appState = AppState()

    var body: some Scene {
        SettingsWindow(appState: appState, onAppear: {
            self.logger.info("settings window is appear")
            appDelegate.appState = appState
        })
        .defaultAppStorage(.group)

        MenuBarExtra(
            "RClick", image: "MenuBar", isInserted: $showMenuBarExtra
        ) {
            MenuBarView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    @AppLog(category: "AppDelegate")
    private var logger

    var appState: AppState?

    let messager = Messager.shared
    var showDockIcon = UserDefaults.group.bool(forKey: Key.showDockIcon)
    var settingsWindow: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 在 app 启动后执行的函数
        logger.notice("App -------------------------- 已启动")

//        Task {
//            await channel.setup(store: folderItemStore)
//        }
//
        // 通知扩展主app已经启动了
        messager.sendMessage(name: "running", data: MessagePayload(action: "test", target: ["/test"], rid: "test"))
        messager.on(name: Key.messageFromFinder) { payload in

            self.logger.info("recive mess from finder by app \(payload.description)")
            switch payload.action {
            case "open":
                self.openApp(rid: payload.rid, target: payload.target)
            case "actioning":
                self.actionHandler(rid: payload.rid, target: payload.target)
            case "Create File":
                self.createFile(rid: payload.rid, target: payload.target)
            default:
                self.logger.warning("actioning payload no matched")
            }
        }
        // 拓展还没有启动，接收不到消息，所以要等一会
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            var target: [String] = []
            if let dirs = self.appState?.dirs {
                target = dirs.map {  $0.url.path() }
            }
            self.messager.sendMessage(name: "running", data: MessagePayload(action: "running", target: target))
        }

//        // 根据某种逻辑设置应用是否显示在 Dock 中
//        if showDockIcon {
//            NSApp.setActivationPolicy(.regular)
//        } else {
//            NSApp.setActivationPolicy(.prohibited)
//        }
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
        guard let appState = appState else {
            logger.warning("when creatFile,but appState is not ready")
            return
        }
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
        do {
            for item in target {
                try fm.removeItem(atPath: item.removingPercentEncoding ?? item)
            }
        } catch {
            logger.error("delete \(target) file run error \(error)")
        }
    }

    func createFile(rid: String, target: [String]) {
        guard let appState = appState else {
            logger.warning("when creatFile,but appState is not ready")
            return
        }
        guard let rcitem = appState.getFileType(rid: rid), let dirPath = target.first else {
            logger.warning("when createFile,but not have fileType ")
            return
        }

        let ext = rcitem.ext

        logger.info("create file dir:\(dirPath) -- ext \(ext)")
        // 完整的文件路径
        let filePath = getUniqueFilePath(dir: dirPath.removingPercentEncoding ?? dirPath, ext: ext)

        let emptyDocxData = Data()
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            try emptyDocxData.write(to: fileURL)
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
    }

    func openApp(rid: String, target: [String]) {
        guard let appState = appState else {
            logger.warning("when openapp,but appState is not ready")
            return
        }
        guard let rcitem = appState.getAppItem(rid: rid) else {
            logger.warning("when openapp,but not have app ")
            return
        }

        let appUrl = rcitem.url
        let config = NSWorkspace.OpenConfiguration()
        config.promptsUserIfNeeded = true

        for dirPath in target {
            let dir = URL(fileURLWithPath: dirPath, isDirectory: true)
            if appUrl.path.hasSuffix("WezTerm.app") {
                config.arguments = ["--cwd", dirPath]
                NSWorkspace.shared.openApplication(at: appUrl, configuration: config)
            } else {
                logger.info("starting open dir .........")
                NSWorkspace.shared.open([dir], withApplicationAt: appUrl, configuration: config)
            }
        }
    }

//    func applicationDidBecomeActive(_ notification: Notification) {
//        NSApplication.shared.openSettings()
//    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        messager.sendMessage(name: "quit", data: MessagePayload(action: "quit"))
        logger.info("applicationWillTerminate")
    }
}
