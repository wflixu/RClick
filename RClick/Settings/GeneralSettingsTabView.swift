//
//  GeneralSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/10.
//

import AppKit
import Cocoa
import Combine
import FinderSync
import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsTabView: View {
    @AppLog(category: "settings-general")
    private var logger

    @AppStorage(Key.showMenuBarExtra, store: .group) private var showMenuBarExtra = true
    @EnvironmentObject var store: AppState
    @ObservedObject private var bookmarkManager = AppState.shared.bookmarkManager

    @State private var finderSyncStatus: PermissionStatus = .unknown
    @State private var accessibilityStatus: PermissionStatus = .unknown
    @State private var showFolderPermissionsSheet = false

    @State private var showDirImporter = false
    @State private var wrongFold = false
    @State private var showAlert = false

    let messager = Messager.shared

    var body: some View {
        Form {
            // MARK: - 第一组：主要控制
            Section {
                LaunchAtLogin.Toggle {
                    Text(appLocalized: "Launch at login")
                }

                Toggle(isOn: $showMenuBarExtra) {
                    Text(appLocalized: "Show icon in menu bar")
                }
            } header: {
                Text(appLocalized: "Main Controls")
            }

            // MARK: - 应用图标样式（全局，作用于「打开方式」里的应用项图标）
            Section {
                Picker(selection: $store.appIconStyle) {
                    Text(AppLocalization.localized("No Icons")).tag(RCAppIconStyle.none.rawValue)
                    Text(AppLocalization.localized("Simple Icons")).tag(RCAppIconStyle.simple.rawValue)
                    Text(AppLocalization.localized("Original Icons")).tag(RCAppIconStyle.original.rawValue)
                } label: {
                    Text(AppLocalization.localized("Icon Style"))
                }
                .pickerStyle(.segmented)
                .onChange(of: store.appIconStyle) {
                    NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                }
            } header: {
                Text(AppLocalization.localized("Icon Style"))
            } footer: {
                Text(appLocalized: "Applies to app icons in the Open With menu: none / simple (monochrome) / original")
                    .foregroundColor(.secondary)
            }

            // MARK: - 第二组：权限
            Section {
                // Finder 扩展状态
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(finderSyncStatus.description)
                            .foregroundColor(.secondary)
                        Button(AppLocalization.localized("Settings…")) {
                            openFinderExtensionSettings()
                        }
                    }
                } label: {
                    Label(AppLocalization.localized("Finder Extension"), systemImage: finderSyncStatus.icon)
                        .foregroundColor(finderSyncStatus.color)
                }

                // 辅助功能权限（行标签跟随系统设置的实际叫法：
                // macOS 26 前叫"辅助功能"，27 起叫"设备控制和数据访问"）
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(accessibilityStatus.description)
                            .foregroundColor(.secondary)
                        Button(AppLocalization.localized("Settings…")) {
                            openAccessibilitySettings()
                        }
                    }
                } label: {
                    Label(SystemSettingsNaming.accessibilitySection, systemImage: accessibilityStatus.icon)
                        .foregroundColor(accessibilityStatus.color)
                }

                // 文件夹权限（Bookmark）
                LabeledContent {
                    HStack(spacing: 8) {
                        Text("\(bookmarkManager.authorizedDirectories.count)")
                            .foregroundColor(.secondary)
                        Button(AppLocalization.localized("Manage…")) {
                            showFolderPermissionsSheet = true
                        }
                    }
                } label: {
                    Label(AppLocalization.localized("Folder Permissions"), systemImage: "folder.badge.gearshape")
                }
            } header: {
                Text(appLocalized: "Permissions")
            } footer: {
                // 条目名按系统版本取实际叫法（27+ 的「扩展」「隐私与安全」「设备控制和数据访问」，
                // 15/26 的「访达」「隐私与安全性」「辅助功能」）
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(
                        format: AppLocalization.localized(
                            "Finder extension: enable \"RClick\" under System Settings > General > Login Items & Extensions > %@."
                        ),
                        SystemSettingsNaming.finderExtensionRow
                    ))
                    Text(String(
                        format: AppLocalization.localized(
                            "\"%@\" is used for auto-renaming new files: System Settings > %@ > %@."
                        ),
                        SystemSettingsNaming.accessibilitySection,
                        SystemSettingsNaming.privacySecuritySection,
                        SystemSettingsNaming.accessibilitySection
                    ))
                }
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
        // 权限状态挂在定时器上：授权发生在系统设置里（本应用在后台），
        // macOS 的 scenePhase 对窗口级焦点切换不可靠，回到本应用时 onForeground
        // 不保证触发。两个权限检测都是廉价系统调用，2 秒轮询无性能顾虑。
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            updatePermissionStatus()
        }
        // 从系统设置切回时立即刷新（窗口重新成为 key window 的那一刻），
        // 不等下一个 2 秒轮询
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
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
            FolderPermissionsSheetView(bookmarkManager: bookmarkManager)
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

    private func openFinderExtensionSettings() {
        // macOS 13+ 的系统设置：Finder 扩展开关在"通用 → 登录项与扩展"面板里
        // （扩展区域底部）。旧锚点 com.apple.AppleFileProvider 在新版设置里无效。
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
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
