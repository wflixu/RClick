//
//  AppsSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/11/18.
//

import SwiftUI

import AppKit

struct AppsSettingsTabView: View {
    @EnvironmentObject var appState: AppState
    @State var showSelectApp = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Menu Apps").font(.title2)
                Spacer()
                Button {
                    showSelectApp = true
                } label: {
                    Label("Add", systemImage: "plus.app")
                        .font(.body)
                }
            }
            
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
            case .failure(let error):
                print(error)
            }
        }
    }
    
    @MainActor private func deleteApp(_ appItem: OpenWithApp) {
        if let index = appState.apps.firstIndex(where: { $0.id == appItem.id }) {
            appState.deleteApp(index: index)
        }
    }
} 
