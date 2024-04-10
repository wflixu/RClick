//
//  ActionSettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/9.
//

import SwiftUI

struct ActionSettingsTabView: View {
    @Bindable var store: MenuItemStore
    @State var showSubMenuForApplication = true
    @State var showSubMenuForAction = true

    @State var showSelectApp = false
    @State private var multiSelection = Set<UUID>()

    var body: some View {
        Form {
            Section {
//                Toggle(isOn: $showSubMenuForApplication) {
//                    Text("Show as submenu")
//                }
                List(selection: $multiSelection) {
                    ForEach($store.appItems) { $item in
                        HStack {
                            Image(nsImage: item.icon)
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

                        case .failure(let error):
                            // handle error
                            print(error)
                        }
                    }
                }
            }

            // Mark

            Section {
//                Toggle(isOn: $showSubMenuForAction) {
//                    Text("Show as submenu")
//                }
                ForEach($store.actionItems) { $item in
                    HStack {
                        Image(nsImage: item.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        Text(item.name).font(.title2)
                        Spacer()
                        Toggle(isOn: $item.enabled) {}.toggleStyle(.switch)
                    }
                }
                .onMove { store.moveActionItems(from: $0, to: $1) }
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
            } footer: {
                Link("有想添加的功能", destination: URL(string: "https://github.com/wflixu/RClick/issues/new/choose")!)
            }
        }
        .controlSize(.large)
        .formStyle(.grouped)
//
    }

    private func deleteApp(_ appItem: AppMenuItem) {
        if let index = store.appItems.firstIndex(where: { $0.url == appItem.url }) {
            store.deleteAppItems(offsets: IndexSet(integer: index))
        }
    }
}

#Preview {
    ActionSettingsTabView(store: MenuItemStore())
}
