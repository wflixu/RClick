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

// MARK: - Extension State Management

@MainActor
class FinderSyncExt: FIFinderSync {
    /// 监听目录：全盘监听（/Users/ + 外接磁盘）
    private var monitoredURLs: Set<URL> = []

    /// 主程序是否运行
    private var isHostAppOpen = false

    /// Tag 到资源 ID 的映射
    private var tagRidDict: [Int: String] = [:]

    /// 下一个可用的 Tag（递增，避免随机数冲突）
    private var nextTag: Int = 1

    /// 内存缓存：菜单配置
    private var cachedMenuConfig: MenuConfigPayload?
    /// 当前菜单版本号，用于防重复和防乱序
    private var currentVersion: Int = 0

    /// 当前菜单触发类型
    private var triggerManKind: FIMenuKind = .contextualMenuForContainer

    override init() {
        super.init()

        // 设置全盘监听
        setupMonitoredURLs()

        logger.info("FinderSyncExt launched from \(Bundle.main.bundlePath)")

        // 注册消息处理器
        setupMessageHandlers()

        // 发送心跳
        heartBeat()
    }

    // MARK: - 全盘监听

    private func setupMonitoredURLs() {
        var urls: Set<URL> = [URL(fileURLWithPath: "/Users/")]

        // 添加外接磁盘
        let volumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.isVolumeKey],
            options: [.skipHiddenVolumes]
        ) ?? []

        for volumeURL in volumeURLs where volumeURL.path != "/" {
            urls.insert(volumeURL)
        }

        monitoredURLs = urls
        FIFinderSyncController.default().directoryURLs = urls

        logger.info("Monitoring directories: \(urls.map { $0.path })")
    }

    // MARK: - 消息处理

    private func setupMessageHandlers() {
        // 处理主程序退出通知
        Messager.shared.onMainMessage(.quit) { [weak self] _ in
            self?.isHostAppOpen = false
            logger.info("Host app quit")
        }

        // 处理主程序启动通知
        Messager.shared.onMainMessage(.running) { [weak self] data in
            self?.isHostAppOpen = true
            logger.info("Host app running")

            if let payload: RunningPayload = Messager.shared.decode(data),
               !payload.directories.isEmpty {
                let urls = Set(payload.directories.map { URL(fileURLWithPath: $0) })
                FIFinderSyncController.default().directoryURLs = urls
                logger.info("Updated directory URLs: \(payload.directories)")
            }
        }

        // 处理菜单配置更新
        Messager.shared.onMainMessage(.menuConfig) { [weak self] data in
            guard let config: MenuConfigPayload = Messager.shared.decode(data) else {
                logger.warning("Failed to decode menu config")
                return
            }
            self?.cachedMenuConfig = config
            logger.info("Menu config updated: \(config.actions.count) actions, \(config.apps.count) apps")
        }

        // 处理菜单配置请求响应（主程序响应 Extension 的请求）
        Messager.shared.onMainMessage(.requestConfig) { [weak self] data in
            guard let config: MenuConfigPayload = Messager.shared.decode(data) else {
                logger.warning("Failed to decode menu config from request response")
                return
            }
            // 版本检查：只接受更新的版本
            guard self?.currentVersion ?? 0 < config.version else { return }
            self?.currentVersion = config.version
            self?.cachedMenuConfig = config
            logger.info("Menu config received via request: version \(config.version)")
        }
    }

    /// 发送心跳
    private func heartBeat() {
        logger.info("Heartbeat")
        Messager.shared.sendHeartbeat()

        // 定期发送心跳
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.heartBeat()
        }
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
        guard isHostAppOpen,
              let config = cachedMenuConfig,
              !config.apps.isEmpty else {
            return []
        }

        logger.info("Creating \(config.apps.count) app menu items")

        return config.apps.map { app in
            let menuItem = NSMenuItem(title: app.name, action: #selector(appOpen(_:)), keyEquivalent: "")

            // Load app icon from cache
            let appIcon = IconCache.shared.icon(for: app.url)
            menuItem.image = appIcon

            // Assign unique tag for identifying the app
            let tag = getUniqueTag(for: app.id)
            menuItem.tag = tag

            logger.debug("Created app menu item: \(app.name) with tag \(tag)")
            return menuItem
        }
    }

    private func getUniqueTag(for rid: String) -> Int {
        let tag = nextTag
        nextTag += 1
        tagRidDict[tag] = rid
        return tag
    }

    @objc func createActionMenuItems() -> [NSMenuItem] {
        guard isHostAppOpen,
              let config = cachedMenuConfig,
              !config.actions.isEmpty else {
            return []
        }

        logger.info("Creating \(config.actions.count) action menu items")

        return config.actions.map { action in
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

    // 创建常用目录菜单项
    @objc func createCommonDirMenuItem() -> NSMenuItem? {
        guard isHostAppOpen,
              let config = cachedMenuConfig,
              !config.commonDirs.isEmpty else {
            return nil
        }

        let menuItem = NSMenuItem(title: "常用目录", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "常用目录")

        for commonDir in config.commonDirs {
            let item = NSMenuItem(title: commonDir.name, action: #selector(openCommonDir(_:)), keyEquivalent: "")
            item.tag = getUniqueTag(for: commonDir.id)
            submenu.addItem(item)
        }

        menuItem.submenu = submenu
        return menuItem
    }

    @MainActor @objc func openCommonDir(_ menuItem: NSMenuItem) {
        guard let rid = tagRidDict[menuItem.tag] else {
            logger.warning("not get rid for \(menuItem.tag)")
            return
        }

        let target = getTargets(triggerManKind)
        if !target.isEmpty {
            let payload = ClickEventPayload(
                itemId: rid,
                itemType: .commonDir,
                target: target,
                trigger: MenuTrigger(rawValue: getTriggerKind(triggerManKind)) ?? .toolbar
            )
            Messager.shared.sendClickEvent(payload)
        }
    }

    @objc func createFileCreateMenuItem() -> NSMenuItem? {
        guard isHostAppOpen,
              let config = cachedMenuConfig,
              !config.newFiles.isEmpty else {
            return nil
        }

        let menuItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "新建文件")

        for newFile in config.newFiles {
            let item = NSMenuItem(title: newFile.name, action: #selector(createFile(_:)), keyEquivalent: "")
            item.tag = getUniqueTag(for: newFile.id)

            // 设置图标：使用 SF Symbol 或文件扩展名图标
            if let icon = NSImage(systemSymbolName: newFile.icon, accessibilityDescription: newFile.name) {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }

            submenu.addItem(item)
        }

        menuItem.submenu = submenu
        return menuItem
    }

    @MainActor @objc func createFile(_ menuItem: NSMenuItem) {
        guard let rid = tagRidDict[menuItem.tag] else {
            logger.warning("not get rid for \(menuItem.tag)")
            return
        }
        let url = FIFinderSyncController.default().targetedURL()

        if let target = url?.path() {
            let payload = ClickEventPayload(
                itemId: rid,
                itemType: .newFile,
                target: [target],
                trigger: .toolbar
            )
            Messager.shared.sendClickEvent(payload)
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

        let payload = ClickEventPayload(
            itemId: rid,
            itemType: .action,
            target: target,
            trigger: MenuTrigger(rawValue: trigger) ?? .toolbar
        )
        Messager.shared.sendClickEvent(payload)
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
            let payload = ClickEventPayload(
                itemId: rid,
                itemType: .app,
                target: target,
                trigger: MenuTrigger(rawValue: getTriggerKind(triggerManKind)) ?? .toolbar
            )
            Messager.shared.sendClickEvent(payload)
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
