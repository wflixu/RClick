//
//  GeneralSettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import FinderSync
import SwiftData
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dirs: [Dir]
    
    @State private var selectedDir = Set<Dir.ID>()
    @State private var showFileImporter = false
    
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
            HStack(alignment: .top) {
                Text("启动 Finder Extension").font(.title3).fontWeight(.semibold)
                Spacer()
                Button(action: openExtensionset) {
                    Label("打开Finder 扩展设置", systemImage: enableIcon)
                }
            }
           
            Text(extensionEabled ? "扩展已经启用" : "扩展未启用")
            Text("需要启用 RClick Finder Extension 以便使其正常工作")
                .font(.headline)
                .fontWeight(.thin)
                .foregroundColor(Color.gray)
            Divider()
            HStack {
                Text("授权文件夹访问权限").font(.title3).fontWeight(.medium)
                Spacer()
                
                Button(action: removeDir) {
                    Label("删除", systemImage: "folder.badge.minus")
                }
                Button(action: addDir) {
                    Label("添加授权文件夹", systemImage: "folder.fill.badge.plus")
                }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.directory],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let files):
                        files.forEach { file in
                            // gain access to the directory
                            let gotAccess = file.startAccessingSecurityScopedResource()
                            if !gotAccess { return }
                            // access the directory URL
                            // (read templates in the directory, make a bookmark, etc.)
                            handlePickedPDF(file)
                            // release access
                            file.stopAccessingSecurityScopedResource()
                        }
                    case .failure(let error):
                        // handle error
                        print(error)
                    }
                }
            }
            
            HStack {
                Table(dirs, selection: $selectedDir) {
                    TableColumn("path", value: \.path)
                }
            }
            .padding(.horizontal)
            Text("\(selectedDir.count) people selected")
            
            Spacer()
            Section {
                HStack {
                    Button {
                        channel.send(name: "ChoosePermissionFolder", data: nil)
                    } label: { Label("Add Folders", systemImage: "folder.badge.plus") }
                    Button {
                        store.deleteAllBookmarkItems()
                    } label: { Label("Remove All", systemImage: "folder.badge.minus") }
                }
                List {
                    ForEach(store.bookmarkItems) { item in
                        HStack {
                            Image(systemName: "folder")
                            Text(item.path)
                        }
                    }
                    .onDelete { store.deleteBookmarkItems(offsets: $0) }
                }
            } header: {
                Text("User Seleted Directories")
            } footer: {
                VStack {
                    HStack {
                        (
                            Text("Directories where you have permission for *application menu items* to open apps and *new file action menu* to create file")
                                + Text(verbatim: "\n")
                                + Text("Recommended folder is \("/Users/\(NSUserName())") (current user's 🏠 directory)")
                        )
                        .foregroundColor(.secondary)
                        .font(.caption)
                        Spacer()
                    }
                }
            }
        }
//        .background(.blue)
        .frame(minWidth: 600, minHeight: 450)
        .onAppear {
            Task {
                await channel.setup(store: store)
            }
        }
    }
    
    private func addDir() {
        showFileImporter = true
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
    GeneralSettingsView(store: FolderItemStore())
}
