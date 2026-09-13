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
    @State private var menuConfigError: String?
    @State private var menuConfigErrorTitle = "Unable to Open Menu Config"
    @State private var showMenuConfigError = false
    @State private var customMenuStatus = CustomMenuStatus(applied: .defaultLayout, notice: .none)

    @State private var showDirImporter = false
    @State private var wrongFold = false
    @State private var showAlert = false

    let messager = Messager.shared

    var body: some View {
        Form {
            // MARK: - 第一组：主要控制
            Section {
                Toggle(isOn: $showMenuBarExtra) {
                    Text(appLocalized: "Show icon in menu bar")
                }

                LaunchAtLogin.Toggle {
                    Text(appLocalized: "Launch at login")
                }
            } header: {
                Text(appLocalized: "Main Controls")
            }

            // MARK: - 第二组：权限
            Section {
                // Finder 扩展状态
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(finderSyncStatus.description)
                            .foregroundColor(.secondary)
                        Button(AppLocalization.localized("Settings…")) {
                            openFileProviderSettings()
                        }
                    }
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
                        Text("\(bookmarkManager.authorizedDirectories.count)")
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

            Section {
                LabeledContent {
                    Text(customMenuStatusDetail)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label(customMenuStatusTitle, systemImage: customMenuStatusIcon)
                        .foregroundStyle(customMenuStatusColor)
                }

                switch customMenuStatus.notice {
                case .none:
                    EmptyView()
                case .edited:
                    Text(appLocalized: "Changed since it was applied, so the menu still shows the previous layout.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .broken(let reason):
                    Label {
                        Text(reason)
                            .textSelection(.enabled)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button(AppLocalization.localized("Edit Menu Config…")) {
                        revealMenuConfig()
                    }
                    .help(AppLocalization.localized("Locates custom_menu.json in Finder so you can open it with the editor you prefer. Creates it first if it does not exist yet."))

                    Button(AppLocalization.localized("Apply Custom Menu")) {
                        applyCustomMenu()
                    }
                    .disabled(!customMenuHasPendingChanges)
                    .help(AppLocalization.localized("Reads the file again and puts it into effect. If it has errors the menu is left as it was."))

                    Spacer()

                    Button(AppLocalization.localized("Restore Default Layout")) {
                        restoreDefaultLayout()
                    }
                    .disabled(!customMenuFileExists)
                    .help(AppLocalization.localized("Deletes the file and returns to the default layout, keeping a backup."))
                }
            } header: {
                Text(appLocalized: "Custom Menu")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if customMenuStatus.applied == .defaultLayout {
                        Text(appLocalized: "Customize top-level items and nested submenus with custom_menu.json. 💡 Tip: Give this file to an AI assistant (such as ChatGPT / Claude) to help arrange your menu.")
                    }
                    Text(appLocalized: "Editing the file changes nothing until you apply it.")
                }
                .foregroundStyle(.secondary)
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
            refreshCustomMenuStatus()
        }
        .onForeground {
            updatePermissionStatus()
            refreshCustomMenuStatus()
        }
        // Keeps the Apply button's enabled state honest. App activation covers the
        // normal "edit elsewhere, switch back" path; this covers a writer that never
        // takes activation away - a script, a sync tool, another process. Without
        // it a stale status would leave the button disabled and unclickable.
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            refreshCustomMenuStatus()
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
        .alert(menuConfigErrorTitle, isPresented: $showMenuConfigError) {
            Button(AppLocalization.localized("OK"), role: .cancel) {}
        } message: {
            Text(menuConfigError ?? "")
        }
        .sheet(isPresented: $showFolderPermissionsSheet) {
            FolderPermissionsSheetView(bookmarkManager: bookmarkManager)
        }
    }

    /// Locates the file in Finder so the user can open it with an editor they chose.
    ///
    /// Deliberately does not open it: the system default editor is whatever happens
    /// to be installed, which is not a choice the user made. A missing file is
    /// seeded first so there is something to reveal - and that no longer changes
    /// the menu, which now waits for Apply.
    private func revealMenuConfig() {
        guard let url = RCRuntime.shared.menuService.customMenuURL else {
            presentConfigError(
                title: "Unable to Open Menu Config",
                message: AppLocalization.localized("The shared configuration folder is unavailable.")
            )
            return
        }
        do {
            try MenuService.prepareCustomMenu(at: url, config: MenuService.makePayload(from: store))
        } catch {
            presentConfigError(title: "Unable to Open Menu Config", message: CustomMenuDiagnostics.message(for: error))
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        refreshCustomMenuStatus()
    }

    // MARK: - 自定义菜单

    private var customMenuFileExists: Bool {
        guard let url = RCRuntime.shared.menuService.customMenuURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Whether the file differs from what is in effect. Also what makes the button
    /// going grey a form of confirmation that applying worked.
    private var customMenuHasPendingChanges: Bool {
        switch customMenuStatus.notice {
        case .edited, .broken: true
        case .none: false
        }
    }

    private var customMenuIsBroken: Bool {
        if case .broken = customMenuStatus.notice { return true }
        return false
    }

    private var customMenuStatusTitle: String {
        switch customMenuStatus.applied {
        case .unavailable:
            AppLocalization.localized("Unavailable")
        case .defaultLayout:
            customMenuIsBroken
                ? AppLocalization.localized("Configuration invalid")
                : AppLocalization.localized("Not enabled")
        case .empty, .custom:
            AppLocalization.localized("Enabled")
        }
    }

    private var customMenuStatusDetail: String {
        switch customMenuStatus.applied {
        case .unavailable: ""
        case .defaultLayout: AppLocalization.localized("Using the default layout")
        case .empty: AppLocalization.localized("Empty menu")
        case .custom(let count): String(format: AppLocalization.localized("%lld items"), count)
        }
    }

    private var customMenuStatusIcon: String {
        switch customMenuStatus.applied {
        case .unavailable: "exclamationmark.triangle.fill"
        case .defaultLayout: customMenuIsBroken ? "exclamationmark.triangle.fill" : "circle.dashed"
        case .empty, .custom: "checkmark.circle.fill"
        }
    }

    private var customMenuStatusColor: Color {
        switch customMenuStatus.applied {
        case .unavailable: .orange
        case .defaultLayout: customMenuIsBroken ? .orange : .secondary
        case .empty, .custom: .green
        }
    }

    /// Guarded by an equality check so the polling timer does not dirty the view on
    /// every tick.
    private func refreshCustomMenuStatus() {
        let fresh = RCRuntime.shared.menuService.customMenuStatus(from: store)
        if fresh != customMenuStatus {
            customMenuStatus = fresh
        }
    }

    private func presentConfigError(title: String, message: String) {
        menuConfigErrorTitle = AppLocalization.localized(title)
        menuConfigError = message
        showMenuConfigError = true
    }

    /// Re-reads the file and only then commits it.
    ///
    /// Nothing is pushed unless the file validated, so a bad edit leaves the live
    /// menu exactly as it was instead of taking it down behind the user's back.
    private func applyCustomMenu() {
        do {
            try RCRuntime.shared.menuService.applyCustomMenu(from: store)
            NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
        } catch {
            presentConfigError(
                title: "Configuration Not Applied",
                message: CustomMenuDiagnostics.message(for: error)
                    + "\n\n" + AppLocalization.localized("The menu is unchanged.")
            )
        }
        refreshCustomMenuStatus()
    }

    private func restoreDefaultLayout() {
        guard let url = RCRuntime.shared.menuService.customMenuURL else {
            presentConfigError(
                title: "Unable to Restore Default Layout",
                message: AppLocalization.localized("The shared configuration folder is unavailable.")
            )
            return
        }

        let alert = NSAlert()
        alert.messageText = AppLocalization.localized("Restore the default layout?")
        alert.informativeText = AppLocalization.localized("This deletes custom_menu.json and returns to the default menu. A copy is kept as custom_menu.backup.json.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppLocalization.localized("Restore"))
        alert.addButton(withTitle: AppLocalization.localized("Cancel"))
        alert.buttons[0].hasDestructiveAction = true

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try MenuService.removeCustomMenu(at: url)
            // Forgetting the snapshot matters: without it, recreating the file with
            // the same bytes (restoring the backup, say) would silently bring the
            // custom layout back without an Apply.
            RCRuntime.shared.menuService.discardAppliedCustomMenu()
            NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
        } catch {
            presentConfigError(title: "Unable to Restore Default Layout", message: CustomMenuDiagnostics.message(for: error))
        }
        refreshCustomMenuStatus()
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
