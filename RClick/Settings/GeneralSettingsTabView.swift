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

    @EnvironmentObject var store: AppState

    @State private var showAlert = false
    @State private var wrongFold = false

    @State private var showDirImporter = false

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
            case .success(let dirs):
                startAddDir(dirs.first!)

            case .failure(let error):
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
        let isEmpty =  store.dirs.isEmpty
        if isEmpty {
            showAlert = true
        } else {
            logger.info("no empty")
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
            try? store.savePermissiveDir()
//            channel.send(name: "ChoosePermissionFolder", data: nil)
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
