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

@main
struct RClickApp: App {
      @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Dir.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    @Environment(\.scenePhase) var scenePhase: ScenePhase
    @Environment(\.openWindow) var openWindow

    let center = DistributedNotificationCenter.default()





    var body: some Scene {
    
        
       

        MenuBarExtra(
            "RClick", image: "MenuBar", isInserted: $showMenuBarExtra
        ) {
            MenuBarView()
        }

        Settings {
            SettingsView()
        }
        .modelContainer(sharedModelContainer)
        .defaultAppStorage(.group)
    }
}

let channel = AppCommChannel()
