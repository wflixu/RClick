//
//  GeneralSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/10.
//

import AppKit
import Cocoa
import FinderSync
import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsTabView: View {
    @AppLog(category: "settings-general")
    private var logger

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @EnvironmentObject var store: AppState

    @State private var finderSyncStatus: PermissionStatus = .unknown
    @State private var fullDiskAccessStatus: PermissionStatus = .unknown
    @State private var accessibilityStatus: PermissionStatus = .unknown

    @State private var showDirImporter = false
    @State private var wrongFold = false
    @State private var showAlert = false

    @Environment(\.modelContext) private var modelContext

    let messager = Messager.shared

    var body: some View {
        Form {
            // MARK: - 第一组：主要控制
            Section {
                Toggle("启用 RClick", isOn: Binding(
                    get: { finderSyncStatus == .enabled },
                    set: { newValue in
                        if newValue {
                            // 开启：如果未启用，打开文件提供程序设置
                            if !FIFinderSyncController.isExtensionEnabled {
                                openFileProviderSettings()
                            }
                        } else {
                            // 关闭：同样打开设置让用户手动关闭
                            openFileProviderSettings()
                        }
                    }
                ))

                Toggle("登录时启动", isOn: $launchAtLogin)
            } header: {
                Text("主要控制")
            } footer: {
                Text("在文件提供程序中启用 RClick 以在右键菜单中显示功能")
            }

            // MARK: - 第二组：权限
            Section {
                // Finder 扩展状态
                HStack {
                    Label("Finder 扩展", systemImage: finderSyncStatus.icon)
                        .foregroundColor(finderSyncStatus.color)
                    Spacer()
                    Text(finderSyncStatus.description)
                        .foregroundColor(.secondary)
                }

                // 完全磁盘访问权限
                HStack {
                    Label("完全磁盘访问权限", systemImage: fullDiskAccessStatus.icon)
                        .foregroundColor(fullDiskAccessStatus.color)
                    Spacer()
                    Button("设置…") {
                        openFullDiskAccessSettings()
                    }
                }

                // 辅助功能权限
                HStack {
                    Label("辅助功能", systemImage: accessibilityStatus.icon)
                        .foregroundColor(accessibilityStatus.color)
                    Spacer()
                    Button("设置…") {
                        openAccessibilitySettings()
                    }
                }
            } header: {
                Text("权限")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("文件提供程序：在列表中选择「RClick」以启用 Finder 右键菜单")
                        .foregroundColor(.secondary)
                    Text("完全磁盘访问权限：用于在受保护目录中创建和删除文件")
                        .foregroundColor(.secondary)
                    if fullDiskAccessStatus != .enabled {
                        Text("添加 RClick 到列表：点击「+」→ 前往「应用程序」→ 选择「RClick.app」")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // MARK: - 第三组：设置管理
            Section {
                // 备份
                HStack {
                    Text("备份")
                    Spacer()
                    HStack(spacing: 12) {
                        Button("导出…") {
                            exportSettings()
                        }
                        Button("导入…") {
                            importSettings()
                        }
                    }
                }

                // 日志
                HStack {
                    Text("日志")
                    Spacer()
                    Button("导出日志…") {
                        exportLogs()
                    }
                }

                // 重置所有设置
                HStack {
                    Spacer()
                    Button("重置所有设置…") {
                        resetAllSettings()
                    }
                    .foregroundColor(.red)
                }
            } header: {
                Text("设置管理")
            } footer: {
                Text("重置所有设置将恢复默认配置，此操作不可逆")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            updatePermissionStatus()
        }
        .onForeground {
            updatePermissionStatus()
        }
        .alert(
            Text("无效文件夹"),
            isPresented: $wrongFold
        ) {
            Button("确定") {
                showDirImporter = true
            }
        } message: {
            Text("所选文件夹是已选文件夹的子目录，请选择其他文件夹。")
        }
        .alert(
            Text("未授权文件夹"),
            isPresented: $showAlert
        ) {
            Button("确定") {
                showDirImporter = true
            }
        } message: {
            Text("必须授予文件夹访问权限才能使用此功能。")
        }
    }

    // MARK: - 权限状态检测

    private func updatePermissionStatus() {
        // Finder 扩展状态
        finderSyncStatus = FIFinderSyncController.isExtensionEnabled ? .enabled : .disabled

        // 完全磁盘访问权限检测（使用 PermissionChecker）
        fullDiskAccessStatus = PermissionChecker.hasFullDiskAccess() ? .enabled : .disabled

        // 辅助功能权限检测（使用 PermissionChecker）
        accessibilityStatus = PermissionChecker.hasAccessibilityPermission() ? .enabled : .disabled
    }

    private func hasFullDiskAccess() -> Bool {
        return PermissionChecker.hasFullDiskAccess()
    }

    private func hasAccessibilityPermission() -> Bool {
        return PermissionChecker.hasAccessibilityPermission()
    }

    // MARK: - 权限设置打开

    private func openFileProviderSettings() {
        // 打开系统设置的"文件提供程序"扩展管理界面
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.AppleFileProvider")!)
    }

    private func openFullDiskAccessSettings() {
        PermissionChecker.openFullDiskAccessSettings()
    }

    private func openAccessibilitySettings() {
        PermissionChecker.openAccessibilitySettings()
    }

    // MARK: - 设置管理

    private func exportSettings() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.propertyList]
        savePanel.nameFieldStringValue = "RClick_Settings.plist"
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            // TODO: 实现设置导出逻辑
            logger.info("导出设置到：\(url.path)")
        }
    }

    private func importSettings() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.propertyList]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else { return }
            // TODO: 实现设置导入逻辑
            logger.info("从以下路径导入设置：\(url.path)")
        }
    }

    private func exportLogs() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "RClick_Log.txt"
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            // TODO: 实现日志导出逻辑
            logger.info("导出日志到：\(url.path)")
        }
    }

    private func resetAllSettings() {
        let alert = NSAlert()
        alert.messageText = "重置所有设置？"
        alert.informativeText = "此操作将删除所有自定义配置，恢复到默认状态。此操作不可逆。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "重置")
        alert.addButton(withTitle: "取消")
        alert.buttons[0].hasDestructiveAction = true

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // TODO: 实现重置逻辑
            logger.info("重置所有设置")
        }
    }
}

// MARK: - 权限状态枚举

enum PermissionStatus {
    case enabled
    case disabled
    case unknown

    var icon: String {
        switch self {
        case .enabled:
            return "checkmark.circle.fill"
        case .disabled:
            return "circle"
        case .unknown:
            return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .enabled:
            return .green
        case .disabled:
            return .gray
        case .unknown:
            return .yellow
        }
    }

    var description: String {
        switch self {
        case .enabled:
            return "已授权"
        case .disabled:
            return "未授权"
        case .unknown:
            return "未知"
        }
    }
}
