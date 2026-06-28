//
//  ActionSettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/9.
//

import SwiftUI

struct ActionSettingsTabView: View {
    @EnvironmentObject var appState: AppState

    let messager = Messager.shared

    var body: some View {
        Form {
            Section {
                Toggle("折叠动作菜单", isOn: $appState.foldActionsMenu)
                    .onChange(of: appState.foldActionsMenu) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }

                ForEach($appState.actions) { $item in
                    LabeledContent {
                        Toggle("启用", isOn: $item.enabled)
                            .toggleStyle(.switch)
                            .onChange(of: item.enabled) {
                                appState.toggleActionItem()
                                messager.sendRunningNotification()
                            }
                            .labelsHidden()
                    } label: {
                        Label(LocalizedStringKey(item.name), systemImage: item.icon)
                    }
                }
            } footer: {
                HStack {
                    Spacer()
                    Button("恢复到默认设置") {
                        appState.resetActionItems()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
