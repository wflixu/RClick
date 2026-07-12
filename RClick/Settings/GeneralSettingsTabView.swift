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
    @AppStorage(Key.showMenuBarExtra, store: .group) private var showMenuBarExtra = true
    @EnvironmentObject var store: AppState

    @State private var finderSyncStatus: PermissionStatus = .unknown
    @State private var accessibilityStatus: PermissionStatus = .unknown
    @State private var showFolderPermissionsSheet = false

    @State private var showDirImporter = false
    @State private var wrongFold = false
    @State private var showAlert = false
    @State private var showLanguageRestartAlert = false

    let messager = Messager.shared

    var body: some View {
        Form {
            // MARK: - 第一组：主要控制
            Section {
                Toggle(isOn: Binding(
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
                )) {
                    Text(appLocalized: "Enable RClick")
                }

                Toggle(isOn: $showMenuBarExtra) {
                    Text(appLocalized: "Show icon in menu bar")
                }

                Toggle(isOn: $launchAtLogin) {
                    Text(appLocalized: "Launch at login")
                }

                Picker(selection: Binding(
                    get: { store.selectedLanguage },
                    set: { newValue in
                        guard newValue != store.selectedLanguage else { return }
                        store.selectedLanguage = newValue
                        showLanguageRestartAlert = true
                    }
                )) {
                    Text(appLocalized: "Automatic").tag(AppLanguage.automatic)
                    Text(appLocalized: "Simplified Chinese").tag(AppLanguage.simplifiedChinese)
                    Text(appLocalized: "English").tag(AppLanguage.english)
                    Text(appLocalized: "Japanese").tag(AppLanguage.japanese)
                } label: {
                    Text(appLocalized: "Language")
                }
            } header: {
                Text(appLocalized: "Main Controls")
            } footer: {
                Text(appLocalized: "Enable RClick in File Provider to show its actions in Finder context menus")
                    .fixedSize(horizontal: false, vertical: true)
            }

            // MARK: - 第二组：权限
            Section {
                // Finder 扩展状态
                LabeledContent {
                    Text(finderSyncStatus.description)
                        .foregroundColor(.secondary)
                } label: {
                    Label(AppLocalization.localized("Finder Extension"), systemImage: finderSyncStatus.icon)
                        .foregroundColor(finderSyncStatus.color)
                }

                // 辅助功能权限
                LabeledContent {
                    Button(AppLocalization.localized("Settings…")) {
                        openAccessibilitySettings()
                    }
                } label: {
                    Label(AppLocalization.localized("Accessibility"), systemImage: accessibilityStatus.icon)
                        .foregroundColor(accessibilityStatus.color)
                }

                // 文件夹权限（Bookmark）
                LabeledContent {
                    HStack(spacing: 8) {
                        Text("\(store.bookmarkManager.authorizedDirectories.count)")
                            .foregroundColor(.secondary)
                        Button(AppLocalization.localized("Manage…")) {
                            showFolderPermissionsSheet = true
                        }
                    }
                } label: {
                    Label(AppLocalization.localized("Folder Permissions"), systemImage: "folder.badge.person.crop")
                }
            } header: {
                Text(appLocalized: "Permissions")
            } footer: {
                Text(appLocalized: "File Provider: Select \"RClick\" in the list to enable the Finder context menu")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // MARK: - 第三组：设置管理
            Section {
                // 备份
                LabeledContent {
                    HStack(spacing: 12) {
                        Button(AppLocalization.localized("Export…")) {
                            exportSettings()
                        }
                        Button(AppLocalization.localized("Import…")) {
                            importSettings()
                        }
                    }
                } label: {
                    Text(appLocalized: "Backup")
                }

                // 日志
                LabeledContent {
                    Button(AppLocalization.localized("Export Logs…")) {
                        exportLogs()
                    }
                } label: {
                    Text(appLocalized: "Logs")
                }

                // 重置所有设置
                HStack {
                    Spacer()
                    Button(AppLocalization.localized("Reset All Settings…")) {
                        resetAllSettings()
                    }
                    .foregroundColor(.red)
                }
            } header: {
                Text(appLocalized: "Settings Management")
            } footer: {
                Text(appLocalized: "Resetting all settings restores the default configuration and cannot be undone")
                    .fixedSize(horizontal: false, vertical: true)
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
            Text(appLocalized: "Invalid Folder"),
            isPresented: $wrongFold
        ) {
            Button(AppLocalization.localized("OK")) {
                showDirImporter = true
            }
        } message: {
            Text(appLocalized: "The selected folder is a subfolder of an already selected folder. Please choose a different folder.")
        }
        .alert(
            Text(appLocalized: "Unauthorized Folder"),
            isPresented: $showAlert
        ) {
            Button(AppLocalization.localized("OK")) {
                showDirImporter = true
            }
        } message: {
            Text(appLocalized: "Folder access permission is required to use this feature.")
        }
        .sheet(isPresented: $showFolderPermissionsSheet) {
            FolderPermissionsSheetView(bookmarkManager: store.bookmarkManager)
        }
        .alert(
            Text(appLocalized: "Language Change Requires Restart"),
            isPresented: $showLanguageRestartAlert
        ) {
            Button(AppLocalization.localized("Restart Now")) {
                restartApplication()
            }
            Button(AppLocalization.localized("Later"), role: .cancel) {}
        } message: {
            Text(appLocalized: "Some interface elements and Finder menus will update after restarting RClick.")
        }
    }

    // MARK: - 权限状态检测

    private func updatePermissionStatus() {
        // Finder 扩展状态
        finderSyncStatus = FIFinderSyncController.isExtensionEnabled ? .enabled : .disabled

        // 辅助功能权限检测
        accessibilityStatus = PermissionChecker.hasAccessibilityPermission() ? .enabled : .disabled
    }

    private func hasAccessibilityPermission() -> Bool {
        return PermissionChecker.hasAccessibilityPermission()
    }

    // MARK: - 权限设置打开

    private func openFileProviderSettings() {
        // 打开系统设置的"文件提供程序"扩展管理界面
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.AppleFileProvider")!)
    }

    private func openAccessibilitySettings() {
        PermissionChecker.openAccessibilitySettings()
    }

    private func restartApplication() {
        let appURL = Bundle.main.bundleURL
        try? Process.run(URL(fileURLWithPath: "/usr/bin/open"), arguments: ["-n", appURL.path])
        NSApp.terminate(nil)
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
        alert.messageText = AppLocalization.localized("Reset All Settings?")
        alert.informativeText = AppLocalization.localized("This will delete all custom configurations and restore the defaults. This action cannot be undone.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppLocalization.localized("Reset"))
        alert.addButton(withTitle: AppLocalization.localized("Cancel"))
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
            return AppLocalization.localized("Authorized")
        case .disabled:
            return AppLocalization.localized("Not Authorized")
        case .unknown:
            return AppLocalization.localized("Unknown")
        }
    }
}
