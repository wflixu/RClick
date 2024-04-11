//
//  RClickApp.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//
import Foundation
import os.log
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: subsystem, category: "main")


let channel = AppCommChannel()

@main
struct RClickApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    @Environment(\.scenePhase) var scenePhase: ScenePhase
    @Environment(\.openWindow) var openWindow

    
    var body: some Scene {
    

        MenuBarExtra(
            "RClick", image: "MenuBar", isInserted: $showMenuBarExtra
        ) {
            MenuBarView()
        }

        Settings {
            SettingsView()
        }
        .defaultAppStorage(.group)
    }
}


