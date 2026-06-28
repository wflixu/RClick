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
                Toggle("折叠新建文件菜单", isOn: $appState.foldNewFileMenu)
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
                        Label("恢复默认", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Spacer()
                    Button {
                        editingFile = NewFile(ext: "", name: "", idx: appState.newFiles.count)
                    } label: {
                        Label("添加文件类型", systemImage: "plus")
                    }
                }

                ForEach($appState.newFiles) { $item in
                    LabeledContent {
                        HStack(spacing: 12) {
                            Button {
                                editingFile = item
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .help("编辑文件类型")

                            Toggle("启用", isOn: $item.enabled)
                                .toggleStyle(.switch)
                                .onChange(of: item.enabled) {
                                    appState.toggleActionItem()
                                    messager.sendRunningNotification()
                                }
                                .labelsHidden()
                        }
                    } label: {
                        HStack(spacing: 8) {
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
                                Text("扩展名: \(item.ext)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editingFile) { file in
            EditFileTypeSheetView(file: file, appState: appState)
        }
    }

}
