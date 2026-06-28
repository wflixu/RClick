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
    @State private var editingApp: OpenWithApp?

    let messager = Messager.shared

    var body: some View {
        Form {
            Section {
                Toggle("折叠应用菜单", isOn: $appState.foldAppsMenu)
                    .onChange(of: appState.foldAppsMenu) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
            }

            Section {
                HStack {
                    Spacer()
                    Button {
                        showSelectApp = true
                    } label: {
                        Label("添加应用", systemImage: "plus.app")
                    }
                }

                ForEach(appState.apps) { item in
                    LabeledContent {
                        HStack(spacing: 8) {
                            Button {
                                editingApp = item
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .help("编辑应用")

                            Button {
                                deleteApp(item)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("删除应用")
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(nsImage: IconCache.shared.icon(for: item.url))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                if !item.arguments.isEmpty || !item.environment.isEmpty {
                                    Text(appSummary(item))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
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
    }

    private func appSummary(_ item: OpenWithApp) -> String {
        var parts: [String] = []
        if !item.arguments.isEmpty {
            parts.append("参数: \(item.arguments.joined(separator: "; "))")
        }
        if !item.environment.isEmpty {
            parts.append("环境变量: \(item.environment.count)个")
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
