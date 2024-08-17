//
//  FiletypeMenuItem.swift
//  RClick
//
//  Created by 李旭 on 2024/8/10.
//

import Foundation

struct FiletypeMenuItem: MenuItem {
    static func == (lhs: FiletypeMenuItem, rhs: FiletypeMenuItem) -> Bool {
        lhs.name == rhs.name
    }

    var ext: String
    var name: String
    var enabled = true
    var actionIndex: Int
    var iconName: String
}

extension FiletypeMenuItem {
    static var all: [FiletypeMenuItem] = [.txt, .md, .json, .docx, .pptx, .xlsx]

    static let json = FiletypeMenuItem(ext: ".json", name: "JSON", actionIndex: 0, iconName: "icon-file-json")
    static let txt = FiletypeMenuItem(ext: ".txt", name: "TXT", actionIndex: 1, iconName: "icon-file-txt")
    static let md = FiletypeMenuItem(ext: ".md", name: "Markdown", actionIndex: 2, iconName: "icon-file-md")
    static let docx = FiletypeMenuItem(ext: ".docx", name: "DOCX", actionIndex: 3, iconName: "icon-file-docx")
    static let pptx = FiletypeMenuItem(ext: ".pptx", name: "PPTX", actionIndex: 4, iconName: "icon-file-pptx")
    static let xlsx = FiletypeMenuItem(ext: ".xlsx", name: "XLSX", actionIndex: 5, iconName: "icon-file-xlsx")
}
