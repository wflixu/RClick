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
//let channel = AppCommChannel()

@main
struct RClickApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    @Environment(\.openWindow) var openWindow

    @AppLog(category: "main")
    private var logger
    
    @StateObject var appState = AppState()
    
    

    var body: some Scene {
        SettingsWindow(appState: appState, onAppear: {})
            .defaultAppStorage(.group)

        MenuBarExtra(
            "RClick", image: "MenuBar", isInserted: self.$showMenuBarExtra
        ) {
            MenuBarView()
        }
    }
}



class AppDelegate: NSObject, NSApplicationDelegate {
    
    @AppLog(category: "AppDelegate")
    private var logger

    private var appState: AppState?
    
    let messager = Messager.shared
    var folderItemStore = FolderItemStore()
    var showDockIcon = UserDefaults.group.bool(forKey: Key.showDockIcon)
    var settingsWindow: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 在 app 启动后执行的函数
        logger.notice("App -------------------------- 已启动")
        
//        Task {
//            await channel.setup(store: folderItemStore)
//        }
//
//        messager.start(name: Key.messageFromFinder)
//        messager.sendMessage(name: "running", data: MessagePayload(action: "running"))

//        // 根据某种逻辑设置应用是否显示在 Dock 中
//        if showDockIcon {
//            NSApp.setActivationPolicy(.regular)
//        } else {
//            NSApp.setActivationPolicy(.prohibited)
//        }
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

