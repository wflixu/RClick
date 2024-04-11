//
//  ActionMenuItem.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import Foundation

import AppKit

struct ActionMenuItem: MenuItem {
    static func == (lhs: ActionMenuItem, rhs: ActionMenuItem) -> Bool {
        lhs.name == rhs.name
    }

    var key: String
    var name: String
    var enabled = true
    var actionIndex: Int
    var iconName: String

//    var icon: NSImage {NSImage(systemSymbolName: iconName, accessibilityDescription: iconName)!}
}

extension ActionMenuItem {
    static var all: [ActionMenuItem] = [.copyPath, .deleteDirect]

    static let copyPath = ActionMenuItem(key: "Copy Path", name: "拷贝路径", actionIndex: 0, iconName: "doc.on.doc")
    static let deleteDirect = ActionMenuItem(key: "Delete Direct", name: "删除文件", actionIndex: 1, iconName: "trash")

    // MARK: - Making the compiler to extract Localized key

    #if DEBUG
    // FIXME: - Refactor this when compiler time const is introduced to Swift
    private static let copyPathString = NSLocalizedString("Copy Path", comment: "Copy Path")
    private static let copyFileNameString = NSLocalizedString("Delete Direct", comment: "Delete Direct")

    #endif
}
