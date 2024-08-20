//
//  MenuBarView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import SwiftUI

struct MenuBarView: View {
    let messager = Messager.shared
    var body: some View {
        VStack {
            SettingsLink {
                Image(systemName: "gearshape")
                Text("Settings")
            }
            
            Button(action: actionQuit) {
                Image(systemName: "xmark.square")
                Text("Quit")
            }
            
        }
    }

    func test () {
        
    }
    private func actionQuit() {
       
        messager.sendMessage(name: "quit", data: MessagePayload(action: "quit"))
      
        Task {
            try await Task.sleep(nanoseconds:UInt64(1.0 * 1e9))
            await NSApplication.shared.terminate(self)
        }
    }

}

#Preview {
    MenuBarView()
}
