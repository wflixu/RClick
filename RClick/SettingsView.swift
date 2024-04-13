//
//  SettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import SwiftUI

enum Tabs: Hashable {
    case general, actions, about
}

struct SettingsView: View {
   
    
    @State var folderItemStore = FolderItemStore()
    @State var menumItemStore = MenuItemStore()
    @State private var tabIndex: Tabs = .general

    var body: some View {
        TabView(selection: $tabIndex) {
            GeneralSettingsTabView( store: folderItemStore)
                .tabItem {
                    Label("通用", systemImage: "slider.horizontal.2.square")
                }
                .tag(Tabs.general)
                ActionSettingsTabView(store: menumItemStore)
                    .tabItem {
                        Label("操作", systemImage: "ellipsis.rectangle")
                    }
                    .tag(Tabs.actions)

            AboutSettingsTabView()
                .tabItem {
                    Label(
                        "关于",
                        systemImage: "exclamationmark.circle"
                    )
                }
                .tag(Tabs.about)
        }.tabViewStyle(.automatic)
            .padding(20)
            .frame(width: 600, height: 450)
    }
}

#Preview {
    SettingsView()
}
