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
}

extension ActionMenuItem {
    static var all: [ActionMenuItem] = [.copyPath, .deleteDirect]

    static let copyPath = ActionMenuItem(key: "Copy Path", name: "Copy Path", actionIndex: 0, iconName: "doc.on.doc")
    static let deleteDirect = ActionMenuItem(key: "Delete Direct", name: "Delete Direct", actionIndex: 1, iconName: "trash")
}
