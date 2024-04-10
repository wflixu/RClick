//
//  SettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("showPreview") private var showPreview = true
    @AppStorage("fontSize") private var fontSize = 12.0
    @State var folderItemStore = FolderItemStore()
    @State var menumItemStore = MenuItemStore()

    private enum Tabs: Hashable {
        case general, folder, actions, about
    }

    var body: some View {
        TabView {
            GeneralSettingsTabView()
                .tabItem {
                    Label("通用", systemImage: "slider.horizontal.2.square")
                }
                .tag(Tabs.general)
             FolderSettingsTabView(store:folderItemStore)
                .tabItem {
                    Label("文件夹", systemImage: "folder.badge.gearshape")
                }
                .tag(Tabs.folder)
            
            
            ActionSettingsTabView(store: menumItemStore)
                .tabItem {
                    Label("操作", systemImage: "ellipsis.rectangle")
                }
                .tag(Tabs.actions)
            AboutSettingsTabView()
                .tabItem {
                    Label("关于", systemImage: "exclamationmark.circle")
                }
                .tag(Tabs.about)
        }
        .padding(20)
        .frame(width: 600, height: 450)
    }
    
}

#Preview {
    SettingsView()
}
