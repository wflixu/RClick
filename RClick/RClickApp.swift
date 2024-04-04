//
//  RClickApp.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import SwiftData
import SwiftUI

@main
struct RClickApp: App {
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        MenuBarExtra(
            "RClick", systemImage: "star", isInserted: $showMenuBarExtra
        ) {
            MenuBarView()
        }
        
        Settings {
            SettingsView()
            
        }
    }
}
