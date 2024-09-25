//
//  SettingsWindow.swift
//  RClick
//
//  Created by 李旭 on 2024/9/25.
//

import SwiftUI

struct SettingsWindow: Scene {
    let onAppear: () -> Void

    var body: some Scene {
        Window("Settings", id: Constants.settingsWindowID) {
            SettingsView().tabViewStyle(.automatic)
                
        }
        
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 615)
    }
    
}
