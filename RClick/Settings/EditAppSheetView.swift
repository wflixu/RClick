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
            Text(appLocalized: "Edit App Properties")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Form {
                Section {
                    TextField(AppLocalization.localized("Display Name"), text: $itemName)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text(appLocalized: "Display Name")
                }

                Section {
                    TextField(AppLocalization.localized("Arguments (semicolon separated)"), text: $arguments)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text(appLocalized: "Run Arguments")
                } footer: {
                    Text(appLocalized: "Separate multiple arguments with semicolons (;)")
                        .foregroundColor(.secondary)
                }

                Section {
                    TextEditor(text: $environment)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.2))
                } header: {
                    Text(appLocalized: "Environment Variables")
                } footer: {
                    Text(appLocalized: "Format: KEY=VALUE, one per line")
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button(AppLocalization.localized("Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button(AppLocalization.localized("Save")) {
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
