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

    private func actionSettings() {
        openWindow(id: Constants.settingsWindowID)

        let windows = NSApplication.shared.windows

        // 查找已存在的目标窗口
        if let existingWindow = windows.first(where: { $0.identifier?.rawValue == Constants.settingsWindowID }) {
            existingWindow.makeKeyAndOrderFront(nil) // 将窗口置于最前
            NSApplication.shared.activate(ignoringOtherApps: true) // 激活应用
        }
    }

    private func actionQuit() {
        messager.sendMessage(name: "quit", data: MessagePayload(action: "quit"))

        Task {
            try await Task.sleep(nanoseconds: UInt64(1.0 * 1e9))

            NSApplication.shared.terminate(self)
        }
    }
}

#Preview {
    MenuBarView()
}
