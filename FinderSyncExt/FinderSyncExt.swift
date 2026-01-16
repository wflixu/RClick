//
//  FinderSyncExt.swift
//  FinderSyncExt
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import Cocoa
import FinderSync
import SwiftData

// MARK: DELETE

import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RClick", category: "FinderOpen")

// MARK: - Extension State Management

extension FinderSyncExt {
    /// Current action menu items received from main app
    var actionMenuItems: [ActionMenuItem] {
        get {
            guard let data = UserDefaults.group.data(forKey: Key.actionMenuItems),
                  let items = try? JSONDecoder().decode([ActionMenuItem].self, from: data) else {
                return []
            }
            return items
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.group.set(data, forKey: Key.actionMenuItems)
        }
    }

    /// Current app menu items received from main app
    var appMenuItems: [AppMenuItem] {
        get {
            guard let data = UserDefaults.group.data(forKey: Key.appMenuItems),
                  let items = try? JSONDecoder().decode([AppMenuItem].self, from: data) else {
                return []
            }
            return items
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.group.set(data, forKey: Key.appMenuItems)
        }
    }
}

// MARK: - Icon Cache

@MainActor
class IconCache {
    static let shared = IconCache()

    // Memory cache: URL -> NSImage
    private var memoryCache: [String: NSImage] = [:]

    // Icon size for caching (standard 32x32 for menu items)
    private let iconSize = CGSize(width: 32, height: 32)

    private init() {}

    /// Get icon with caching
    /// - Parameter url: The file URL to get icon for
    /// - Returns: Cached or newly loaded icon
    func icon(for url: URL) -> NSImage {
        let cacheKey = url.path

        // Check memory cache first
        if let cached = memoryCache[cacheKey] {
            return cached
        }

        // Load icon
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = iconSize

        // Store in memory cache
        memoryCache[cacheKey] = icon

        return icon
    }

    /// Clear memory cache (call on memory warning)
    func clearMemoryCache() {
        memoryCache.removeAll()
    }

    /// Preload icons for array of URLs
    /// - Parameter urls: Array of URLs to preload icons for
    func preloadIcons(for urls: [URL]) {
        for url in urls {
            _ = icon(for: url)
        }
    }
}

@MainActor
class FinderSyncExt: FIFinderSync {
    var myFolderURL = URL(fileURLWithPath: "/Users/")
    var isHostAppOpen = false

    private var tagRidDict: [Int: String] = [:]

    var triggerManKind = FIMenuKind.contextualMenuForContainer

    override init() {
        super.init()

        FIFinderSyncController.default().directoryURLs = [myFolderURL]
        logger.info("FinderSync() launched from \(Bundle.main.bundlePath as NSString)")

        // Register message handlers
        Messager.shared.on(name: "quit") { _ in
            logger.info("Extension received quit message")
            self.isHostAppOpen = false
        }

        Messager.shared.on(name: "running") { payload in
            logger.info("Extension received running message")
            self.isHostAppOpen = true

            if payload.target.count > 0 {
                FIFinderSyncController.default().directoryURLs = Set(payload.target.map { URL(fileURLWithPath: $0) })
                logger.info("Updated directory URLs from main app")
            }
            Task {
                self.heartBeat()
            }
        }

        // Handler for receiving updated menu configurations from main app
        Messager.shared.on(name: Key.messageFromMain) { payload in
            logger.info("Extension received config update from main app: \(payload.action)")

            switch payload.action {
            case "update-menu":
                logger.info("Menu configuration updated, will reload on next menu build")
                // Menu items are stored in UserDefaults, so they'll be automatically available
                // on the next menu creation via createActionMenuItems() and createAppItems()
            default:
                logger.warning("Unknown config action: \(payload.action)")
            }
        }

        heartBeat()
    }

    func heartBeat() {
        logger.info("Extension heartbeat")
        Messager.shared.sendMessage(name: Key.messageFromFinder, data: MessagePayload(action: "heartbeat", target: [], rid: ""))
    }

