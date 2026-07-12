//
//  SettingsWindow.swift
//  RClick
//
//  Created by 李旭 on 2024/9/25.
//

import SwiftUI

struct SettingsWindow: Scene {
    @ObservedObject var appState: AppState
    
    @EnvironmentObject var updateManager: UpdateManager
    
    let onAppear: () -> Void

    var body: some Scene {
        Window(AppLocalization.localized("Settings"), id: Constants.settingsWindowID) {
            SettingsView()
                .environmentObject(appState)
                .onAppear {
                    onAppear()
                }
                .frame(minWidth: 700, minHeight: 480)
                .sheet(isPresented: $updateManager.showUpdateSheet) {
                    UpdateView(updateManager: updateManager)
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 480)
    }
    
}
