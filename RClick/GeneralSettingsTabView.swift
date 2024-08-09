//
//  GeneralSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/10.
//

import AppKit
import Cocoa
import FinderSync
import SwiftUI

struct GeneralSettingsTabView: View {
    @AppLog(category: "settings-general")
    private var logger

    @AppStorage("extensionEnabled") private var extensionEnabled = false

    var store: FolderItemStore

    @State private var showFileImporter = false

    @Environment(\.scenePhase) private var scenePhase

    var enableIcon: String {
        if extensionEnabled {
            return "checkmark.circle.fill"
        } else {
            return "checkmark.circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom) {
                Text("启动扩展").font(.title3).fontWeight(.semibold)
                Spacer()
                Button(action: openExtensionset) {
                    Label("打开扩展设置", systemImage: enableIcon)
                }
            }

            HStack {
                Text(extensionEnabled ? "扩展已经启用" : "扩展未启用")
            }
            Text("需要启用 RClick 扩展以便使其正常工作")
                .font(.headline)
                .fontWeight(.thin)
                .foregroundColor(Color.gray)
            Divider()

            HStack {}.frame(height: 10)

            VStack(alignment: .leading) {
                Section {
                    List {
                        ForEach(store.bookmarkItems) { item in
                            HStack {
                                Image(systemName: "folder")
                                Text(item.path)
                                Spacer()
                                Button {
                                    removeBookmark(item)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("授权文件夹").font(.title3).fontWeight(.semibold)
                        Spacer()
                        Button {
                            showFileImporter = true
                        } label: { Label("添加", systemImage: "folder.badge.plus") }
                            .fileImporter(
                                isPresented: $showFileImporter,
                                allowedContentTypes: [.directory],
                                allowsMultipleSelection: false
                            ) { result in
                                switch result {
                                case .success(let files):

                                    for file in files {
                                        // gain access to the directory
                                        store.appendItem(BookmarkFolderItem(file))
                                    }
                                    channel.send(name: "ChoosePermissionFolder", data: nil)
                                case .failure(let error):
                                    // handle error
                                    print(error)
                                }
                            }
                    }

                } footer: {
                    VStack {
                        HStack {
                            Text("授权的文件夹，才能执行菜单的操作")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
            }
        }

        .onAppear {
            extensionEnabled = FIFinderSyncController.isExtensionEnabled
        }.onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification), perform: { _ in
            updateEnableState()
        })
    }

    func updateEnableState() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    @MainActor private func removeBookmark(_ item: BookmarkFolderItem) {
        // 根据item 查找offsets
        if let index = store.bookmarkItems.firstIndex(of: item) {
            store.deleteBookmarkItem(index: index)
        }
    }

    private func openExtensionset() {
        FinderSync.FIFinderSyncController.showExtensionManagementInterface()
    }
}
