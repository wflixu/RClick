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
    var name: String { String(localized: String.LocalizationValue(key)) }
    var enabled = true
    var actionIndex: Int

    var icon: NSImage { NSImage(named: "icon")! }
}

extension ActionMenuItem {
    static var all: [ActionMenuItem] = [.copyPath, copyFileName, .goParent, .newFile]

    static let copyPath = ActionMenuItem(key: "Copy Path", actionIndex: 0)
    static let copyFileName = ActionMenuItem(key: "Copy File Name", actionIndex: 1)
    static let goParent = ActionMenuItem(key: "Go Parent Directory", actionIndex: 2)
    static let newFile = ActionMenuItem(key: "New File", actionIndex: 3)

    // MARK: - Making the compiler to extract Localized key

    #if DEBUG
    // FIXME: - Refactor this when compiler time const is introduced to Swift
    private static let copyPathString = NSLocalizedString("Copy Path", comment: "Copy Path")
    private static let copyFileNameString = NSLocalizedString("Copy File Name", comment: "Copy File Name")
    private static let goParentString = NSLocalizedString("Go Parent Directory", comment: "Go Parent Directory")
    private static let newFileString = NSLocalizedString("New File", comment: "New File")
    #endif
}
