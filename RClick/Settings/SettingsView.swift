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
    case about = "About"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: "slider.horizontal.2.square"
        case .apps: "apps.ipad.landscape"
        case .actions: "ellipsis.rectangle"
        case .newFile: "doc.badge.plus"
        case .about: "exclamationmark.circle"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: Tabs = .general
    @EnvironmentObject var appState: AppState
    @State var showSelectApp = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航
            VStack {
                // App Icon 部分
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
                        Text("\(getAppVersion())")
                        Spacer()
                    }
                }
                .padding(.vertical)
                
                // 导航列表
                List(Tabs.allCases, selection: $selectedTab) { tab in
                    HStack {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .font(.title2)
                            .padding(.all, 8)
                            .padding(.leading, 16)
                        Spacer(minLength: 0)
                    }
                    .listRowInsets(.init(top: 0,
                                       leading: -16,
                                       bottom: 0,
                                       trailing: -16))
                    .background(tab == selectedTab ? Color.accentColor.opacity(0.3) : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTab = tab
                    }
                }
                .listStyle(.sidebar)
                
                Spacer()
            }
            .frame(width: 200)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // 分隔线
            Divider()
            
            // 右侧内容
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsTabView()
                case .apps:
                    AppsSettingsTabView()
                case .actions:
                    actionsSection
                case .newFile:
                    NewFileSettingsTabView()
                case .about:
                    AboutSettingsTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .frame(width: 800, height: 500)
    }
    
    // Actions 部分
    private var actionsSection: some View {
        VStack {
            HStack {
                Text("Action Items").font(.title2)
                Spacer()
                Button {
                    appState.resetActionItems()
                } label: {
                    Label("Reset", systemImage: "arrow.triangle.2.circlepath")
                        .font(.body)
                }
            }
            
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
                            }
                            .toggleStyle(.switch)
                    }
                }
            }
        }
    }
    
    func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Unknown"
    }
}

#Preview {
    SettingsView()
}
