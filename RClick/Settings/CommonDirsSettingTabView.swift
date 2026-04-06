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
        VStack(alignment: .leading, spacing: 8) {
            Section {
                List {
                    ForEach(store.cdirs) { item in
                        HStack {
                            Image(systemName: "folder")
                            Text(verbatim: item.url.path)
                            Spacer()
                            Button {
                                removeCommonDir(item)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Toggle("折叠常用文件夹菜单", isOn: $store.foldCommonDirMenu)
                        .toggleStyle(.switch)
                    Spacer()
                    Button {
                        showCommonDirImporter = true
                    } label: { Label("Add", systemImage: "folder.badge.plus") }
                }
            } footer: {
                Text("Quick access to frequently used folders")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .fileImporter(
                isPresented: $showCommonDirImporter,
                allowedContentTypes: [.directory],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            let commonDir = CommonDir(id: UUID().uuidString, name: url.lastPathComponent, url: url, icon: "folder")
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
    }

    @MainActor private func removeCommonDir(_ item: CommonDir) {
        if let index = store.cdirs.firstIndex(of: item) {
            store.cdirs.remove(at: index)
            store.sync()
        }
    }
}
