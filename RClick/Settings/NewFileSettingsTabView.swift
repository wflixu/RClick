//
//  NewFileSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/11/18.
//

import AppKit
import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct NewFileSettingsTabView: View {
    @AppLog(category: "NewFileSettingsTabView")
    private var logger
    
    @EnvironmentObject var appState: AppState
    @State private var editingFile: NewFile?

    let messager = Messager.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $appState.foldNewFileMenu) {
                    Text(appLocalized: "Collapse new file menu")
                }
                    .onChange(of: appState.foldNewFileMenu) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
            }

            Section {
                // 操作按钮放在列表顶部，始终可见
                HStack {
                    Button {
                        appState.resetFiletypeItems()
                    } label: {
                        Label(AppLocalization.localized("Restore Defaults"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    Spacer()
                    Button {
                        editingFile = NewFile(ext: "", name: "", idx: appState.newFiles.count)
                    } label: {
                        Label(AppLocalization.localized("Add File Type"), systemImage: "plus")
                    }
                }

                List {
                    ForEach($appState.newFiles) { $item in
                        LabeledContent {
                            HStack(spacing: 12) {
                                Button {
                                    editingFile = item
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .help(AppLocalization.localized("Edit File Type"))

                                Toggle(AppLocalization.localized("Enabled"), isOn: $item.enabled)
                                    .toggleStyle(.switch)
                                    .onChange(of: item.enabled) {
                                        appState.toggleActionItem()
                                        messager.sendRunningNotification()
                                    }
                                    .labelsHidden()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.secondary)
                                // 图标
                                if let appUrl = item.openApp {
                                    Image(nsImage: IconCache.shared.icon(for: appUrl))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                } else if let sysIcon = FileTypeIconProvider.shared.icon(for: item.ext, fallbackSymbol: item.icon) {
                                    Image(nsImage: sysIcon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                    Text(String(format: AppLocalization.localized("Extension: %@"), item.ext))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onMove { source, destination in
                        appState.moveNewFiles(from: source, to: destination)
                        messager.sendRunningNotification()
                    }
                }
                .frame(minHeight: 180)
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editingFile) { file in
            EditFileTypeSheetView(file: file, appState: appState)
        }
    }

}
