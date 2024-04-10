//
//  MenuBarView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import SwiftUI

struct MenuBarView: View {
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

    private func actionQuit() {
        print("action action quirt")
        NSApplication.shared.terminate(self)
    }

    private func actionSettings() {}
}

#Preview {
    MenuBarView()
}
