//
//  GeneralSettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import FinderSync
import os.log
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: subsystem, category: "main")

struct FolderSettingsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dirs: [Dir]
    
    @State private var selectedDir = Set<Dir.ID>()
    @State private var showFileImporter = false
    
    @State private var showActionFileImporter = false
    
    var store: FolderItemStore

    var extensionEabled: Bool {
        return FinderSync.FIFinderSyncController.isExtensionEnabled
    }
    
    var enableIcon: String {
        if FinderSync.FIFinderSyncController.isExtensionEnabled {
            return "checkmark.circle.fill"
        } else {
            return "checkmark.circle"
        }
    }

    var body: some View {
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
                    Text("用户选择文件夹").font(.title2)
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
                        
                    Button {
                        store.deleteAllBookmarkItems()
                    } label: { Label("删除", systemImage: "folder.badge.minus") }
                }
                
            } footer: {
                VStack {
                    HStack {
                        Text(" App 可以打开的文件夹")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Spacer()
                    }
                }
            }
            
            Spacer()
            
            Section {
                List {
                    ForEach(store.syncItems) { item in
                        HStack {
                            Image(systemName: "folder")
                            Text(item.path)
                            Spacer()
                            Button {
                                removeActionFolder(item)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("同步文件夹").font(.title2)
                    Spacer()
                    Button {
                        showActionFileImporter = true
                    } label: { Label("添加", systemImage: "folder.badge.plus") }
                        .fileImporter(
                            isPresented: $showActionFileImporter,
                            allowedContentTypes: [.directory],
                            allowsMultipleSelection: false
                        ) { result in
                            switch result {
                            case .success(let files):
                                    
                                for file in files {
                                    // gain access to the directory
                                    store.appendItem(SyncFolderItem(file))
                                }
                            case .failure(let error):
                                // handle error
                                print(error)
                            }
                        }
                        
                    Button {
                        store.deleteAllBookmarkItems()
                    } label: { Label("删除", systemImage: "folder.badge.minus") }
                }.padding(.top)
                
            } footer: {
                VStack {
                    HStack {
                        Text("同步文件夹有右键菜单")

                            .foregroundColor(.secondary)
                            .font(.caption)
                        Spacer()
                    }
                }
            }
        }
        
    }
    
    private func addDir() {
        showFileImporter = true
    }
    
    @MainActor private func removeBookmark(_ item: BookmarkFolderItem) {
        // 根据item 查找offsets
        if let index = store.bookmarkItems.firstIndex(of: item) {
            store.deleteBookmarkItem(index: index)
        }
    }
    
    @MainActor private func removeActionFolder(_ item: SyncFolderItem) {
        if let index = store.syncItems.firstIndex(of: item) {
            store.deleteSyncItem(index: index)
        }
    }
    
    private func removeDir() {
        while let id = selectedDir.popFirst() {
            if let dir = dirs.first(where: { item in item.id == id }) {
                modelContext.delete(dir)
            }
        }
    }
    
    private func handlePickedPDF(_ file: URL) {
        print(file.path())
        let dir = Dir(path: file.path())
        modelContext.insert(dir)
    }
    
    private func openExtensionset() {
        FinderSync.FIFinderSyncController.showExtensionManagementInterface()
    }
}

#Preview {
    FolderSettingsTabView(store: FolderItemStore())
}
