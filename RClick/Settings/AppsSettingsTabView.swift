//
//  AppsSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/11/18.
//

import AppKit
import SwiftUI

struct AppsSettingsTabView: View {
    @EnvironmentObject var appState: AppState
    @State var showSelectApp = false
    @State private var expandedAppId: String?
    @State private var editingApp: OpenWithApp?
    @State private var editingItemName: String = ""
    @State private var editingArguments: String = ""
    @State private var editingEnvironment: String = ""
    
    let messager = Messager.shared
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                   
                    Spacer()
                    Button {
                        showSelectApp = true
                    } label: {
                        Label("Add", systemImage: "plus.app")
                            .font(.body)
                    }
                }
                
                List {
                    ForEach(appState.apps) { item in
                        VStack {
                            // App 基本信息行
                            HStack {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                Text(item.name).font(.title2)
                                Spacer()
                                
                                // 展开/收起按钮
                                Button {
                                    withAnimation {
                                        if expandedAppId == item.id {
                                            expandedAppId = nil
                                        } else {
                                            expandedAppId = item.id
                                        }
                                    }
                                } label: {
                                    Image(systemName: expandedAppId == item.id ? "chevron.up" : "chevron.down")
                                }
                                
                                // 编辑按钮
                                Button {
                                    editingApp = item
                                    editingItemName = item.itemName
                                    editingArguments = item.arguments.joined(separator: "; ")
                                    editingEnvironment = item.environment.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                
                                // 删除按钮
                                Button {
                                    deleteApp(item)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            .padding(.vertical, 4)
                            
                            // 展开的属性信息
                            if expandedAppId == item.id {
                                VStack(alignment: .leading, spacing: 12) {
                                    if !item.arguments.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Arguments:").font(.headline)
                                            VStack(alignment: .leading, spacing: 2) {
                                                ForEach(item.arguments, id: \.self) { arg in
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "arrow.right")
                                                            .foregroundColor(.secondary)
                                                            .font(.caption)
                                                        Text(arg)
                                                            .font(.system(.body, design: .monospaced))
                                                    }
                                                }
                                            }
                                            .padding(.leading, 8)
                                        }
                                    }
                                    
                                    if !item.environment.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Environment:").font(.headline)
                                            VStack(alignment: .leading, spacing: 2) {
                                                ForEach(Array(item.environment.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "arrow.right")
                                                            .foregroundColor(.secondary)
                                                            .font(.caption)
                                                        Text("\(key)=\(value)")
                                                            .font(.system(.body, design: .monospaced))
                                                    }
                                                }
                                            }
                                            .padding(.leading, 8)
                                        }
                                    }
                                }
                                .padding(.leading, 40)
                                .padding(.vertical, 8)
                                
                                .transition(.opacity)
                                .frame(maxWidth: .infinity, alignment: .leading) // 添加这行使宽度填充整个可用空间
                                .background(Color(NSColor.alternatingContentBackgroundColors[1])) // 使用系统交替背景色
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showSelectApp,
                allowedContentTypes: [.application],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let files):
                    if let url = files.first {
                        appState.addApp(item: OpenWithApp(appURL: url))
                    }
                case .failure(let error):
                    print(error)
                }
            }
            
            // 编辑浮层
            if editingApp != nil {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        editingApp = nil
                    }
                
                VStack {
                    HStack {
                        Text("Edit App Properties").font(.title2)
                    }.padding(.top, 16)
                    
                    
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("Display Name").font(.headline)
                            TextField("Display Name", text: $editingItemName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Arguments").font(.headline)
                            Text("One argument per semicolon (;)").font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Arguments", text: $editingArguments)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Environment Variables").font(.headline)
                            Text("Format: KEY=VALUE, one per line").font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $editingEnvironment)
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 100)
                                .border(Color.gray.opacity(0.2))
                        }
                    }
                    .padding()
                    
                    HStack {
                        Button("Cancel") {
                            editingApp = nil
                        }
                        .keyboardShortcut(.escape)
                        
                        Button("Save") {
                            if let app = editingApp {
                                updateApp(app)
                            }
                            editingApp = nil
                        }
                        .keyboardShortcut(.return)
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
    
    @MainActor private func updateApp(_ app: OpenWithApp) {
        appState.updateApp(
            id: app.id,
            itemName: editingItemName,
            arguments: editingArguments.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            environment: parseEnvironmentVariables(editingEnvironment)
        )
        messager.sendMessage(name: "running", data: MessagePayload(action: "running", target: []))
    }
    
    @MainActor private func deleteApp(_ appItem: OpenWithApp) {
        if let index = appState.apps.firstIndex(where: { $0.id == appItem.id }) {
            appState.deleteApp(index: index)
            if expandedAppId == appItem.id {
                expandedAppId = nil
            }
        }
        messager.sendMessage(name: "running", data: MessagePayload(action: "running", target: []))
    }
}
