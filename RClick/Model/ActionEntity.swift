//
//  ActionEntity.swift
//  RClick
//
//  Created by Claude on 2026/01/16.
//

import SwiftData
import Foundation

/// 动作实体 - 用于存储右键菜单动作配置
@Model
final class ActionEntity {
    @Attribute(.unique) var id: String
    var name: String
    var icon: String
    var isEnabled: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         name: String,
         icon: String,
         isEnabled: Bool = true,
         sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 从 RCAction 转换
    convenience init(from action: RCAction) {
        self.init(
            id: action.id,
            name: action.name,
            icon: action.icon,
            isEnabled: action.enabled,
            sortOrder: action.idx
        )
    }

    // 预定义动作的工厂方法
    static func createDefaultActions() -> [ActionEntity] {
        return [
            ActionEntity(id: "copy-path", name: "复制路径", icon: "doc.on.doc", sortOrder: 0),
            ActionEntity(id: "copy-filename", name: "复制文件名", icon: "doc.text", sortOrder: 1),
            ActionEntity(id: "reveal", name: "在Finder中显示", icon: "folder", sortOrder: 2),
            ActionEntity(id: "airdrop", name: "AirDrop", icon: "paperplane", sortOrder: 3),
            ActionEntity(id: "delete", name: "删除", icon: "trash", sortOrder: 4),
            ActionEntity(id: "hide", name: "隐藏", icon: "eye.slash", sortOrder: 5),
            ActionEntity(id: "unhide", name: "显示", icon: "eye", sortOrder: 6),
        ]
    }
}
