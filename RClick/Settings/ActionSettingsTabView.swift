//
//  ActionSettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/9.
//

import AppKit

import SwiftUI

struct ActionSettingsTabView: View {
    @EnvironmentObject var appState: AppState

    @State var showSelectApp = false

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(appState.apps) { item in
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
                    Text("Menu App").font(.title2)
                    Spacer()
                    Button {
                        showSelectApp = true
                    } label: {
                        Label("Add", systemImage: "plus.app")
                            .font(.body)
                    }
                    .fileImporter(
                        isPresented: $showSelectApp,
                        allowedContentTypes: [.application],
                        allowsMultipleSelection: false

                    ) { result in
                        switch result {
                        case .success(let files):
                            if let url = files.first {
                                appState.addApp(item: OpenWithApp(appURL: url))
                            }

//                            channel.send(name: "RefreshMenuItems")
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
                    ForEach($appState.actions) { $item in
                        HStack {
                            Image(systemName: item.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            Text(LocalizedStringKey(item.name)).font(.title2)
                            Spacer()
                            Toggle("", isOn: $item.enabled)
                                .onChange(of: item.enabled) {
                                    appState.toggleActionItem()
//                                    channel.send(name: "RefreshMenuItems")
                                }
                                .toggleStyle(.switch)
                        }
                    }
                }

            } header: {
                HStack {
                    Text("Action Item").font(.title2)
                    Spacer()
                    Button {
                        appState.resetActionItems()
                    } label: {
                        Label("Reset", systemImage: "arrow.triangle.2.circlepath")
                            .font(.body)
                    }
                }
            }

            // Mark
            Section {
                List {
                    ForEach($appState.newFiles) { $item in
                        HStack {
                            Image(item.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            Text(item.name).font(.title2)
                            Spacer()
                            Toggle("", isOn: $item.enabled)
                                .onChange(of: item.enabled) {
                                    appState.toggleActionItem()
//                                    channel.send(name: "RefreshMenuItems")
                                }
                                .toggleStyle(.switch)
                        }
                    }
                }

            } header: {
                HStack {
                    Text("New File").font(.title2)
                    Spacer()
                    Button {
                        appState.resetFiletypeItems()
                    } label: {
                        Label("Reset", systemImage: "arrow.triangle.2.circlepath")
                            .font(.body)
                    }
                }
            } footer: {
                Link("Want to add a feature? Give feedback here.", destination: URL(string: "https://github.com/wflixu/RClick/issues/new/choose")!)
            }
        }
        .controlSize(.large)
        .formStyle(.grouped)
    }

    @MainActor private func deleteApp(_ appItem: OpenWithApp) {
        if let index = appState.apps.firstIndex(where: { $0.id == appItem.id }) {
            appState.deleteApp(index: index)
        }
    }
}
