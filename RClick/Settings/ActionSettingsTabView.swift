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
                                messager.sendMessage(name: "running", data: MessagePayload(action: "running", target: []))
                            }
                            .toggleStyle(.switch)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }
            }
        }
    }
}
