//
//  BookmarkEntity.swift
//  RClick
//
//  Created by Claude on 2026/07/12.
//

import Foundation
import SwiftData

/// Security-Scoped Bookmark 持久化实体
///
/// 存储用户通过 NSOpenPanel 授权的目录的安全作用域书签，
/// 用于替代 Full Disk Access 权限。
///
/// 与 CommonDirEntity 独立：
/// - CommonDir: "我常用这个文件夹"（收藏夹语义）
/// - BookmarkEntity: "我授权访问这个文件夹"（权限凭证语义）
@Model
final class BookmarkEntity {
    /// 唯一标识
    @Attribute(.unique) var id: String
    /// 安全作用域 bookmark 二进制数据
    var bookmarkData: Data
    /// 目录路径（展示 + 匹配）
    var pathString: String
    /// 创建时间
    var createdAt: Date

    init(id: String = UUID().uuidString, bookmarkData: Data, pathString: String, createdAt: Date = Date()) {
        self.id = id
        self.bookmarkData = bookmarkData
        self.pathString = pathString
        self.createdAt = createdAt
    }
}
