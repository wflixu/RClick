//
//  AppDelegate.swift
//  RClick
//
//  Created by 李旭 on 2024/4/10.
//

import Cocoa
import Foundation
import os.log

private let logger = Logger(subsystem: subsystem, category: "main")


class AppDelegate: NSObject, NSApplicationDelegate {
   
    let messager = Messager()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 在 app 启动后执行的函数
        print("App -------------------------- 已启动")
        messager.start(name: Key.messageFromFinder)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {}


}
