//
//  CommonDirsSettingTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/10.
//

import AppKit
import Cocoa
import FinderSync
import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct CommonDirsSettingTabView: View {
    @AppLog(category: "settings-general")
    private var logger
    
    @EnvironmentObject var store: AppState
    
    @State private var showCommonDirImporter = false
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $store.showCommonDirs) {
                    Text(appLocalized: "Show Open Folder menu")
                }
                    .onChange(of: store.showCommonDirs) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
                Toggle(isOn: $store.foldCommonDirMenu) {
                    Text(appLocalized: "Collapse Open Folder menu")
                }
                    .disabled(!store.showCommonDirs)
                    .onChange(of: store.foldCommonDirMenu) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
            } header: {
                Text(appLocalized: "Open Folder Menu")
            } footer: {
                Text(appLocalized: "Shows saved folders as shortcuts that open those folders from the Finder context menu.")
            }

            Section {
                Toggle(isOn: $store.showCopyToCommonDirs) {
                    Text(appLocalized: "Show Copy To menu")
                }
                    .onChange(of: store.showCopyToCommonDirs) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
                Toggle(isOn: $store.showMoveToCommonDirs) {
                    Text(appLocalized: "Show Move To menu")
                }
                    .onChange(of: store.showMoveToCommonDirs) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
            } header: {
                Text(appLocalized: "Copy and Move Menus")
            } footer: {
                Text(appLocalized: "These menus use the saved folders below as destinations and only appear when Finder items are selected.")
            }

            Section {
                HStack {
                    Spacer()
                    Button {
                        showCommonDirImporter = true
                    } label: {
                        Label(AppLocalization.localized("Add Folder"), systemImage: "folder.badge.plus")
                    }
                }

                ForEach(store.cdirs) { item in
                    LabeledContent {
                        Button {
                            removeCommonDir(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    } label: {
                        Label(item.displayName, systemImage: item.icon.isEmpty ? "folder" : item.icon)
                    }
                }
            } header: {
                Text(appLocalized: "Added Folders")
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showCommonDirImporter,
            allowedContentTypes: [.directory],
            allowsMultipleSelection: false
        ) { result in
            switch result {
                case .success(let urls):
                    if let url = urls.first {
                        let commonDir = CommonDir(id: UUID().uuidString, name: url.lastPathComponent, url: url, icon: iconForDirectory(url: url))
                        if !store.cdirs.contains(where: { $0.url == commonDir.url }) {
                            store.cdirs.append(commonDir)
                            store.sync()
                        }
                    }
                case .failure(let error):
                    logger.error("Failed to select common folder: \(error.localizedDescription)")
            }
        }
    }

    @MainActor private func removeCommonDir(_ item: CommonDir) {
        if let index = store.cdirs.firstIndex(of: item) {
            store.cdirs.remove(at: index)
            store.sync()
        }
    }
}
