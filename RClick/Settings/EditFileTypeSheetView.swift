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
    @State private var saveErrorMessage: String?

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
            Text(appLocalized: isAdding ? "Add File Type" : "Edit File Type")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Form {
                Section {
                    TextField(AppLocalization.localized("Display Name"), text: $name)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text(appLocalized: "Name")
                }

                Section {
                    TextField(AppLocalization.localized("File Extension"), text: $ext)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text(appLocalized: "File Extension")
                } footer: {
                    Text(appLocalized: "For example: txt, md, json")
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
                            Text(appLocalized: template == nil ? "Choose Template File" : "Change Template")
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
                    Text(appLocalized: "Template")
                }

                Section {
                    TextField(AppLocalization.localized("SF Symbol Name"), text: $icon)
                        .textFieldStyle(.roundedBorder)

                    if !icon.isEmpty {
                        HStack {
                            Text(appLocalized: "Preview:")
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
                    Text(appLocalized: "Icon")
                } footer: {
                    Text(appLocalized: "Enter an SF Symbol name, for example doc.text or curlybraces")
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
                            Text(appLocalized: openApp == nil ? "Choose Default App" : "Change App")
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
                    Text(appLocalized: "Default Open App")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button(AppLocalization.localized("Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button(AppLocalization.localized(isAdding ? "Add" : "Save")) {
                    do {
                        try saveChanges()
                        dismiss()
                    } catch {
                        if error is TemplateStorageError {
                            saveErrorMessage = AppLocalization.localized("The template storage folder is unavailable.")
                        } else {
                            saveErrorMessage = error.localizedDescription
                        }
                    }
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || ext.isEmpty)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 440, height: 580)
        .alert(
            Text(appLocalized: "Unable to Save File Type"),
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button(AppLocalization.localized("OK")) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private func saveChanges() throws {
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
            newFile.template = try storedTemplate(from: template, id: newFile.id, replacing: nil)
            appState.addNewFile(newFile)
        } else {
            if let index = appState.newFiles.firstIndex(where: { $0.id == file.id }) {
                var updatedFile = file
                updatedFile.name = name
                updatedFile.ext = ext
                updatedFile.icon = icon
                updatedFile.openApp = openApp
                updatedFile.template = try storedTemplate(from: template, id: file.id, replacing: file.template)
                appState.newFiles[index] = updatedFile
            }
        }
        appState.sync()
        messager.sendRunningNotification()
    }

    private func storedTemplate(from sourceURL: URL?, id: String, replacing previousURL: URL?) throws -> URL? {
        guard let templatesDir else {
            throw TemplateStorageError.applicationSupportUnavailable
        }
        guard let sourceURL else {
            try removeManagedTemplate(at: previousURL, templatesDir: templatesDir)
            return nil
        }

        try FileManager.default.createDirectory(at: templatesDir, withIntermediateDirectories: true)
        let fileName = sourceURL.pathExtension.isEmpty ? id : "\(id).\(sourceURL.pathExtension)"
        let destinationURL = templatesDir.appendingPathComponent(fileName)
        guard sourceURL.standardizedFileURL != destinationURL.standardizedFileURL else {
            return destinationURL
        }

        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let stagingURL = templatesDir.appendingPathComponent(".\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: stagingURL) }
        try FileManager.default.copyItem(at: sourceURL, to: stagingURL)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: stagingURL, to: destinationURL)

        if previousURL?.standardizedFileURL != destinationURL.standardizedFileURL {
            try removeManagedTemplate(at: previousURL, templatesDir: templatesDir)
        }
        return destinationURL
    }

    private func removeManagedTemplate(at url: URL?, templatesDir: URL) throws {
        guard let url,
              url.deletingLastPathComponent().standardizedFileURL == templatesDir.standardizedFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

private enum TemplateStorageError: Error {
    case applicationSupportUnavailable
}
