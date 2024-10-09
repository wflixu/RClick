//
//  MenuBarView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) var openWindow: OpenWindowAction
    
    let messager = Messager.shared
    
    var body: some View {
        VStack {
           
            Button(action: actionSettings) {
                Image(systemName: "gearshape")
                Text("Settings")
            }
            .keyboardShortcut(",", modifiers: [.command])
            
            Button(action: actionQuit) {
                Image(systemName: "xmark.square")
                Text("Quit")
            }
            .keyboardShortcut("q", modifiers: [.command])
            
        }
    }

    private func actionSettings () {
        openWindow(id: Constants.settingsWindowID)
    }
    private func actionQuit() {
       
        messager.sendMessage(name: "quit", data: MessagePayload(action: "quit"))
      
        Task {
            try await Task.sleep(nanoseconds:UInt64(1.0 * 1e9))
             NSApplication.shared.terminate(self)
        }
    }

}

#Preview {
    MenuBarView()
}
