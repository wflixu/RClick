//
//  AppDelegate.swift
//  RClick
//
//  Created by 李旭 on 2024/4/10.
//

import AppKit
import Cocoa
import Foundation
import os.log

private let logger = Logger(subsystem: subsystem, category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {
    let messager = Messager.shared
    var folderItemStore = FolderItemStore()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 在 app 启动后执行的函数
        logger.notice("App -------------------------- 已启动")

        Task {
            await channel.setup(store: folderItemStore)
        }

//        NSApplication.shared.openSettings()
        messager.start(name: Key.messageFromFinder)
        messager.sendMessage(name: "running", data: MessagePayload(action: "running"))
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NSApplication.shared.openSettings()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        
    }
}
