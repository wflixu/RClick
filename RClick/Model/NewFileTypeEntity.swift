//
//  NewFileTypeEntity.swift
//  RClick
//
//  Created by Claude on 2026/01/16.
//

import SwiftData
import Foundation

/// 新建文件类型实体 - 用于存储文件模板配置
@Model
final class NewFileTypeEntity {
    @Attribute(.unique) var id: String
    var fileExtension: String
    var name: String
    var icon: String
    var isEnabled: Bool
    var sortOrder: Int
    var templatePath: String?
    var openAppPath: String?
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         fileExtension: String,
         name: String,
         icon: String = "doc",
         isEnabled: Bool = true,
         sortOrder: Int = 0,
         templatePath: String? = nil,
         openAppPath: String? = nil) {
        self.id = id
        self.fileExtension = fileExtension
        self.name = name
        self.icon = icon
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.templatePath = templatePath
        self.openAppPath = openAppPath
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 从 NewFile 转换
    convenience init(from newFile: NewFile) {
        self.init(
            id: newFile.id,
            fileExtension: newFile.ext,
            name: newFile.name,
            icon: newFile.icon,
            isEnabled: newFile.enabled,
            sortOrder: newFile.idx
        )
    }

    // 预定义文件类型的工厂方法
    static func createDefaultFileTypes() -> [NewFileTypeEntity] {
        return [
            NewFileTypeEntity(id: "txt", fileExtension: ".txt", name: "TXT", icon: "doc.text", sortOrder: 0),
            NewFileTypeEntity(id: "md", fileExtension: ".md", name: "Markdown", icon: "doc.richtext", sortOrder: 1),
            NewFileTypeEntity(id: "json", fileExtension: ".json", name: "JSON", icon: "curlybraces", sortOrder: 2),
            NewFileTypeEntity(id: "docx", fileExtension: ".docx", name: "DOCX", icon: "doc.richtext.fill", sortOrder: 3),
            NewFileTypeEntity(id: "pptx", fileExtension: ".pptx", name: "PPTX", icon: "rectangle.on.rectangle.fill", sortOrder: 4),
            NewFileTypeEntity(id: "xlsx", fileExtension: ".xlsx", name: "XLSX", icon: "tablecells", sortOrder: 5),
            NewFileTypeEntity(id: "pages", fileExtension: ".pages", name: "Pages", icon: "doc.richtext", sortOrder: 6),
            NewFileTypeEntity(id: "key", fileExtension: ".key", name: "Keynote", icon: "rectangle.on.rectangle", sortOrder: 7),
            NewFileTypeEntity(id: "numbers", fileExtension: ".numbers", name: "Numbers", icon: "tablecells", sortOrder: 8),
        ]
    }
}
