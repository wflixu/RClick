//
//  CommonDirEntity.swift
//  RClick
//
//  Created by Claude on 2026/01/16.
//

import SwiftData
import Foundation

/// 常用目录实体 - 用于存储快速访问目录
@Model
final class CommonDirEntity {
    @Attribute(.unique) var id: String
    var name: String
    var pathString: String
    var icon: String
    var sortOrder: Int
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         name: String,
         path: URL,
         icon: String = "folder",
         sortOrder: Int = 0,
         isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.pathString = path.path()
        self.icon = icon
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var path: URL {
        get {
            URL(fileURLWithPath: pathString)
        }
        set {
            pathString = newValue.path()
        }
    }

    /// 从 CommonDir 转换
    convenience init(from commonDir: CommonDir) {
        self.init(
            id: commonDir.id,
            name: commonDir.name,
            path: commonDir.url,
            icon: commonDir.icon
        )
    }

    // 预定义常用目录的工厂方法
    static func createDefaultCommonDirs() -> [CommonDirEntity] {
        let fileManager = FileManager.default
        var dirs: [CommonDirEntity] = []

        let homeDir = fileManager.homeDirectoryForCurrentUser
        let desktop = homeDir.appendingPathComponent("Desktop")
        let documents = homeDir.appendingPathComponent("Documents")
        let downloads = homeDir.appendingPathComponent("Downloads")

        dirs.append(CommonDirEntity(id: "desktop", name: "桌面", path: desktop, icon: "desktopcomputer", sortOrder: 0))
        dirs.append(CommonDirEntity(id: "documents", name: "文档", path: documents, icon: "doc.folder", sortOrder: 1))
        dirs.append(CommonDirEntity(id: "downloads", name: "下载", path: downloads, icon: "arrow.down.circle", sortOrder: 2))
        dirs.append(CommonDirEntity(id: "applications", name: "应用程序", path: URL(fileURLWithPath: "/Applications"), icon: "app", sortOrder: 3))
        dirs.append(CommonDirEntity(id: "home", name: "用户主目录", path: homeDir, icon: "house", sortOrder: 4))

        return dirs
    }
}
