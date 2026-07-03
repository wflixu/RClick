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
                Toggle(isOn: $appState.foldActionsMenu) {
                    Text(appLocalized: "Collapse actions menu")
                }
                    .onChange(of: appState.foldActionsMenu) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }

                ForEach($appState.actions) { $item in
                    LabeledContent {
                        Toggle(AppLocalization.localized("Enabled"), isOn: $item.enabled)
                            .toggleStyle(.switch)
                            .onChange(of: item.enabled) {
                                appState.toggleActionItem()
                                messager.sendRunningNotification()
                            }
                            .labelsHidden()
                    } label: {
                        Label(item.displayName, systemImage: item.icon)
                    }
                }
            } footer: {
                HStack {
                    Spacer()
                    Button(AppLocalization.localized("Restore Defaults")) {
                        appState.resetActionItems()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
