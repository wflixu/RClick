//
//  RClickApp.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import SwiftData
import SwiftUI

let channel = AppCommChannel()

@main
struct RClickApp: App {
    //  @NSApplicationDelegateAdaptor private var appDelegate: MyAppDelegate

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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        MenuBarExtra(
            "RClick", systemImage: "computermouse.fill", isInserted: $showMenuBarExtra
        ) {
            MenuBarView()
        }

        Settings {
            SettingsView()
        }.modelContainer(sharedModelContainer)
            .defaultAppStorage(.group)
    }
}


