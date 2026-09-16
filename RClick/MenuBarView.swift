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
                Text(appLocalized: "Settings")
            }
            .keyboardShortcut(",", modifiers: [.command])

            Button(action: actionQuit) {
                Image(systemName: "xmark.square")
                Text(appLocalized: "Quit")
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }

    @MainActor
    private func actionSettings() {
        openWindow(id: Constants.settingsWindowID)

        let windows = NSApplication.shared.windows

        // 查找已存在的目标窗口
        if let existingWindow = windows.first(where: { $0.identifier?.rawValue == Constants.settingsWindowID }) {
            existingWindow.makeKeyAndOrderFront(nil) // 将窗口置于最前
            NSApplication.shared.activate(ignoringOtherApps: true) // 激活应用
        }
    }

    @MainActor
    private func actionQuit() {
        messager.sendQuitNotification()

        // 等一拍让菜单栏弹出面板收起，再退出。
        //
        // 这里唯一的抛出是任务被取消；用户点的是"退出"，不该因为一次取消就被留在这里，
        // 所以显式吞掉取消、继续走完 —— 而不是让错误悄悄丢掉（这条警告说的正是后者）。
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))

            NSApplication.shared.terminate(self)
        }
    }
}

#Preview {
    MenuBarView()
}
