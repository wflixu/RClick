//
//  FinderSyncExt.swift
//  FinderSyncExt
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import Cocoa
import FinderSync
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RClick", category: "FinderSyncExt")

@MainActor
class FinderSyncExt: FIFinderSync {

    override init() {
        super.init()
        logger.error("===== FinderSyncExt 初始化 =====")
        logger.error("Bundle Path: \(Bundle.main.bundlePath)")
        logger.error("Bundle Identifier: \(Bundle.main.bundleIdentifier ?? "nil")")
    }

    // MARK: - 全盘监听

    override func beginObservingDirectory(at url: URL) {
        logger.error("===== beginObservingDirectory: \(url.path) =====")
    }

    override func endObservingDirectory(at url: URL) {
        logger.error("endObservingDirectory: \(url.path)")
    }

    // MARK: - Menu

    override var toolbarItemName: String {
        return "RClick"
    }

    override var toolbarItemToolTip: String {
        return "RClick: Click the toolbar item for a menu."
    }

    override var toolbarItemImage: NSImage {
        return NSImage(systemSymbolName: "folder", accessibilityDescription: "RClick")!
    }

    @MainActor override func menu(for menuKind: FIMenuKind) -> NSMenu {
        logger.error("===== menu(for:) 被调用，menuKind: \(menuKind.rawValue) =====")

        let applicationMenu = NSMenu(title: "RClick")

        // 添加一个测试菜单项
        let testItem = NSMenuItem(title: "测试菜单项", action: #selector(testAction(_:)), keyEquivalent: "")
        testItem.target = self
        applicationMenu.addItem(testItem)

        logger.error("菜单创建完成，包含 1 个菜单项")

        return applicationMenu
    }

    @objc func testAction(_ sender: NSMenuItem) {
        logger.error("===== 测试菜单项被点击 =====")
        print("测试菜单项被点击！")
    }
}
