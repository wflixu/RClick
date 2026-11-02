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
    @State private var opensNewInstance: Bool
    @State private var opensContainingDir: Bool?

    let messager = Messager.shared

    init(app: OpenWithApp, appState: AppState) {
        self.app = app
        self.appState = appState
        _itemName = State(initialValue: app.itemName)
        _arguments = State(initialValue: app.arguments.joined(separator: "; "))
        _environment = State(initialValue: app.environment.map { "\($0.key)=\($0.value)" }.joined(separator: "\n"))
        _opensNewInstance = State(initialValue: app.opensNewInstance)
        _opensContainingDir = State(initialValue: app.opensContainingDir)
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

                Section {
                    Toggle(isOn: $opensNewInstance) {
                        Text(appLocalized: "Open in a new window")
                    }
                } header: {
                    Text(appLocalized: "Window")
                } footer: {
                    Text(appLocalized: "For browser-like apps, launch a new instance instead of opening a new tab in the running one")
                        .foregroundColor(.secondary)
                }

                Section {
                    Picker(selection: $opensContainingDir) {
                        Text(appLocalized: "Follow App Preset").tag(nil as Bool?)
                        Text(appLocalized: "On").tag(true as Bool?)
                        Text(appLocalized: "Off").tag(false as Bool?)
                    } label: {
                        Text(appLocalized: "Open Containing Folder")
                    }
                } footer: {
                    Text(appLocalized: "When a file is selected, open its containing folder instead")
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .background(PersistentScrollbar())

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
            environment: parseEnvironmentVariables(environment),
            opensNewInstance: opensNewInstance
        )
        appState.updateAppOpensContainingDir(id: app.id, value: opensContainingDir)
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

/// 让表单的滚动条常驻显示，提示下方还有配置项。
/// SwiftUI 的 .scrollIndicators(.visible) 对 Form 不生效，只能在 AppKit 层处理：
/// 系统默认的 overlay 滚动条不滚动时会自动隐藏，把该 NSScrollView 的
/// scrollerStyle 设为 .legacy 后滚动条固定可见（仅影响弹窗内这一个表单）。
private struct PersistentScrollbar: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // 等表单布局完成后再改，否则找不到 NSScrollView
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak view] in
            Self.apply(to: view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // SwiftUI 状态更新可能重建滚动视图，顺带重新应用一次（幂等）
        DispatchQueue.main.async { [weak nsView] in
            Self.apply(to: nsView?.window)
        }
    }

    private static func apply(to window: NSWindow?) {
        guard let contentView = window?.contentView else { return }
        scrollViews(in: contentView).forEach { scrollView in
            scrollView.hasVerticalScroller = true
            scrollView.scrollerStyle = .legacy
        }
    }

    /// 递归找出窗口里的全部 NSScrollView（弹窗内只有表单一个）
    private static func scrollViews(in view: NSView) -> [NSScrollView] {
        var found: [NSScrollView] = []
        if let scrollView = view as? NSScrollView {
            found.append(scrollView)
        }
        for child in view.subviews {
            found.append(contentsOf: scrollViews(in: child))
        }
        return found
    }
}
