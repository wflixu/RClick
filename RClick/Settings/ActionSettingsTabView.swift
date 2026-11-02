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
            }

            Section {
                List {
                    ForEach($appState.actions) { $item in
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent {
                                Toggle(AppLocalization.localized("Enabled"), isOn: $item.enabled)
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()
                                    .onChange(of: item.enabled) {
                                        appState.toggleActionItem()
                                        messager.sendRunningNotification()
                                    }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.secondary)
                                    Label(item.displayName, systemImage: item.icon)
                                }
                            }

                            // Nested under Direct Delete: only when that action is enabled.
                            if item.id == RCAction.deleteDirect.id, item.enabled {
                                Toggle(isOn: $appState.confirmBeforeDelete) {
                                    Text(appLocalized: "Confirm before delete")
                                }
                                .toggleStyle(.checkbox)
                                .padding(.leading, 28)
                                .help(AppLocalization.localized("When enabled, RClick asks before permanently deleting files. Direct delete bypasses Trash and cannot be undone."))
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 2, bottom: 8, trailing: 2))
                    }
                    .onMove { source, destination in
                        appState.moveActions(from: source, to: destination)
                        messager.sendRunningNotification()
                    }
                }
                .frame(minHeight: 180)
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
