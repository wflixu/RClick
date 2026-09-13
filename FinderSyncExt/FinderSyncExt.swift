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

    private var volumeObserver: MountedVolumeObserver?

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

    // MARK: - 连接状态（UX 优化，非可靠性机制）

    /// 最近一次收到主程序消息的时间
    private var lastMainActivity = Date()

    /// 是否认为主程序可通信（连续 3 次心跳未收到即判离线）
    private var isHostAppRunning: Bool {
        Date().timeIntervalSince(lastMainActivity) < 30
    }

    /// 待确认的点击事件 ack 计时器
    private var pendingAckWorkItem: DispatchWorkItem?

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

    /// Register each mounted volume explicitly; filesystem ancestry alone is not
    /// a reliable observation boundary for Finder Sync across mount points.
    private func setupObservingDirectories() {
        // Finder Sync requires an initial set during extension startup.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        Task { @MainActor [weak self] in
            self?.volumeObserver = MountedVolumeObserver { directories in
                FIFinderSyncController.default().directoryURLs = directories
                logger.info("Observing \(directories.count) filesystem roots")
            }
        }
    }

    // MARK: - Message Handling

    /// 注册消息处理器
    private func setupMessageHandlers() {
        // 处理主程序发送的菜单配置
        messager.onMainMessage(.menuConfig) { [weak self] data in
            guard let self = self else { return }
            self.markMainActivity()
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
            self.markMainActivity()
            if let payload = self.messager.decodeSignedData(data, as: RunningPayload.self) {
                logger.info("Received running notification: \(payload.directories)")
                // 可以根据 payload 更新监听目录
            }
        }

        // 处理主程序发送的退出通知：立即置离线，消除"退出后 30s 假活"窗口
        messager.onMainMessage(.quit) { [weak self] _ in
            logger.info("Received quit notification from main app")
            self?.markMainOffline()
        }

        // 点击事件确认：主程序已收到 click，取消 ack 超时提示
        messager.onMainMessage(.actionAck) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleAck()
            }
        }
    }

    // MARK: - 连接状态辅助

    /// 记录主程序最近活动（统一到主线程，避免 DNC 回调线程写 / menu 主线程读竞争）
    private func markMainActivity() {
        DispatchQueue.main.async { [weak self] in
            self?.lastMainActivity = Date()
        }
    }

    /// 标记主程序离线（收到 .quit 时立即生效）
    private func markMainOffline() {
        DispatchQueue.main.async { [weak self] in
            self?.lastMainActivity = .distantPast
        }
    }

    /// 发送点击事件：离线先提示；在线则等待 ack，超时无响应再提示
    private func sendClickEvent(_ event: ClickEventPayload) {
        guard isHostAppRunning else {
            Task { @MainActor in
                self.showAlert(
                    title: AppLocalization.localized("RClick is not running"),
                    message: AppLocalization.localized("This action requires RClick to be running. Please launch RClick and try again.")
                )
            }
            return
        }
        messager.sendClickEvent(event)
        awaitAck()
    }

    /// 启动 ack 等待：主程序收到 click 后回 actionAck，超时未收到则提示操作可能未执行
    private func awaitAck() {
        pendingAckWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.showAlert(
                    title: AppLocalization.localized("RClick did not respond"),
                    message: AppLocalization.localized("The operation may not have been executed. Please check that RClick is running.")
                )
            }
        }
        pendingAckWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    /// 收到 ack，取消超时提示
    private func handleAck() {
        pendingAckWorkItem?.cancel()
        pendingAckWorkItem = nil
    }

    @MainActor private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: AppLocalization.localized("OK"))
        alert.runModal()
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
        // 不设置任何徽章标识，避免 Finder 在项目上叠加 RClick 图标。
        // 非空徽章 ID 会使 Finder 在文件/磁盘图标上显示扩展的图标叠加层，
        // 这会导致移动磁盘和光盘等外部卷的图标被 RClick 图标覆盖。
        FIFinderSyncController.default().setBadgeIdentifier("", for: url)
    }

    // MARK: - Menu and toolbar item support

    override var toolbarItemName: String {
        return "RClick"
    }

    override var toolbarItemToolTip: String {
        return AppLocalization.localized("RClick: Click for menu options")
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
            let icon: NSImage
            if Thread.isMainThread {
                icon = MainActor.assumeIsolated { NSWorkspace.shared.icon(forFile: appURL) }
            } else {
                icon = DispatchQueue.main.sync { NSWorkspace.shared.icon(forFile: appURL) }
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

        // 连接状态缓存：主程序离线时，显示置灰提示而非可点击菜单（避免"点了没反应"）
        guard isHostAppRunning else {
            menu.addItem(withTitle: AppLocalization.localized("RClick is not running"), action: nil, keyEquivalent: "")
            menu.addItem(withTitle: AppLocalization.localized("Restart RClick to restore the menu"), action: nil, keyEquivalent: "")
            return menu
        }

        // 如果缓存为空，触发请求并返回加载中的菜单
        guard let config = cachedMenuConfig else {
            requestMenuConfig()
            menu.addItem(withTitle: AppLocalization.localized("RClick (loading...)"), action: nil, keyEquivalent: "")
            return menu
        }

        if let nodes = config.customMenu {
            CustomMenu.render(nodes, into: menu, makeItem: { type, id in
                switch type {
                case .action: return config.actions.first { $0.id == id }.map(self.makeActionItem)
                case .app: return config.apps.first { $0.id == id }.map(self.makeAppItem)
                case .newFile: return config.newFiles.first { $0.id == id }.map(self.makeNewFileItem)
                case .commonDir: return config.commonDirs.first { $0.id == id }.map(self.makeCommonDirItem)
                }
            }, loadIcon: { self.loadIcon(named: $0, accessibilityDescription: $0) })
            return menu
        }

        // 构建动作菜单
        if !config.actions.isEmpty {
            if config.actionsCollapsed {
                // 折叠：使用子菜单
                let actionsTitle = AppLocalization.localized("Actions")
                let actionsSubMenu = NSMenu(title: actionsTitle)
                for action in config.actions {
                    let item = makeActionItem(action)
                    actionsSubMenu.addItem(item)
                }
                let actionsItem = NSMenuItem(title: actionsTitle, action: nil, keyEquivalent: "")
                actionsItem.submenu = actionsSubMenu
                actionsItem.image = templateSymbol("ellipsis.circle")
                menu.addItem(actionsItem)
            } else {
                // 不折叠：直接显示菜单项
                for action in config.actions {
                    let item = makeActionItem(action)
                    menu.addItem(item)
                }
            }
        }

        // 构建应用菜单
        if !config.apps.isEmpty {
            if config.appsCollapsed {
                // 折叠：使用子菜单
                let appsTitle = AppLocalization.localized("Open With")
                let appsSubMenu = NSMenu(title: appsTitle)
                for app in config.apps {
                    let item = makeAppItem(app)
                    appsSubMenu.addItem(item)
                }
                let appsItem = NSMenuItem(title: appsTitle, action: nil, keyEquivalent: "")
                appsItem.submenu = appsSubMenu
                appsItem.image = templateSymbol("square.and.arrow.up.on.square")
                menu.addItem(appsItem)
            } else {
                // 不折叠：直接显示菜单项
                for app in config.apps {
                    let item = makeAppItem(app)
                    menu.addItem(item)
                }
            }
        }

        // 构建新建文件菜单
        do {
            if config.newFilesCollapsed {
                // 折叠：使用子菜单
                let newFilesTitle = AppLocalization.localized("New File")
                let newFilesSubMenu = NSMenu(title: newFilesTitle)
                for newFile in config.newFiles {
                    let item = makeNewFileItem(newFile)
                    newFilesSubMenu.addItem(item)
                }
                let newFilesItem = NSMenuItem(title: newFilesTitle, action: nil, keyEquivalent: "")
                newFilesItem.submenu = newFilesSubMenu
                newFilesItem.image = templateSymbol("doc.badge.plus")
                menu.addItem(newFilesItem)
            } else {
                // 不折叠：直接显示菜单项
                for newFile in config.newFiles {
                    let item = makeNewFileItem(newFile)
                    menu.addItem(item)
                }
            }
        }

        // 构建常用目录菜单
        if !config.commonDirs.isEmpty {
            if config.commonDirsCollapsed {
                // 折叠：使用子菜单
                let commonDirsTitle = AppLocalization.localized("Common Dirs")
                let commonDirsSubMenu = NSMenu(title: commonDirsTitle)
                for commonDir in config.commonDirs {
                    let item = makeCommonDirItem(commonDir)
                    commonDirsSubMenu.addItem(item)
                }
                let commonDirsItem = NSMenuItem(title: commonDirsTitle, action: nil, keyEquivalent: "")
                commonDirsItem.submenu = commonDirsSubMenu
                commonDirsItem.image = templateSymbol("folder")
                menu.addItem(commonDirsItem)
            } else {
                // 不折叠：直接显示菜单项
                for commonDir in config.commonDirs {
                    let item = makeCommonDirItem(commonDir)
                    menu.addItem(item)
                }
            }
        }

        return menu
    }

    private func makeActionItem(_ action: ActionMenuItem) -> NSMenuItem {
        let item = NSMenuItem(title: action.name, action: #selector(handleActionClick(_:)), keyEquivalent: "")
        item.tag = hashForAction(action)
        item.target = self
        if let icon = templateSymbol(action.icon) {
            item.image = icon
        }
        return item
    }

    private func makeAppItem(_ app: AppMenuItem) -> NSMenuItem {
        let item = NSMenuItem(title: app.name, action: #selector(handleAppClick(_:)), keyEquivalent: "")
        item.tag = hashForApp(app)
        item.target = self
        item.image = cachedAppIcon(app: app)
        return item
    }

    private func makeNewFileItem(_ newFile: NewFileMenuItem) -> NSMenuItem {
        let item = NSMenuItem(title: newFile.name, action: #selector(handleNewFileClick(_:)), keyEquivalent: "")
        item.tag = hashForNewFile(newFile)
        item.target = self
        item.image = iconProvider.icon(for: newFile.ext, fallbackSymbol: newFile.icon)
        item.image?.accessibilityDescription = newFile.name
        return item
    }

    private func makeCommonDirItem(_ commonDir: CommonDirMenuItem) -> NSMenuItem {
        let item = NSMenuItem(title: commonDir.name, action: #selector(handleCommonDirClick(_:)), keyEquivalent: "")
        item.tag = hashForCommonDir(commonDir)
        item.target = self
        item.image = loadIcon(named: commonDir.icon, accessibilityDescription: commonDir.name)
        return item
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
        sendClickEvent(event)
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
        sendClickEvent(event)
    }

    @objc private func handleNewFileClick(_ sender: NSMenuItem) {
        guard let config = cachedMenuConfig,
              let newFile = config.newFiles.first(where: { hashForNewFile($0) == sender.tag }) else {
            logger.warning("NewFile not found for tag: \(sender.tag)")
            return
        }
        let itemId = newFile.id
        logger.debug("NewFile clicked: \(newFile.name) (id: \(newFile.id))")

        let event = ClickEventPayload(
            itemId: itemId,
            itemType: .newFile,
            target: newFileTargetPaths(),
            trigger: getTriggerForMenuKind()
        )
        sendClickEvent(event)
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
        sendClickEvent(event)
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

    private func newFileTargetPaths() -> [String] {
        if currentMenuKind == .contextualMenuForContainer,
           let targetURL = FIFinderSyncController.default().targetedURL() {
            return [targetURL.path]
        }

        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        if !selectedItems.isEmpty {
            return selectedItems.map { $0.path }
        }

        if let targetURL = FIFinderSyncController.default().targetedURL() {
            return [targetURL.path]
        }

        return []
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
