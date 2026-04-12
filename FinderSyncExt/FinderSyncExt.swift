//
//  FinderSyncExt.swift
//  FinderSyncExt
//
//  Created by luke on 2026/4/6.
//

import Cocoa
import FinderSync
import OSLog
import AppKit

// MARK: - Logger

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "RClick.FinderSyncExt",
    category: "FinderSyncExt"
)

// MARK: - Icon Loading

/// 从 Assets 加载图标
private func loadIcon(named iconName: String, accessibilityDescription description: String) -> NSImage? {
    // 优先从 Assets.xcassets 加载 PNG 图标，如果加载不到则尝试 SF Symbol
    if let icon = NSImage(named: iconName) {
        return icon
    }
    // 尝试 SF Symbol（CommonDir 使用 SF Symbol 名称）
    return NSImage(systemSymbolName: iconName, accessibilityDescription: description)
}

// MARK: - FinderSync Extension

/// FinderSync Extension - 瘦 Extension 架构
/// 只负责菜单渲染和事件转发，不读取 SwiftData
class FinderSyncExt: FIFinderSync {

    // MARK: - Properties

    /// 菜单配置缓存（内存缓存，从 Main App 推送）
    private var cachedMenuConfig: MenuConfigPayload?

    /// 消息管理器
    private let messager = Messager.shared

    // MARK: - Initialization

    override init() {
        super.init()

        logger.info("FinderSyncExt launched from \(Bundle.main.bundlePath)")

        // 设置监听目录（全盘监听）
        setupObservingDirectories()

        // 注册消息处理器
        setupMessageHandlers()

        // 启动心跳机制
        startHeartbeat()

        // 主动请求菜单配置
        requestMenuConfig()
    }

    // MARK: - Directory Observing

    /// 设置监听目录
    private func setupObservingDirectories() {
        var directories: Set<URL> = []

        // 添加 /Users/ 目录
        if let usersDir = URL(string: "file:///Users/") {
            directories.insert(usersDir)
        }

        // 添加外接磁盘目录
        let volumns = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: .skipHiddenVolumes
        ) ?? []

        for volume in volumns.dropFirst() { // dropFirst 跳过系统盘
            directories.insert(volume)
        }

