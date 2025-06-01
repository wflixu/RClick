//
//  NewFileSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/11/18.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NewFileSettingsTabView: View {
    @AppLog(category: "NewFileSettingsTabView")
    private var logger
    
    @EnvironmentObject var appState: AppState
    @State private var editingFile: NewFile?
    @State private var showSelectApp = false
    
    // 编辑状态
    @State private var editingName: String = ""
    @State private var editingExt: String = ""
    @State private var editingIcon: String = "document"
    @State private var editingOpenApp: URL?
    // 添加状态变量
    @State private var editingTemplate: URL?
    @State private var showSelectTemplate = false
    
    // 新建状态
    @State private var isAddingNew = false
    
    let messager = Messager.shared
    // 优化后的存储路径选择
    let templatesDir: URL? = // 选项1: 应用程序支持目录（推荐）
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("RClick/Templates")
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isAddingNew = true
                        editingFile = NewFile(ext: "", name: "", idx: appState.newFiles.count)
                        resetEditingFields()
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.body)
                    }
                    Button {
                        appState.resetFiletypeItems()
                    } label: {
                        Label("Reset", systemImage: "arrow.triangle.2.circlepath")
                            .font(.body)
                    }
                }
                // TODO: 编辑 Button 和 Toggle 放在列表的右边
                List {
                    ForEach($appState.newFiles) { $item in
                        HStack(spacing: 12) {
                            // 左侧图标和名称
                            HStack {
                                // 图标显示逻辑
                                if let appUrl = item.openApp {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: appUrl.path()))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 32, height: 32)
                                } else {
                                    if item.icon.starts(with: "icon-") {
                                        Image(item.icon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image(systemName: item.icon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                                
                                HStack(alignment: .center) {
                                    Text(item.name).font(.title3)
                                    Text(item.ext)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let templateUrl = item.template {
                                        Text(templateUrl.path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // 右侧按钮组
                            HStack(spacing: 16) {
                                Button {
                                    editingFile = item
                                    editingName = item.name
                                    editingExt = item.ext
                                    editingIcon = item.icon
                                    editingOpenApp = item.openApp
                                    editingTemplate = item.template
                                } label: {
                                    Image(systemName: "pencil")
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                                
                                Toggle("", isOn: $item.enabled)
                                    .onChange(of: item.enabled) {
                                        appState.toggleActionItem()
                                        messager.sendMessage(name: "running", data: MessagePayload(action: "running", target: []))
                                    }
                                    .toggleStyle(.switch)
                                    .frame(width: 50)
                            }
                            .padding(.trailing, 4)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            
            // 编辑浮层
            if editingFile != nil {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        cancelEditing()
                    }
                
                VStack {
                    Text(isAddingNew ? "Add New File Type" : "Edit File Type")
                        .font(.title2)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("Name").font(.headline)
                            TextField("Display Name", text: $editingName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Extension").font(.headline)
                            TextField("File Extension (e.g., .txt)", text: $editingExt)
                                .textFieldStyle(.roundedBorder)
                        }

                        // 在编辑浮层中添加模板选择部分
                        VStack(alignment: .leading) {
                            Text("Template").font(.headline)
                            HStack {
                                if let templateUrl = editingTemplate {
                                    Text(templateUrl.lastPathComponent)
                                    Button {
                                        editingTemplate = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                }
                                Button {
                                    self.showSelectTemplate = true
                                    self.logger.info("click.. sleect tele")
                                } label: {
                                    Text(editingTemplate == nil ? "Select Template" : "Change Template")
                                }
                                .fileImporter(
                                    isPresented: $showSelectTemplate,
                                    allowedContentTypes: [
                                        .content
                                    ],
                                    allowsMultipleSelection: false
                                ) { result in
                                    logger.warning("start select template result")
                                    switch result {
                                    case .success(let files):
                                        if let url = files.first {
                                            editingTemplate = url
                                        }
                                    case .failure:
                                        logger.warning("error when import template file")
                                    }
                                }
                                .zIndex(1)
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Icon").font(.headline)
                            TextField("SF Symbol name or custom icon", text: $editingIcon)
                                .textFieldStyle(.roundedBorder)
                            
                            if !editingIcon.isEmpty {
                                HStack {
                                    Text("Preview:")
                                    if editingIcon.starts(with: "icon-") {
                                        Image(editingIcon)
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image(systemName: editingIcon)
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Default Open App").font(.headline)
                            HStack {
                                if let appUrl = editingOpenApp {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: appUrl.path()))
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                    Text(appUrl.lastPathComponent)
                                }
                                
                                Button {
                                    showSelectApp = true
                                } label: {
                                    Text(editingOpenApp == nil ? "Select App" : "Change App")
                                }
                                .fileImporter(
                                    isPresented: $showSelectApp,
                                    allowedContentTypes: [.application],
                                    allowsMultipleSelection: false
                                ) { result in
                                    switch result {
                                    case .success(let files):
                                        if let url = files.first {
                                            editingOpenApp = url
                                        }
                                    case .failure(let error):
                                        print(error)
                                    }
                                }
                                .zIndex(1)
                                
                                if editingOpenApp != nil {
                                    Button {
                                        editingOpenApp = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding()
                    
                    HStack {
                        Button("Cancel") {
                            cancelEditing()
                        }
                        .keyboardShortcut(.escape)
                        
                        Button(isAddingNew ? "Add" : "Save") {
                            saveChanges()
                        }
                        .keyboardShortcut(.return)
                        .disabled(editingName.isEmpty || editingExt.isEmpty)
                    }
                    .padding(.bottom)
                }
                .frame(width: 400)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
    }

    private func resetEditingFields() {
        editingName = ""
        editingExt = ""
        editingIcon = "document"
        editingOpenApp = nil
    }
    
    private func cancelEditing() {
        editingFile = nil
        isAddingNew = false
        resetEditingFields()
    }
    
    private func saveChanges() {
        if isAddingNew {
            var newFile = NewFile(
                ext: editingExt,
                name: editingName,
                idx: appState.newFiles.count,
                icon: editingIcon
            )
            if let app = editingOpenApp {
                newFile.openApp = app
            }
            appState.addNewFile(newFile)
        } else if let file = editingFile,
                  let index = appState.newFiles.firstIndex(where: { $0.id == file.id })
        {
            var updatedFile = file
            updatedFile.name = editingName
            updatedFile.ext = editingExt
            updatedFile.icon = editingIcon
            updatedFile.openApp = editingOpenApp
            if let templateUrl = editingTemplate {
                // 创建目录并复制模板
                if let templateDir = templatesDir {
                    try? FileManager.default.createDirectory(at: templateDir, withIntermediateDirectories: true)
                    let destUrl = templateDir.appendingPathComponent(templateUrl.lastPathComponent)
                    try? FileManager.default.copyItem(at: templateUrl, to: destUrl)
                    updatedFile.template = destUrl
                }
            }
            appState.newFiles[index] = updatedFile
        }
        Task {
             appState.sync();
        }
        messager.sendMessage(name: "running", data: MessagePayload(action: "running", target: []))
        cancelEditing()
    }
}
