//
//  EditAppSheetView.swift
//  RClick
//
//  Created by Claude on 2026/06/28.
//

import SwiftUI

struct EditAppSheetView: View {
    let app: OpenWithApp
    let appState: AppState

    @Environment(\.dismiss) private var dismiss

    @State private var itemName: String
    @State private var arguments: String
    @State private var environment: String

    let messager = Messager.shared

    init(app: OpenWithApp, appState: AppState) {
        self.app = app
        self.appState = appState
        _itemName = State(initialValue: app.itemName)
        _arguments = State(initialValue: app.arguments.joined(separator: "; "))
        _environment = State(initialValue: app.environment.map { "\($0.key)=\($0.value)" }.joined(separator: "\n"))
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("编辑应用属性")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Form {
                Section {
                    TextField("显示名称", text: $itemName)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("显示名称")
                }

                Section {
                    TextField("参数（分号分隔）", text: $arguments)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("运行参数")
                } footer: {
                    Text("多个参数用分号（;）分隔")
                        .foregroundColor(.secondary)
                }

                Section {
                    TextEditor(text: $environment)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.2))
                } header: {
                    Text("环境变量")
                } footer: {
                    Text("格式：KEY=VALUE，每行一个")
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("保存") {
                    saveChanges()
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 400, height: 480)
    }

    private func saveChanges() {
        appState.updateApp(
            id: app.id,
            itemName: itemName,
            arguments: arguments.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            environment: parseEnvironmentVariables(environment)
        )
        messager.sendRunningNotification()
    }

    private func parseEnvironmentVariables(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                result[String(parts[0]).trimmingCharacters(in: .whitespaces)] = String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }
}
