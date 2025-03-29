//
//  SettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import SwiftUI

enum Tabs: String, CaseIterable, Identifiable {
    case general = "General"
    case apps = "Apps"
    case actions = "Actions"
    case newFile = "New File"
    case cdirs = "Common Dir"
    case about = "About"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .general: "slider.horizontal.2.square"
        case .apps: "apps.ipad.landscape"
        case .actions: "bolt.square"
        case .newFile: "doc.badge.plus"
        case .cdirs: "folder.badge.gearshape"
        case .about: "exclamationmark.circle"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: Tabs = .general
    @EnvironmentObject var appState: AppState
    @State var showSelectApp = false

    @ViewBuilder
    private var sidebar: some View {
        Section {
            Divider()
            List(selection: self.$selectedTab) {
                ForEach(Tabs.allCases, id: \.self) { tab in
                    HStack {
                        Label(LocalizedStringKey(tab.rawValue), systemImage: tab.icon)
                            .font(.title2)
                            .padding(.all, 8)
                        Spacer(minLength: 0)
                    }
                    .onTapGesture {
                        self.selectedTab = tab
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .scrollDisabled(true)
            .navigationSplitViewColumnWidth(210)
        } header: {
            //  App Icon 部分
            VStack {
                HStack {
                    Spacer()
                    Image("Logo")
                        .resizable()
                        .frame(width: 64, height: 64)
                    Spacer()
                }
                HStack {
                    Spacer()
                    Text("RClick").font(.title)
                    Text("\(self.getAppVersion())")
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .removeSidebarToggle()
    }

    @ViewBuilder var detailView: some View {
        // 右侧内容
        Group {
            switch self.selectedTab {
            case .general:
                GeneralSettingsTabView()
            case .apps:
                AppsSettingsTabView()
            case .actions:
                ActionSettingsTabView()
            case .newFile:
                NewFileSettingsTabView()
            case .cdirs:
                CommonDirsSettingTabView()
            case .about:
                AboutSettingsTabView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    var body: some View {
        NavigationSplitView {
            self.sidebar
        } detail: {
            self.detailView
        }
    }

    func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Unknown"
    }
}

extension View {
    /// Removes the sidebar toggle button from the toolbar.
    func removeSidebarToggle() -> some View {
        toolbar(removing: .sidebarToggle)
            .toolbar {
                Color.clear
            }
    }
}

#Preview {
    SettingsView()
}
