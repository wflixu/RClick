//
//  ActionSettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/9.
//

import AppKit

import SwiftUI


struct ActionSettingsTabView: View {
    @Bindable var store: MenuItemStore
    
    @State var menumItemStore = MenuItemStore()
    @State var showSelectApp = false

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(store.appItems) { item in
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                            Text(item.appName).font(.title2)
                            Spacer()
                            Button {
                                deleteApp(item)
                            } label: {
                                Image(systemName: "delete.backward")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("菜单应用").font(.title2)
                    Spacer()
                    Button {
                        showSelectApp = true
                    } label: {
                        Label("添加", systemImage: "plus.app")
                            .font(.body)
                    }
                    .fileImporter(
                        isPresented: $showSelectApp,
                        allowedContentTypes: [.application],
                        allowsMultipleSelection: false

                    ) { result in
                        switch result {
                        case .success(let files):
                            let items = files.map { AppMenuItem(appURL: $0) }
                            store.appendItems(items)
                            channel.send(name: "RefreshMenuItems")
                        case .failure(let error):
                            // handle error
                            print(error)
                        }
                    }
                }
            }

            // Mark

            Section {
                List {
                    ForEach($store.actionItems) { $item in
                        HStack {
                            Image(systemName: item.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            Text(item.name).font(.title2)
                            Spacer()
                            Toggle("", isOn: $item.enabled)
                                .onChange(of: item.enabled) {
                                    store.toggleActionItem()
                                    channel.send(name: "RefreshMenuItems")
                                }
                                .toggleStyle(.switch)
                        }
                    }
                }

            } header: {
                HStack {
                    Text("操作项").font(.title2)
                    Spacer()
                    Button {
                        store.resetActionItems()
                    } label: {
                        Label("重置", systemImage: "arrow.triangle.2.circlepath")
                            .font(.body)
                    }
                }
            }
            
            // Mark
            Section {
                List {
                    ForEach($store.filetypeItems) { $item in
                        HStack {
                            Image(item.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            Text(item.name).font(.title2)
                            Spacer()
                            Toggle("", isOn: $item.enabled)
                                .onChange(of: item.enabled) {
                                    store.toggleActionItem()
                                    channel.send(name: "RefreshMenuItems")
                                }
                                .toggleStyle(.switch)
                        }
                    }
                }

            } header: {
                HStack {
                    Text("新建文件").font(.title2)
                    Spacer()
                    Button {
                        store.resetFiletypeItems()
                    } label: {
                        Label("重置", systemImage: "arrow.triangle.2.circlepath")
                            .font(.body)
                    }
                }
            } footer: {
                Link("想添加功能, 这里反馈", destination: URL(string: "https://github.com/wflixu/RClick/issues/new/choose")!)
            }
        }
        .controlSize(.large)
        .formStyle(.grouped)
    }

    @MainActor private func deleteApp(_ appItem: AppMenuItem) {
        if let index = store.appItems.firstIndex(where: { $0.url == appItem.url }) {
            store.deleteAppItems(offsets: IndexSet(integer: index))
            channel.send(name: "RefreshMenuItems")
        }
    }
}

#Preview {
    ActionSettingsTabView(store: MenuItemStore())
}