    // MARK: - Primary Finder Sync protocol methods

    override func beginObservingDirectory(at url: URL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        logger.info("beginObservingDirectoryAtURL: \(url.path as NSString)")
        let dirs = FIFinderSyncController.default().directoryURLs!

        for dir in dirs {
            logger.notice("Sync directory set to \(dir.path)")
        }
    }

    override func endObservingDirectory(at url: URL) {
        // The user is no longer seeing the container's contents.
        logger.info("endObservingDirectoryAtURL: \(url.path as NSString)")
    }

    override func requestBadgeIdentifier(for url: URL) {
        NSLog("requestBadgeIdentifierForURL: %@", url.path as NSString)
    }

    // MARK: - Menu and toolbar item support

    override var toolbarItemName: String {
        return "RClick"
    }

    override var toolbarItemToolTip: String {
        return "RClick: Click the toolbar item for a menu."
    }

    override var toolbarItemImage: NSImage {
        return NSImage(named: "toolbar")!
    }

    @MainActor override func menu(for menuKind: FIMenuKind) -> NSMenu {
        // Produce a menu for the extension.
        logger.info("mak menddd .....")
        triggerManKind = menuKind
        logger.info("start build menu ....")
        let applicationMenu = NSMenu(title: "RClick")
        guard isHostAppOpen else {
            logger.warning("host app is not open , return empty menu")
            return applicationMenu
        }

        switch menuKind {
        //  finder 中没有选中文件或文件夹

        case .toolbarItemMenu, .contextualMenuForItems, .contextualMenuForContainer:
            logger.info(" create menu for toolbar or contextual")
            createMenuForToolbar(applicationMenu)

        default:
            logger.warning("not have menuKind ")
        }

        return applicationMenu
    }

    @objc func createMenuForToolbar(_ applicationMenu: NSMenu) {
        for nsmenu in createAppItems() {
            logger.info("add app menu item \(nsmenu.title)")
            applicationMenu.addItem(nsmenu)
        }

        if let fileMenuItem = createFileCreateMenuItem() {
            logger.info("add file create menu item \(fileMenuItem.title)")
            applicationMenu.addItem(fileMenuItem)
        }

        if let commonDirMenuItem = createCommonDirMenuItem() {
            logger.info("add common dir menu item \(commonDirMenuItem.title)")
            applicationMenu.addItem(commonDirMenuItem)
        }

        for item in createActionMenuItems() {
            logger.info("add action menu item \(item.title)")
            applicationMenu.addItem(item)
        }
    }

    @objc func createAppItems() -> [NSMenuItem] {
        return []
        // guard isHostAppOpen else {
        //     logger.warning("Host app is not open, returning empty app menu")
        //     return []
        // }

        // let apps = appMenuItems
        // logger.info("Creating \(apps.count) app menu items")

        // return apps.map { app in
        //     let menuItem = NSMenuItem(title: app.name, action: #selector(appOpen(_:)), keyEquivalent: "")

        //     // Load app icon from cache
        //     let appIcon = IconCache.shared.icon(for: app.url)
        //     menuItem.image = appIcon

        //     // Assign unique tag for identifying the app
        //     let tag = getUniqueTag(for: app.id)
        //     menuItem.tag = tag

        //     logger.debug("Created app menu item: \(app.name) with tag \(tag)")
        //     return menuItem
        // }
    }

    private func getUniqueTag(for rid: String) -> Int {
        var newTag = Int.random(in: 1 ... Int.max)

        // 确保生成的 tag 不在已有的 keys 中
        while tagRidDict.keys.contains(newTag) {
            newTag = Int.random(in: 1 ... Int.max)
        }
        tagRidDict[newTag] = rid
        return newTag
    }

