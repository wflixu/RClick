//
//  EditFileTypeSheetView.swift
//  RClick
//
//  Created by Claude on 2026/06/28.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EditFileTypeSheetView: View {
    let file: NewFile
    let appState: AppState

    var isAdding: Bool { file.ext.isEmpty && file.name.isEmpty }

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var ext: String
    @State private var icon: String
    @State private var openApp: URL?
    @State private var template: URL?

    @State private var showSelectApp = false
    @State private var showSelectTemplate = false

    let messager = Messager.shared

    private let iconToSF: [String: String] = [
        "icon-file-json": "curlybraces",
        "icon-file-txt": "doc.text",
        "icon-file-md": "doc.richtext",
        "icon-file-docx": "doc.richtext.fill",
        "icon-file-pptx": "rectangle.on.rectangle.fill",
        "icon-file-xlsx": "tablecells",
    ]

    let templatesDir: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("RClick/Templates")

    init(file: NewFile, appState: AppState) {
        self.file = file
        self.appState = appState
        _name = State(initialValue: file.name)
        _ext = State(initialValue: file.ext)
        _icon = State(initialValue: file.icon)
        _openApp = State(initialValue: file.openApp)
        _template = State(initialValue: file.template)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isAdding ? "添加文件类型" : "编辑文件类型")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Form {
                Section {
                    TextField("显示名称", text: $name)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("名称")
                }

                Section {
                    TextField("文件扩展名", text: $ext)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("扩展名")
                } footer: {
                    Text("例如：txt、md、json")
                        .foregroundColor(.secondary)
                }

                Section {
                    HStack {
                        if let templateUrl = template {
                            Text(templateUrl.lastPathComponent)
                            Button {
                                template = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            showSelectTemplate = true
                        } label: {
                            Text(template == nil ? "选择模板文件" : "更换模板")
                        }
                        .fileImporter(
                            isPresented: $showSelectTemplate,
                            allowedContentTypes: [.content],
                            allowsMultipleSelection: false
                        ) { result in
                            switch result {
                            case .success(let files):
                                if let url = files.first {
                                    template = url
                                }
                            case .failure:
                                break
                            }
                        }
                    }
                } header: {
                    Text("模板")
                }

                Section {
                    TextField("SF Symbol 名称", text: $icon)
                        .textFieldStyle(.roundedBorder)

                    if !icon.isEmpty {
                        HStack {
                            Text("预览:")
                            if let preview = FileTypeIconProvider.shared.icon(for: ext, fallbackSymbol: icon) {
                                Image(nsImage: preview)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "doc")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                        }
                    }
                } header: {
                    Text("图标")
                } footer: {
                    Text("输入 SF Symbol 名称，例如 doc.text、curlybraces")
                        .foregroundColor(.secondary)
                }

                Section {
                    HStack {
                        if let appUrl = openApp {
                            Image(nsImage: IconCache.shared.icon(for: appUrl))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(appUrl.lastPathComponent)
                        }

                        Button {
                            showSelectApp = true
                        } label: {
                            Text(openApp == nil ? "选择默认打开应用" : "更换应用")
                        }
                        .fileImporter(
                            isPresented: $showSelectApp,
                            allowedContentTypes: [.application],
                            allowsMultipleSelection: false
                        ) { result in
                            switch result {
                            case .success(let files):
                                if let url = files.first {
                                    openApp = url
                                }
                            case .failure:
                                break
                            }
                        }

                        if openApp != nil {
                            Button {
                                openApp = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("默认打开应用")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button(isAdding ? "添加" : "保存") {
                    saveChanges()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || ext.isEmpty)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 440, height: 580)
    }

    private func saveChanges() {
        if isAdding {
            var newFile = NewFile(
                ext: ext,
                name: name,
                idx: appState.newFiles.count,
                icon: icon
            )
            if let app = openApp {
                newFile.openApp = app
            }
            if let templateUrl = template {
                if let templateDir = templatesDir {
                    try? FileManager.default.createDirectory(at: templateDir, withIntermediateDirectories: true)
                    let destUrl = templateDir.appendingPathComponent(templateUrl.lastPathComponent)
                    try? FileManager.default.copyItem(at: templateUrl, to: destUrl)
                    newFile.template = destUrl
                }
            }
            appState.addNewFile(newFile)
        } else {
            if let index = appState.newFiles.firstIndex(where: { $0.id == file.id }) {
                var updatedFile = file
                updatedFile.name = name
                updatedFile.ext = ext
                updatedFile.icon = icon
                updatedFile.openApp = openApp
                if let templateUrl = template {
                    if let templateDir = templatesDir {
                        try? FileManager.default.createDirectory(at: templateDir, withIntermediateDirectories: true)
                        let destUrl = templateDir.appendingPathComponent(templateUrl.lastPathComponent)
                        try? FileManager.default.copyItem(at: templateUrl, to: destUrl)
                        updatedFile.template = destUrl
                    }
                }
                appState.newFiles[index] = updatedFile
            }
        }
        Task { @MainActor in
            appState.sync()
        }
        messager.sendRunningNotification()
    }
}
