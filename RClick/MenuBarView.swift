//
//  MenuBarView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import Combine
import SwiftUI

// MARK: - 打开设置窗口

/// 调出设置窗口：不存在则由 SwiftUI 创建，已存在则前置，最后激活 App——
/// LSUIElement 应用不会自己抢焦点，必须显式 activate。
@MainActor
func showSettingsWindow(openWindow: OpenWindowAction) {
    openWindow(id: Constants.settingsWindowID)

    if let existingWindow = NSApplication.shared.windows.first(where: {
        $0.identifier?.rawValue == Constants.settingsWindowID
    }) {
        existingWindow.makeKeyAndOrderFront(nil)
    }
    NSApplication.shared.activate(ignoringOtherApps: true)
}

/// MenuBarExtra 的标签视图。菜单栏图标从 App 启动第一刻就常驻渲染，这个视图
/// 连同它对 `openSettingsRequested` 的订阅从启动早期就存在；而 MenuBarExtra 的
/// 内容视图（MenuBarView）要等用户第一次点开菜单才构建——启动期的"打开设置"
/// 请求（手动 open 的 applicationDidFinishLaunching、已运行时的 reopen）只能
/// 由这里接住。
struct MenuBarExtraLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image("MenuBar")
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
                showSettingsWindow(openWindow: openWindow)
            }
    }
}

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
        showSettingsWindow(openWindow: openWindow)
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
