//
//  SettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
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
        case .general: "gearshape"
        case .apps: "app.badge"
        case .actions: "bolt.square"
        case .newFile: "doc.badge.plus"
        case .cdirs: "folder.badge.gearshape"
        case .about: "info.circle"
        }
    }

    /// 每个 tab 图标对应的圆角色块颜色
    var iconColor: Color {
        switch self {
        case .general: .blue
        case .apps: .indigo
        case .actions: .orange
        case .newFile: .green
        case .cdirs: .teal
        case .about: .purple
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: Tabs = .general
    @EnvironmentObject var appState: AppState
    @State var showSelectApp = false

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            // 顶部品牌区：图标 + 名字 + 版本号
            VStack(spacing: 6) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)

                Text("RClick")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("v\(self.getAppVersion())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // 六个 tab 垂直排列，间距完全由代码控制（无原生 List 隐藏 inset）
            VStack(spacing: 4) {
                ForEach(Tabs.allCases, id: \.self) { tab in
                    sidebarButton(tab)
                }
            }
            .padding(.horizontal, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationSplitViewColumnWidth(200)
    }

    /// 侧边栏单个 tab：选中时行背景为图标色的半透明色（如绿色图标 → 半透明绿）
    private func sidebarButton(_ tab: Tabs) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(tab.iconColor)
                    )

                Text(appLocalized: tab.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? tab.iconColor.opacity(0.15) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        .frame(minWidth: 450)
    }

    var body: some View {
        NavigationSplitView {
            self.sidebar
        } detail: {
            self.detailView
        }
        .navigationTitle(AppLocalization.localized(selectedTab.rawValue))
        .background(Color(NSColor.windowBackgroundColor))
        // A failed write used to be invisible: the change stayed on screen but was
        // never stored, so the only way to notice was losing it on the next launch.
        .alert(
            Text(appLocalized: "Settings could not be saved"),
            isPresented: Binding(
                get: { appState.lastSaveError != nil },
                set: { if !$0 { appState.clearSaveError() } }
            )
        ) {
            Button(AppLocalization.localized("OK"), role: .cancel) { appState.clearSaveError() }
        } message: {
            Text(appState.lastSaveError ?? "")
        }
    }

    func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return AppLocalization.localized("Unknown")
    }
}


#Preview {
    SettingsView()
}