        FIFinderSyncController.default().directoryURLs = directories
        logger.info("Observing directories: \(directories.map { $0.path })")
    }

    // MARK: - Message Handling

    /// 注册消息处理器
    private func setupMessageHandlers() {
        // 处理主程序发送的菜单配置
        messager.onMainMessage(.menuConfig) { [weak self] data in
            guard let self = self else { return }
            // 使用 decodeSignedData 解码签名数据
            if let config = self.messager.decodeSignedData(data, as: MenuConfigPayload.self) {
                self.handleMenuConfig(config)
            } else {
                logger.warning("Invalid menu config data")
            }
        }

        // 处理主程序发送的 running 通知
        messager.onMainMessage(.running) { [weak self] data in
            guard let self = self else { return }
            if let payload = self.messager.decodeSignedData(data, as: RunningPayload.self) {
                logger.info("Received running notification: \(payload.directories)")
                // 可以根据 payload 更新监听目录
            }
        }

        // 处理主程序发送的退出通知
        messager.onMainMessage(.quit) { _ in
            logger.info("Received quit notification from main app")
            // 可以标记主程序已退出
        }
    }

    /// 处理菜单配置
    private func handleMenuConfig(_ config: MenuConfigPayload) {
        cachedMenuConfig = config
        logger.info("Menu config cached: version=\(config.version), actions=\(config.actions.count), apps=\(config.apps.count)")
    }

    /// 请求菜单配置
    private func requestMenuConfig() {
        logger.info("Requesting menu config from main app")
        messager.requestMenuConfig()
    }

    // MARK: - Heartbeat

    /// 启动心跳机制（每 10 秒发送一次）
    private func startHeartbeat() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.messager.sendHeartbeat()
        }
        RunLoop.current.add(Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.messager.sendHeartbeat()
        }, forMode: .common)
    }

    // MARK: - Primary Finder Sync protocol methods

    override func beginObservingDirectory(at url: URL) {
        logger.info("beginObservingDirectoryAtURL: \(url.path)")
    }

    override func endObservingDirectory(at url: URL) {
        logger.info("endObservingDirectoryAtURL: \(url.path)")
    }

    override func requestBadgeIdentifier(for url: URL) {
        logger.info("requestBadgeIdentifierForURL: \(url.path)")

        // 示例：根据文件状态设置徽章
        let whichBadge = abs(url.path.hash) % 3
        let badgeIdentifier = ["", "One", "Two"][whichBadge]
        FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
    }

    // MARK: - Menu and toolbar item support

    override var toolbarItemName: String {
        return "RClick"
    }

    override var toolbarItemToolTip: String {
        return "RClick: Click for menu options"
    }

    override var toolbarItemImage: NSImage {
        return NSImage(named: NSImage.cautionName) ?? NSImage()
    }

    /// 构建并返回 Finder 上下文菜单
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "RClick")

        // 如果缓存为空，触发请求并返回加载中的菜单
        guard let config = cachedMenuConfig else {
            requestMenuConfig()
            menu.addItem(withTitle: "RClick (loading...)", action: nil, keyEquivalent: "")
            return menu
        }

        // 构建动作菜单
        if !config.actions.isEmpty {
            if config.actionsCollapsed {
                // 折叠：使用子菜单
                let actionsSubMenu = NSMenu(title: "Actions")
                for action in config.actions {
                    let item = NSMenuItem(title: action.name, action: #selector(handleActionClick(_:)), keyEquivalent: "")
                    item.tag = hashForAction(action)
                    if let icon = NSImage(systemSymbolName: action.icon, accessibilityDescription: action.name) {
                        item.image = icon
                    }
                    actionsSubMenu.addItem(item)
                }
                let actionsItem = NSMenuItem(title: "Actions", action: nil, keyEquivalent: "")
                actionsItem.submenu = actionsSubMenu
                menu.addItem(actionsItem)
            } else {
                // 不折叠：直接显示菜单项
                for action in config.actions {
                    let item = NSMenuItem(title: action.name, action: #selector(handleActionClick(_:)), keyEquivalent: "")
                    item.tag = hashForAction(action)
                    if let icon = NSImage(systemSymbolName: action.icon, accessibilityDescription: action.name) {
                        item.image = icon
                    }
                    menu.addItem(item)
                }
            }
        }

        // 构建应用菜单
        if !config.apps.isEmpty {
            if config.appsCollapsed {
                // 折叠：使用子菜单
                let appsSubMenu = NSMenu(title: "Open With")
                for app in config.apps {
                    let item = NSMenuItem(title: app.name, action: #selector(handleAppClick(_:)), keyEquivalent: "")
                    item.tag = hashForApp(app)
                    // 优先从应用路径获取图标，其次从 Assets 加载，最后使用 SF Symbol
                    if let appURL = app.appURL {
                        // NSWorkspace.icon(forFile:) 总是返回非空，但路径无效时返回通用图标
                        let icon = NSWorkspace.shared.icon(forFile: appURL)
                        // 检查是否是通用图标（通过比较大小或名称）
                        if icon.size.width > 0 {
                            item.image = icon
                        }
                    }
                    if item.image == nil {
                        if let icon = NSImage(named: app.icon) {
                            item.image = icon
                        } else if let icon = NSImage(systemSymbolName: app.icon, accessibilityDescription: app.name) {
                            item.image = icon
                        }
                    }
                    appsSubMenu.addItem(item)
                }
                let appsItem = NSMenuItem(title: "Open With", action: nil, keyEquivalent: "")
                appsItem.submenu = appsSubMenu
                menu.addItem(appsItem)
            } else {
                // 不折叠：直接显示菜单项
                for app in config.apps {
                    let item = NSMenuItem(title: app.name, action: #selector(handleAppClick(_:)), keyEquivalent: "")
                    item.tag = hashForApp(app)
                    // 优先从应用路径获取图标，其次从 Assets 加载，最后使用 SF Symbol
                    if let appURL = app.appURL {
                        // NSWorkspace.icon(forFile:) 总是返回非空，但路径无效时返回通用图标
                        let icon = NSWorkspace.shared.icon(forFile: appURL)
                        // 检查是否是通用图标（通过比较大小或名称）
                        if icon.size.width > 0 {
                            item.image = icon
                        }
                    }
                    if item.image == nil {
                        if let icon = NSImage(named: app.icon) {
                            item.image = icon
                        } else if let icon = NSImage(systemSymbolName: app.icon, accessibilityDescription: app.name) {
                            item.image = icon
                        }
                    }
                    menu.addItem(item)
                }
            }
        }

        // 构建新建文件菜单
        if !config.newFiles.isEmpty {
            if config.newFilesCollapsed {
                // 折叠：使用子菜单
                let newFilesSubMenu = NSMenu(title: "New File")
                for newFile in config.newFiles {
                    let item = NSMenuItem(title: newFile.name, action: #selector(handleNewFileClick(_:)), keyEquivalent: "")
                    item.tag = hashForNewFile(newFile)
                    item.image = loadIcon(named: newFile.icon, accessibilityDescription: newFile.name)
                    newFilesSubMenu.addItem(item)
                }
                let newFilesItem = NSMenuItem(title: NSLocalizedString("New File", comment: ""), action: nil, keyEquivalent: "")
                newFilesItem.submenu = newFilesSubMenu
                newFilesItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "New File")
                menu.addItem(newFilesItem)
            } else {
                // 不折叠：直接显示菜单项
                for newFile in config.newFiles {
                    let item = NSMenuItem(title: newFile.name, action: #selector(handleNewFileClick(_:)), keyEquivalent: "")
                    item.tag = hashForNewFile(newFile)
                    item.image = loadIcon(named: newFile.icon, accessibilityDescription: newFile.name)
                    menu.addItem(item)
                }
            }
        }

        // 构建常用目录菜单
        if !config.commonDirs.isEmpty {
            if config.commonDirsCollapsed {
                // 折叠：使用子菜单
                let commonDirsSubMenu = NSMenu(title: "Common Dirs")
                for commonDir in config.commonDirs {
                    let item = NSMenuItem(title: commonDir.name, action: #selector(handleCommonDirClick(_:)), keyEquivalent: "")
                    item.tag = hashForCommonDir(commonDir)
                    item.image = loadIcon(named: commonDir.icon, accessibilityDescription: commonDir.name)
                    commonDirsSubMenu.addItem(item)
                }
                let commonDirsItem = NSMenuItem(title: NSLocalizedString("Common Dirs", comment: ""), action: nil, keyEquivalent: "")
                commonDirsItem.submenu = commonDirsSubMenu
                commonDirsItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Common Dirs")
                menu.addItem(commonDirsItem)
            } else {
                // 不折叠：直接显示菜单项
                for commonDir in config.commonDirs {
                    let item = NSMenuItem(title: commonDir.name, action: #selector(handleCommonDirClick(_:)), keyEquivalent: "")
                    item.tag = hashForCommonDir(commonDir)
                    item.image = loadIcon(named: commonDir.icon, accessibilityDescription: commonDir.name)
                    menu.addItem(item)
                }
            }
        }

        return menu
    }

    // MARK: - Menu Item Hash Functions

    private func hashForAction(_ action: ActionMenuItem) -> Int {
        return "action_\(action.id)".hash
    }

    private func hashForApp(_ app: AppMenuItem) -> Int {
        return "app_\(app.id)".hash
    }

    private func hashForNewFile(_ newFile: NewFileMenuItem) -> Int {
        return "newfile_\(newFile.id)".hash
    }

    private func hashForCommonDir(_ commonDir: CommonDirMenuItem) -> Int {
        return "commondir_\(commonDir.id)".hash
    }

    // MARK: - Menu Action Handlers

    @objc private func handleActionClick(_ sender: NSMenuItem) {
        guard let config = cachedMenuConfig,
              let action = config.actions.first(where: { hashForAction($0) == sender.tag }) else {
            logger.warning("Action not found for tag: \(sender.tag)")
            return
        }

        logger.info("Action clicked: \(action.name) (id: \(action.id))")

        // 获取选中的文件/目录
        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        let itemPaths = selectedItems.map { $0.path }

        // 发送点击事件到主程序
        let event = ClickEventPayload(
            itemId: action.id,
            itemType: .action,
            target: itemPaths,
            trigger: getTriggerForMenuKind()
        )
        messager.sendClickEvent(event)
    }

    @objc private func handleAppClick(_ sender: NSMenuItem) {
        logger.info("handleAppClick called with sender: \(sender.title), tag: \(sender.tag)")

        guard let config = cachedMenuConfig,
              let app = config.apps.first(where: { hashForApp($0) == sender.tag }) else {
            logger.warning("App not found for tag: \(sender.tag)")
            return
        }

        logger.info("App clicked: \(app.name) (id: \(app.id))")

        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        let itemPaths = selectedItems.map { $0.path }
        logger.info("Selected items: \(itemPaths)")

        let event = ClickEventPayload(
            itemId: app.id,
            itemType: .app,
            target: itemPaths,
            trigger: getTriggerForMenuKind()
        )
        logger.info("Sending click event for app: \(app.name)")
        messager.sendClickEvent(event)
    }

    @objc private func handleNewFileClick(_ sender: NSMenuItem) {
        guard let config = cachedMenuConfig,
              let newFile = config.newFiles.first(where: { hashForNewFile($0) == sender.tag }) else {
            logger.warning("NewFile not found for tag: \(sender.tag)")
            return
        }

        logger.info("NewFile clicked: \(newFile.name) (id: \(newFile.id))")

        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        let itemPaths = selectedItems.map { $0.path }

        let event = ClickEventPayload(
            itemId: newFile.id,
            itemType: .newFile,
            target: itemPaths,
            trigger: getTriggerForMenuKind()
        )
        messager.sendClickEvent(event)
    }

    @objc private func handleCommonDirClick(_ sender: NSMenuItem) {
        guard let config = cachedMenuConfig,
              let commonDir = config.commonDirs.first(where: { hashForCommonDir($0) == sender.tag }) else {
            logger.warning("CommonDir not found for tag: \(sender.tag)")
            return
        }

        logger.info("CommonDir clicked: \(commonDir.name) (id: \(commonDir.id))")

        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        let itemPaths = selectedItems.map { $0.path }

        let event = ClickEventPayload(
            itemId: commonDir.id,
            itemType: .commonDir,
            target: itemPaths,
            trigger: getTriggerForMenuKind()
        )
        messager.sendClickEvent(event)
    }

    // MARK: - Helper Methods

    /// 获取触发来源
    private func getTriggerForMenuKind() -> MenuTrigger {
        // 根据菜单类型判断触发来源
        // 这里简化处理，默认使用 contextualItems
        return .contextualItems
    }
}

// MARK: - NSMenu Extension

extension NSMenu {
    /// 添加菜单分组标题（带分隔符）
    func addSection(_ title: String) {
        let header = NSMenuItem.separator()
        self.addItem(header)

        let sectionHeader = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        sectionHeader.isEnabled = false
        self.addItem(sectionHeader)
    }

    /// 添加菜单分组标题（无分隔符，仅标题）
    func addSectionHeader(_ title: String) {
        let sectionHeader = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        sectionHeader.isEnabled = false
        self.addItem(sectionHeader)
    }
}

