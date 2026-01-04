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
    @AppStorage(Key.showMenuBarExtra) private var showMenuBarExtra = true
    @AppStorage(Key.showInDock) private var showInDock = false

    @EnvironmentObject var store: AppState

    @State private var showAlert = false
    @State private var wrongFold = false

    @State private var showDirImporter = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    let messager = Messager.shared

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
                Text("Enable extension").font(.title3).fontWeight(.semibold)
                Spacer()
                Button(action: openExtensionset) {
                    Label("Open Settings", systemImage: enableIcon)
                }
            }

            Text("The RClick extension needs to be enabled for it to work properly")
                .font(.headline)
                .fontWeight(.thin)
                .foregroundColor(Color.gray)
            Divider()

            HStack {
                LaunchAtLogin.Toggle(
                    LocalizedStringKey("Launch at login")
                )
            }
            Divider()
            Text("App Icon Show").font(.title2)

            HStack {
                Toggle("Show in menu bar", isOn: $showMenuBarExtra)
                    .toggleStyle(.checkbox)
                Spacer()
                // 设置 showMenuBarExtra 的开关
                Toggle("Show in dock", isOn: $showInDock)
                    .toggleStyle(.checkbox)
                    .onChange(of: showInDock) { _, newValue in
                        logger.debug("the hcnage --- a kjd \(newValue)")
                        // 在这里处理开关状态的变化
                        if newValue {
                            // 显示菜单栏图标
                            NSApp.setActivationPolicy(.regular)
                        } else {
                            // 隐藏菜单栏图标
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
            }
            // 设置 showMenuBarExtra 的开关

            Divider()
            HStack {}.frame(height: 10)

            VStack(alignment: .leading) {
                Section {
                    List {
                        ForEach(store.dirs) { item in
                            HStack {
                                Image(systemName: "folder")
                                Text(verbatim: item.url.path)
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
                        Text("Authorization folder").font(.title3).fontWeight(.semibold)
                        Spacer()
                        Button {
                            showDirImporter = true
                        } label: { Label("Add", systemImage: "folder.badge.plus") }
                    }

                } footer: {
                    VStack {
                        HStack {
                            Text("The operation of the menu can only be executed in authorized folders")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
            }
            .alert(
                Text("Invalid Folder Selection"),
                isPresented: $wrongFold
            ) {
                Button("OK") {
                    showDirImporter = true
                }
            } message: {
                Text("The selected folder is a subdirectory of the previously chosen folder. Please select a different folder.")
            }
        }
        .alert(
            Text("Not Authorized Folder"),
            isPresented: $showAlert
        ) {
            Button("OK") {
                showDirImporter = true
            }
        } message: {
            Text("You must grant access to the folder to use this feature.")
        }
        .fileImporter(
            isPresented: $showDirImporter,
            allowedContentTypes: [.directory],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(dirs):
                startAddDir(dirs.first!)

            case let .failure(error):
                // handle error
                print(error)
            }
        }

        .onAppear {
            extensionEnabled = FIFinderSyncController.isExtensionEnabled

        }.onForeground {
            updateEnableState()
//            Task {
//                await checkPermissionFolder()
//            }
        }
        .task {
//            await checkPermissionFolder()
        }
    }

    func updateEnableState() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    func checkPermissionFolder() async {
        let isEmpty = store.dirs.isEmpty
        if isEmpty {
            showAlert = true
        } else {
            logger.info("no empty")
        }
    }

    private func insertNewPermDir(url: URL) {
        // 2. 创建唯一的ID
        let newId = UUID().uuidString

        // 3. 创建Bookmark Data (这里你需要根据实际情况提供)
        // 例如，你可以尝试从URL创建bookmark data，或者根据你的应用逻辑提供相应的数据。
        // 如果暂时没有实际数据，可以使用空Data()，但不建议长期这样。
        let bookmarkData: Data
        do {
            bookmarkData = try url.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            print("Failed to create bookmark data: \(error)")
            // 根据你的需求决定错误处理方式，这里使用空Data
            bookmarkData = Data()
        }

        // 4. 创建新的PermDir实例
        let newPermDir = PermDir(id: newId, url: url, bookmark: bookmarkData)

        // 5. 插入到模型上下文:cite[1]
        modelContext.insert(newPermDir)

        // 6. 保存上下文（SwiftData有时会自动保存，但显式保存是个好习惯，尤其是在重要操作后）
        do {
            try modelContext.save()
            print("PermDir inserted successfully.")
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    @MainActor
    func startAddDir(_ url: URL) {
        let hasParentDir = store.hasParentBookmark(of: url)
        if hasParentDir {
            wrongFold = true
//            showAlert = true
            logger.info("hasParentDir\(hasParentDir)")
        } else {
            store.dirs.append(PermissiveDir(permUrl: url))
            // 声明一个PermDir 实体，并插入到 modelContext 中
            insertNewPermDir(url: url)
            try? store.savePermissiveDir()

            let observeDirs = store.dirs.map { $0.url.path }
            messager.sendMessage(name: "running", data: MessagePayload(action: "running", target: observeDirs))
        }
    }

    @MainActor private func removeBookmark(_ item: PermissiveDir) {
        // 根据item 查找offsets
        if let index = store.dirs.firstIndex(of: item) {
            store.deletePermissiveDir(index: index)
        }
    }

    private func openExtensionset() {
        FinderSync.FIFinderSyncController.showExtensionManagementInterface()
    }
}