    @objc func createActionMenuItems() -> [NSMenuItem] {
        guard isHostAppOpen else {
            logger.warning("Host app is not open, returning empty action menu")
            return []
        }

        let actions = actionMenuItems
        logger.info("Creating \(actions.count) action menu items")

        return actions.map { action in
            let menuItem = NSMenuItem(title: action.name, action: #selector(actioning(_:)), keyEquivalent: "")

            // Set icon if available
            if let icon = NSImage(systemSymbolName: action.icon, accessibilityDescription: action.name) {
                icon.size = NSSize(width: 16, height: 16)
                menuItem.image = icon
            }

            // Assign unique tag for identifying the action
            let tag = getUniqueTag(for: action.id)
            menuItem.tag = tag

            // Enable/disable based on configuration
            menuItem.isEnabled = action.enabled

            logger.debug("Created action menu item: \(action.name) with tag \(tag)")
            return menuItem
        }
    }

    // 创建文件菜单容器
    @objc func createCommonDirMenuItem() -> NSMenuItem? {
        // TODO: Extension will receive menu config from main app in future
        return nil
    }

    @MainActor @objc func openCommonDir(_ menuItem: NSMenuItem) {
        // TODO: Implement when extension receives menu config
    }

    @objc func createFileCreateMenuItem() -> NSMenuItem? {
        // TODO: Extension will receive menu config from main app in future
        return nil
    }

    @MainActor @objc func createFile(_ menuItem: NSMenuItem) {
        guard let rid = tagRidDict[menuItem.tag] else {
            logger.warning("not get rid for \(menuItem.tag)")
            return
        }
        let url = FIFinderSyncController.default().targetedURL()

        if let target = url?.path() {
            Messager.shared.sendMessage(name: Key.messageFromFinder, data: MessagePayload(action: "Create File", target: [target], rid: rid))
        }
    }

    @MainActor @objc func actioning(_ menuItem: NSMenuItem) {
        guard let rid = tagRidDict[menuItem.tag] else {
            logger.warning("not get rid")
            return
        }
        let target = getTargets(triggerManKind)
        let trigger = getTriggerKind(triggerManKind)
        if target.isEmpty {
            logger.warning("not dir when actioning")
            return
        }
        logger.info("actioning \(rid) , trigger:\(trigger)")
        Messager.shared.sendMessage(name: Key.messageFromFinder, data: MessagePayload(action: "actioning", target: target, rid: rid, trigger: trigger))
    }

    func getTargets(_: FIMenuKind) -> [String] {
        var target: [String] = []

        switch triggerManKind {
        case FIMenuKind.contextualMenuForItems:
            if let urls = FIFinderSyncController.default().selectedItemURLs() {
                for url in urls {
                    target.append(url.path())
                }
            } else {
                logger.warning("not have selected dirs")
            }

        case FIMenuKind.toolbarItemMenu:
            if let urls = FIFinderSyncController.default().selectedItemURLs() {
                for url in urls {
                    target.append(url.path())
                }
            }
            if target.isEmpty {
                if let targetURL = FIFinderSyncController.default().targetedURL() {
                    target.append(targetURL.path())
                }
            }

        default:
            if let targetURL = FIFinderSyncController.default().targetedURL() {
                target.append(targetURL.path())
            }
        }

        return target
    }

    @objc func appOpen(_ menuItem: NSMenuItem) {
        guard let rid = tagRidDict[menuItem.tag] else {
            logger.warning("not get rid")
            return
        }

        let target: [String] = getTargets(triggerManKind)
        if !target.isEmpty {
            Messager.shared.sendMessage(name: Key.messageFromFinder, data: MessagePayload(action: "open", target: target, rid: rid))
        } else {
            logger.warning("not get target")
        }
    }

    @objc func getTriggerKind(_ kind: FIMenuKind) -> String {
        switch kind {
        case .contextualMenuForItems:
            return "ctx-items"
        case .contextualMenuForContainer:
            return "ctx-container"
        case .contextualMenuForSidebar:
            return "ctx-sidebar"
        case .toolbarItemMenu:
            return "toolbar"
        default:
            return "unknown"
        }
    }
}
