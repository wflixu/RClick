//
//  File.swift
//  RClick
//
//  Created by 李旭 on 2024/9/26.
//

import Foundation

import Combine
import OrderedCollections
import SwiftUI

class AppState: ObservableObject {
    @AppLog(category: "AppState")
    private var logger
    
    @Published var apps: [OpenWithApp] = []
    @Published var dirs: [PermissiveDir] = []
    @Published var actions: [RCAction] = []
    @Published var newFiles: [NewFile] = []
    
    init() {
        Task {
            await MainActor.run {
                logger.info("start load")
                try? load()
            }
        }
    }
    
    // Apps
    @MainActor func deleteApp(index: Int) {
        apps.remove(at: index)
        do {
            try save()
            // 使用 result
        } catch {
            // 处理错误
            logger.info("save error: \(error.localizedDescription)")
        }
    }

    @MainActor func addApp(item: OpenWithApp) {
        logger.info("start add app")
        apps.append(item)
        
        do {
            try save()
            // 使用 result
        } catch {
            // 处理错误
            logger.info("save error: \(error.localizedDescription)")
        }
    }
    
    func getAppItem(rid: String) -> OpenWithApp? {
        apps.first { rid.contains($0.id) }
    }
    
    func getFileType(rid: String) -> NewFile? {
        newFiles.first { rid.contains($0.id) }
    }
    
    func getActionItem(rid: String) -> RCAction? {
        actions.first { rid.contains($0.id) }
    }
    
    // Action
    @MainActor func toggleActionItem() {
        try? save()
    }

    @MainActor func resetActionItems() {
        actions = RCAction.all
        try? save()
    }
    
    @MainActor func resetFiletypeItems() {
        newFiles = NewFile.all
        try? save()
    }
    
    // Permission
    @MainActor func deletePermissiveDir(index: Int) {
        dirs.remove(at: index)

        try? save()
    }

    @MainActor func hasParentBookmark(of url: URL) -> Bool {
        return false
//        let storedUrls = dirs.map { $0.url }
//        for storedURL in storedUrls {
//            // 确保 storedURL 是一个目录，并且传入的 URL 以 storedURL 的路径为前缀
//            if url.path.hasPrefix(storedURL.path) {
//                return true
//            }
//        }
//        return false
    }
    
    @MainActor
    private func save() throws {
        let encoder = PropertyListEncoder()
        let appItemsData = try encoder.encode(OrderedSet(apps))
        let actionItemsData = try encoder.encode(OrderedSet(actions))
        let filetypeItemsData = try encoder.encode(OrderedSet(newFiles))
        let permDirsData = try encoder.encode(OrderedSet(dirs))
        UserDefaults.group.set(appItemsData, forKey: Key.apps)
        UserDefaults.group.set(actionItemsData, forKey: Key.actions)
        UserDefaults.group.set(filetypeItemsData, forKey: Key.fileTypes)
        UserDefaults.group.set(permDirsData, forKey: Key.permDirs)
    }
    
    @MainActor
    func savePermissiveDir() throws {
        let encoder = PropertyListEncoder()
        let permDirsData = try encoder.encode(OrderedSet(dirs))
        UserDefaults.group.set(permDirsData, forKey: Key.permDirs)
    }
    
    @MainActor func refresh() {
        _ = try? load()
    }
    
    @MainActor
    private func load() throws {
        let decoder = PropertyListDecoder()
        
        if let permDirsData = UserDefaults.group.data(forKey: Key.permDirs) {
            dirs = try decoder.decode([PermissiveDir].self, from: permDirsData)
            logger.info("load permDir success")
        } else {
            logger.warning("load permission dirfailed")
           
            dirs = []
            
                  
        }
   
        if let actionData = UserDefaults.group.data(forKey: Key.actions) {
            actions = try decoder.decode([RCAction].self, from: actionData)
            logger.info("load actions success")
        } else {
            logger.warning("load actions failed")
            actions = RCAction.all
        }
        
        if let filetypeItemData = UserDefaults.group.data(forKey: Key.fileTypes) {
            newFiles = try decoder.decode([NewFile].self, from: filetypeItemData)
            logger.info("load filetype success")
        } else {
            logger.warning("load  new file type failed")
            newFiles = NewFile.all
        }
        
        if let appItemData = UserDefaults.group.data(forKey: Key.apps) {
            apps = try decoder.decode([OpenWithApp].self, from: appItemData)
            logger.info("load apps success")
        } else {
            logger.warning("load apps failed")
            apps = OpenWithApp.defaultApps
        }
    }
}
