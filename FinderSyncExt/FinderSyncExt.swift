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
    subsystem: "RClick.FinderSyncExt",
    category: "FinderSyncExt"
)

// MARK: - FinderSync Extension

/// FinderSync Extension - 瘦 Extension 架构
/// 只负责菜单渲染和事件转发，不读取 SwiftData
class FinderSyncExt: FIFinderSync, @unchecked Sendable {

    // MARK: - Properties

    /// 菜单配置缓存（内存缓存，从 Main App 推送）
    private var cachedMenuConfig: MenuConfigPayload?

    /// 图标内存缓存，避免每次构建菜单都重新创建 NSImage
    private var iconCache: [String: NSImage] = [:]

    /// 文件类型图标提供者
    private let iconProvider = FileTypeIconProvider.shared

    /// 无效/旧版图标名 → SF Symbol 映射
    private let iconFallbackMap: [String: String] = [
        "icon-file-json": "curlybraces",
        "icon-file-txt": "doc.text",
        "icon-file-md": "doc.richtext",
        "icon-file-docx": "doc.richtext.fill",
        "icon-file-pptx": "rectangle.on.rectangle.fill",
        "icon-file-xlsx": "tablecells",
        "document": "doc",
        "apps.iphone.badge.checkmark": "square.grid.2x2",
    ]

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
        iconCache.removeAll()
        logger.debug("Menu config cached: version=\(config.version), actions=\(config.actions.count), apps=\(config.apps.count), icons cleared")
    }

    /// 请求菜单配置
    private func requestMenuConfig() {
        logger.info("Requesting menu config from main app")
        messager.requestMenuConfig()
    }

    // MARK: - Heartbeat

    /// 启动心跳机制（每 10 秒发送一次）
    private func startHeartbeat() {
        scheduleHeartbeat()
    }

    /// 调度下一次心跳
    private func scheduleHeartbeat() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { @MainActor [weak self] in
            self?.messager.sendHeartbeat()
            self?.scheduleHeartbeat()
        }
    }

    // MARK: - Primary Finder Sync protocol methods

    override func beginObservingDirectory(at url: URL) {
        logger.debug("beginObservingDirectoryAtURL: \(url.path)")
    }

    override func endObservingDirectory(at url: URL) {
        logger.debug("endObservingDirectoryAtURL: \(url.path)")
    }

    override func requestBadgeIdentifier(for url: URL) {
        logger.debug("requestBadgeIdentifierForURL: \(url.path)")

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
        let image = NSImage(named: "toolbar") ?? NSImage()
        image.isTemplate = true
        return image
    }

    /// 当前菜单触发类型（工具栏 or 右键）
    private var currentMenuKind: FIMenuKind = .contextualMenuForItems

    // MARK: - Icon Helpers

    /// 获取 App 图标（带缓存）
    private func cachedAppIcon(app: AppMenuItem) -> NSImage? {
        if let appURL = app.appURL {
            let cacheKey = "app:\(appURL)"
            if let cached = iconCache[cacheKey] { return cached }
            let icon: NSImage = DispatchQueue.main.sync {
                NSWorkspace.shared.icon(forFile: appURL)
            }
            if icon.size.width > 0 {
                iconCache[cacheKey] = icon
                return icon
            }
        }
        if let icon = NSImage(named: app.icon) { return icon }
        return templateSymbol(app.icon)
    }

    /// 加载 SF Symbol 并使用 hierarchicalColor 适配亮色/暗色模式（带缓存）
    private func templateSymbol(_ name: String) -> NSImage? {
        let cacheKey = "sf:\(name)"
        if let cached = iconCache[cacheKey] { return cached }
        let config = NSImage.SymbolConfiguration(hierarchicalColor: .labelColor)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }
        iconCache[cacheKey] = image
        return image
    }

    /// 从 Assets 或 SF Symbol 加载图标（带缓存）
    private func loadIcon(named iconName: String, accessibilityDescription description: String) -> NSImage? {
        let cacheKey = "load:\(iconName)"
        if let cached = iconCache[cacheKey] { return cached }
        if let icon = NSImage(named: iconName) {
            iconCache[cacheKey] = icon
            return icon
        }
        if let icon = templateSymbol(iconName) {
            iconCache[cacheKey] = icon
            return icon
        }
        if let fallback = iconFallbackMap[iconName],
           let icon = templateSymbol(fallback) {
            iconCache[cacheKey] = icon
            return icon
        }
        return nil
    }

    /// 构建并返回 Finder 上下文菜单
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        currentMenuKind = menuKind
        let menuKindLabel: String = {
            switch menuKind {
            case .contextualMenuForItems: return "右键菜单(选中项)"
            case .contextualMenuForContainer: return "右键菜单(空白处)"
            case .contextualMenuForSidebar: return "右键菜单(侧边栏)"
            case .toolbarItemMenu: return "工具栏按钮"
            default: return "其他(\(menuKind.rawValue))"
            }
        }()
        logger.info("构建菜单，触发方式: \(menuKindLabel)")

        let menu = NSMenu(title: "RClick")

        // 如果缓存为空，触发请求并返回加载中的菜单
        guard let config = cachedMenuConfig else {
            requestMenuConfig()
            menu.addItem(withTitle: String(localized: "RClick (loading...)"), action: nil, keyEquivalent: "")
            return menu
        }

        // 构建动作菜单
        if !config.actions.isEmpty {
            if config.actionsCollapsed {
                // 折叠：使用子菜单
                let actionsSubMenu = NSMenu(title: "操作")
                for action in config.actions {
                    let item = NSMenuItem(title: action.name, action: #selector(handleActionClick(_:)), keyEquivalent: "")
                    item.tag = hashForAction(action)
                    item.target = self
                    if let icon = templateSymbol(action.icon) {
                        item.image = icon
                    }
                    actionsSubMenu.addItem(item)
                }
                let actionsItem = NSMenuItem(title: "操作", action: nil, keyEquivalent: "")
                actionsItem.submenu = actionsSubMenu
                menu.addItem(actionsItem)
            } else {
                // 不折叠：直接显示菜单项
                for action in config.actions {
                    let item = NSMenuItem(title: action.name, action: #selector(handleActionClick(_:)), keyEquivalent: "")
                    item.tag = hashForAction(action)
                    item.target = self
                    if let icon = templateSymbol(action.icon) {
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
                let appsSubMenu = NSMenu(title: "打开方式")
                for app in config.apps {
                    let item = NSMenuItem(title: app.name, action: #selector(handleAppClick(_:)), keyEquivalent: "")
                    item.tag = hashForApp(app)
                    item.target = self
                    item.image = cachedAppIcon(app: app)
                    appsSubMenu.addItem(item)
                }
                let appsItem = NSMenuItem(title: "打开方式", action: nil, keyEquivalent: "")
                appsItem.submenu = appsSubMenu
                menu.addItem(appsItem)
            } else {
                // 不折叠：直接显示菜单项
                for app in config.apps {
                    let item = NSMenuItem(title: app.name, action: #selector(handleAppClick(_:)), keyEquivalent: "")
                    item.tag = hashForApp(app)
                    item.target = self
                    item.image = cachedAppIcon(app: app)
                    menu.addItem(item)
                }
            }
        }

        // 构建新建文件菜单
        if !config.newFiles.isEmpty {
            if config.newFilesCollapsed {
                // 折叠：使用子菜单
                let newFilesSubMenu = NSMenu(title: "新建文件")
                for newFile in config.newFiles {
                    let item = NSMenuItem(title: newFile.name, action: #selector(handleNewFileClick(_:)), keyEquivalent: "")
                    item.tag = hashForNewFile(newFile)
                    item.target = self
                    item.image = iconProvider.icon(for: newFile.ext, fallbackSymbol: newFile.icon)
                    item.image?.accessibilityDescription = newFile.name
                    newFilesSubMenu.addItem(item)
                }
                let newFilesItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
                newFilesItem.submenu = newFilesSubMenu
                newFilesItem.image = templateSymbol("doc.badge.plus")
                menu.addItem(newFilesItem)
            } else {
                // 不折叠：直接显示菜单项
                for newFile in config.newFiles {
                    let item = NSMenuItem(title: newFile.name, action: #selector(handleNewFileClick(_:)), keyEquivalent: "")
                    item.tag = hashForNewFile(newFile)
                    item.target = self
                    item.image = iconProvider.icon(for: newFile.ext, fallbackSymbol: newFile.icon)
                    item.image?.accessibilityDescription = newFile.name
                    menu.addItem(item)
                }
            }
        }

        // 构建常用目录菜单
        if !config.commonDirs.isEmpty {
            if config.commonDirsCollapsed {
                // 折叠：使用子菜单
                let commonDirsSubMenu = NSMenu(title: "常用文件夹")
                for commonDir in config.commonDirs {
                    let item = NSMenuItem(title: commonDir.name, action: #selector(handleCommonDirClick(_:)), keyEquivalent: "")
                    item.tag = hashForCommonDir(commonDir)
                    item.target = self
                    item.image = loadIcon(named: commonDir.icon, accessibilityDescription: commonDir.name)
                    commonDirsSubMenu.addItem(item)
                }
                let commonDirsItem = NSMenuItem(title: "常用文件夹", action: nil, keyEquivalent: "")
                commonDirsItem.submenu = commonDirsSubMenu
                commonDirsItem.image = templateSymbol("folder")
                menu.addItem(commonDirsItem)
            } else {
                // 不折叠：直接显示菜单项
                for commonDir in config.commonDirs {
                    let item = NSMenuItem(title: commonDir.name, action: #selector(handleCommonDirClick(_:)), keyEquivalent: "")
                    item.tag = hashForCommonDir(commonDir)
                    item.target = self
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

        logger.debug("Action clicked: \(action.name) (id: \(action.id))")

        // 获取选中的文件/目录
        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        let itemPaths = selectedItems.map { $0.path }
        logger.info("[Action] selectedItemURLs 返回 \(selectedItems.count) 个文件: \(itemPaths)")

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
        logger.debug("handleAppClick called with sender: \(sender.title), tag: \(sender.tag)")

        guard let config = cachedMenuConfig,
              let app = config.apps.first(where: { hashForApp($0) == sender.tag }) else {
            logger.warning("App not found for tag: \(sender.tag)")
            return
        }

        logger.debug("App clicked: \(app.name) (id: \(app.id))")

        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        let itemPaths = selectedItems.map { $0.path }
        logger.info("[App] selectedItemURLs 返回 \(selectedItems.count) 个文件: \(itemPaths)")

        let event = ClickEventPayload(
            itemId: app.id,
            itemType: .app,
            target: itemPaths,
            trigger: getTriggerForMenuKind()
        )
        logger.debug("Sending click event for app: \(app.name)")
        messager.sendClickEvent(event)
    }

    @objc private func handleNewFileClick(_ sender: NSMenuItem) {
        guard let config = cachedMenuConfig,
              let newFile = config.newFiles.first(where: { hashForNewFile($0) == sender.tag }) else {
            logger.warning("NewFile not found for tag: \(sender.tag)")
            return
        }

        logger.debug("NewFile clicked: \(newFile.name) (id: \(newFile.id))")

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

        logger.debug("CommonDir clicked: \(commonDir.name) (id: \(commonDir.id))")

        // 使用常用目录自身的路径，而不是 Finder 当前选中的路径
        let target = commonDir.url.map { [$0] } ?? []

        let event = ClickEventPayload(
            itemId: commonDir.id,
            itemType: .commonDir,
            target: target,
            trigger: getTriggerForMenuKind()
        )
        messager.sendClickEvent(event)
    }

    // MARK: - Helper Methods

    /// 获取触发来源
    private func getTriggerForMenuKind() -> MenuTrigger {
        switch currentMenuKind {
        case .toolbarItemMenu:
            return .toolbar
        case .contextualMenuForItems:
            return .contextualItems
        case .contextualMenuForContainer:
            return .contextualContainer
        case .contextualMenuForSidebar:
            return .contextualSidebar
        default:
            return .contextualItems
        }
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

