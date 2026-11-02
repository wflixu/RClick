//
//  AppsSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/11/18.
//

import AppKit
import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct AppsSettingsTabView: View {
    @EnvironmentObject var appState: AppState
    @State var showSelectApp = false
    @State var showPresetSheet = false
    @State private var editingApp: OpenWithApp?

    let messager = Messager.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $appState.foldAppsMenu) {
                    Text(appLocalized: "Collapse apps menu")
                }
                    .onChange(of: appState.foldAppsMenu) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
            }

            Section {
                HStack {
                    Button {
                        showPresetSheet = true
                    } label: {
                        Label(AppLocalization.localized("Add Preset App"), systemImage: "wand.and.stars")
                    }
                    Spacer()
                    Button {
                        showSelectApp = true
                    } label: {
                        Label(AppLocalization.localized("Add App"), systemImage: "plus.app")
                    }
                }

                List {
                    ForEach(appState.apps) { item in
                        LabeledContent {
                            HStack(spacing: 10) {
                                Toggle(AppLocalization.localized("Toolbar"), isOn: visibilityBinding(item, \.showInToolbar))
                                    .toggleStyle(.checkbox)
                                    .controlSize(.small)
                                    .fixedSize()
                                Toggle(AppLocalization.localized("Context Menu"), isOn: visibilityBinding(item, \.showInContextMenu))
                                    .toggleStyle(.checkbox)
                                    .controlSize(.small)
                                    .fixedSize()

                                Button {
                                    editingApp = item
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .help(AppLocalization.localized("Edit App"))

                                Button {
                                    deleteApp(item)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help(AppLocalization.localized("Delete App"))
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.secondary)
                                Image(nsImage: IconCache.shared.icon(for: item.url))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    if !item.arguments.isEmpty || !item.environment.isEmpty {
                                        Text(appSummary(item))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                }
                            }
                        }
                    }
                    .onMove { source, destination in
                        appState.moveApps(from: source, to: destination)
                        messager.sendRunningNotification()
                    }
                }
                .frame(minHeight: 180)
            } header: {
                Text(AppLocalization.localized("Show In"))
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showSelectApp,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let url = files.first {
                    appState.addApp(item: OpenWithApp(appURL: url))
                }
            case .failure(let error):
                print(error)
            }
        }
        .sheet(item: $editingApp) { app in
            EditAppSheetView(app: app, appState: appState)
        }
        .sheet(isPresented: $showPresetSheet) {
            PresetAppsSheetView(appState: appState)
        }
    }

    /// 行内可见性开关的双向绑定：写入 AppState（persist 会自动广播菜单更新）
    private func visibilityBinding(_ item: OpenWithApp, _ keyPath: WritableKeyPath<OpenWithApp, Bool>) -> Binding<Bool> {
        Binding<Bool>(
            get: { item[keyPath: keyPath] },
            set: { newValue in
                let toolbar = keyPath == \.showInToolbar ? newValue : item.showInToolbar
                let context = keyPath == \.showInContextMenu ? newValue : item.showInContextMenu
                appState.updateAppVisibility(id: item.id, showInToolbar: toolbar, showInContextMenu: context)
            }
        )
    }

    private func appSummary(_ item: OpenWithApp) -> String {
        var parts: [String] = []
        if !item.arguments.isEmpty {
            parts.append(String(format: AppLocalization.localized("Arguments: %@"), item.arguments.joined(separator: "; ")))
        }
        if !item.environment.isEmpty {
            parts.append(String(format: AppLocalization.localized("Environment variables: %lld"), Int64(item.environment.count)))
        }
        return parts.joined(separator: " · ")
    }
    
    @MainActor private func deleteApp(_ appItem: OpenWithApp) {
        if let index = appState.apps.firstIndex(where: { $0.id == appItem.id }) {
            appState.deleteApp(index: index)
        }
        messager.sendRunningNotification()
    }
}

/// 预设应用快速添加：列出常用终端/编辑器/Git 客户端，标记安装状态，一键添加
struct PresetAppsSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            List {
                // 排序：已安装未添加 > 已添加 > 未安装；组内保持预设清单原顺序
                ForEach(sortedPresets, id: \.preset.bundleID) { entry in
                    presetRow(entry.preset, installedURL: entry.installedURL, alreadyAdded: entry.added)
                }
            }
            .listStyle(.inset)
            Divider()
            HStack {
                Spacer()
                Button(AppLocalization.localized("Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 420, height: 480)
    }

    /// 预设行数据：预装状态 + 是否已添加（随 appState.apps 变化重新计算）
    private struct PresetEntry {
        let preset: AppPreset
        let installedURL: URL?
        let added: Bool
    }

    private var sortedPresets: [PresetEntry] {
        let entries = AppPresets.all.map { preset -> PresetEntry in
            let installedURL = AppPresets.installedURL(for: preset)
            let added = installedURL.map { url in
                appState.apps.contains { $0.url.path == url.path }
            } ?? false
            return PresetEntry(preset: preset, installedURL: installedURL, added: added)
        }
        // 0=可添加（已安装未添加） 1=已添加 2=未安装；稳定排序保持组内原顺序
        return entries.enumerated().sorted { a, b in
            let pa = Self.priority(a.element)
            let pb = Self.priority(b.element)
            return pa != pb ? pa < pb : a.offset < b.offset
        }.map(\.element)
    }

    private static func priority(_ entry: PresetEntry) -> Int {
        switch (entry.installedURL, entry.added) {
        case (.some, false): return 0
        case (.some, true): return 1
        case (.none, _): return 2
        }
    }

    @ViewBuilder
    private func presetRow(_ preset: AppPreset, installedURL: URL?, alreadyAdded: Bool) -> some View {
        HStack(spacing: 10) {
            Group {
                if let url = installedURL {
                    Image(nsImage: IconCache.shared.icon(for: url))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: preset.symbol)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppLocalization.localized(preset.nameKey))
                Text(AppLocalization.localized(installedURL != nil ? "Installed" : "Not Installed"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let url = installedURL {
                if alreadyAdded {
                    Text(AppLocalization.localized("Added"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    Button(AppLocalization.localized("Add")) {
                        appState.addApp(item: OpenWithApp(appURL: url))
                    }
                    .controlSize(.small)
                }
            } else {
                Text(AppLocalization.localized("Not Installed"))
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}
