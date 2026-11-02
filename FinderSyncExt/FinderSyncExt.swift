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
    private var mainActivity = PeerActivity()

    /// 是否认为主程序可通信（连续 3 次心跳未收到即判离线）
    private var isHostAppRunning: Bool {
        mainActivity.isActive()
    }

    /// 待确认的点击事件 ack 计时器
    private var pendingAckWorkItem: DispatchWorkItem?

    // MARK: - Option 键状态

    /// 菜单构建时是否按住 Option。Finder 负责显示菜单，点击回调可能晚于
    /// 用户松开按键，所以除了回调时的实时检测，还要记住菜单打开那一刻的状态。
    private var menuOptionPressed = false

    /// 菜单打开期间最近一次观察到 Option 按下的时间
    private var optionSeenAt: Date?

    /// 菜单打开期间轮询修饰键的计时器（沙盒下 NSEvent/CGEventSource 均可用）
    private var optionPollTimer: Timer?

    private static let optionRecentWindow: TimeInterval = 1.0

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
    ///
    /// This is also what makes Finder redraw those volumes' sidebar icons with
    /// RClick's app icon (#158) — a trade-off, not an oversight: a sandboxed
    /// extension cannot read a volume root (`/Volumes` is readable, `/Volumes/<a
    /// volume>` is not), so it cannot discover the volume's contents to observe
    /// anything narrower. See specs/external-volumes-observation.md.
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
            // 使用 decodeSignedData 解码签名数据
            if let config = self.messager.decodeSignedData(data, as: MenuConfigPayload.self) {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    _ = self.mainActivity.receive()
                    self.handleMenuConfig(config)
                }
            } else {
                logger.warning("Invalid menu config data")
            }
        }

        // 处理主程序发送的 running 通知
        messager.onMainMessage(.running) { [weak self] data in
            guard let self = self else { return }
            if let payload = self.messager.decodeSignedData(data, as: RunningPayload.self) {
                self.markMainActivity()
                logger.debug("Received running notification: \(payload.directories)")
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
            _ = self?.mainActivity.receive()
        }
    }

    /// 标记主程序离线（收到 .quit 时立即生效）
    private func markMainOffline() {
        DispatchQueue.main.async { [weak self] in
            self?.mainActivity.disconnect()
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
    ///
    /// 注意：不要在这里清 iconCache。缓存键是图标名 / App 路径 / SF Symbol 名，
    /// 配置内容不变就不会脏。此前每次收到配置都 removeAll，而主程序曾每 10 秒随
    /// 心跳推送一次配置，下一次右键就得在 Finder 主线程同步重建全部 App 图标
    /// （NSWorkspace.icon(forFile:) 是磁盘查询），菜单弹出明显卡顿。
    private func handleMenuConfig(_ config: MenuConfigPayload) {
        let apps = config.apps
        DispatchQueue.global(qos: .utility).async {
            AppPresets.prewarm(forAppPaths: apps.compactMap { $0.appURL })
            DispatchQueue.main.async {
                for app in apps { _ = AppPresets.simpleIcon(forAppPath: app.appURL) }
            }
        }
        cachedMenuConfig = config
        preloadIcons(for: config)
        logger.debug("Menu config cached: version=\(config.version), actions=\(config.actions.count), apps=\(config.apps.count)")
    }

    /// 后台预热图标缓存
    ///
    /// 图标缓存是懒加载的：扩展每次重启后（重装、系统重启、Finder 回收进程）
    /// 首次构建菜单都要在 Finder 主线程同步执行 NSWorkspace.icon(forFile:)——
    /// LaunchServices 磁盘查询，每个 App 项几十毫秒，第一次右键明显偏慢。
    /// 这里在配置到达/更新时于后台把 App 图标先加载好，再一次性合并回缓存。
    ///
    /// 线程安全：iconCache 只在主线程读写，后台先把结果装进局部字典，回主线程
    /// 合并，无数据竞争。NSWorkspace.icon(forFile:) 官方文档标注为线程安全。
    private func preloadIcons(for config: MenuConfigPayload) {
        let apps = config.apps
        let newFiles = config.newFiles
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var warmed: [String: NSImage] = [:]
            for app in apps {
                guard let url = app.appURL else { continue }
                let key = "app:\(url)"
                let icon = NSWorkspace.shared.icon(forFile: url)
                if icon.size.width > 0 { warmed[key] = icon }
            }
            // 新建文件图标：iconProvider 首次构建会同步查询 NSWorkspace（实测首次 30-40ms），
            // 同样在后台预热，主线程只做合并
            let warmedFiles = newFiles.isEmpty
                ? [:]
                : FileTypeIconProvider.shared.computeWorkspaceIcons(forExts: newFiles.map { $0.ext })
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for (key, icon) in warmed where self.iconCache[key] == nil {
                    self.iconCache[key] = icon
                }
                FileTypeIconProvider.shared.mergeWarmedIcons(warmedFiles)
                logger.debug("图标预热完成: app \(warmed.count) 项, file \(warmedFiles.count) 项")
            }
        }
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

    /// Finder 会为观察范围内的每个项目回调这里，问它该显示什么徽章。
    ///
    /// RClick 不使用徽章，所以留空：扩展包里没有任何 badge 图（FinderSync 只认
    /// Resources 下的 `<id>.png` 散文件，不认 asset catalog），没有可设的标识。
    ///
    /// ⚠️ 这两行**不是**"外置盘图标变成 RClick 图标"的修复。#155 那个现象在这里
    /// 被误判过两次：25b69e8 把随机标识改成空串，b697cc3 改成干脆不调用 —— 两次
    /// 都没有解决，第二次还实测过"不调用时图标照旧"。真正的原因在观察根：Finder
    /// 会把扩展的图标画到每个**被当作根观察**的文件夹上，扩展则把每个卷根放进了
    /// `directoryURLs`，于是这些卷的侧边栏图标被重画（见 setupObservingDirectories）。
    /// 换成像"只观察卷内一级子目录"这种绕法行不通：沙盒下扩展读不到卷根。
    /// 别再往 badge 上找了。
    override func requestBadgeIdentifier(for url: URL) {
        // 故意留空，见上。
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

    /// 快链路动作 id：主程序离线时仍可在扩展内完成的操作
    private static let copyPathActionId = "copy-path"

    /// 「直接删除」动作 id：按住 Option 时跳过二次确认
    private static let deleteDirectActionId = "delete-direct"

    // MARK: - Icon Helpers

    /// 获取 App 图标（带缓存）
    private func cachedAppIcon(app: AppMenuItem) -> NSImage? {
        let style = cachedMenuConfig.flatMap { RCAppIconStyle(rawValue: $0.iconStyle) } ?? .original
        switch style {
        case .none: return nil
        case .simple: return AppPresets.simpleIcon(forAppPath: app.appURL) ?? cachedOriginalAppIcon(app: app)
        case .original: return cachedOriginalAppIcon(app: app)
        }
    }

    private func cachedOriginalAppIcon(app: AppMenuItem) -> NSImage? {
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

    /// 加载 SF Symbol，缓存按名称、尺寸与外观区分。
    private func templateSymbol(_ name: String) -> NSImage? {
        MenuSymbolIcon.image(named: name)
    }

    /// 从 Assets 或 SF Symbol 加载图标（带缓存）
    private func loadIcon(named iconName: String, accessibilityDescription description: String) -> NSImage? {
        let cacheKey = "load:\(iconName)"
        if let cached = iconCache[cacheKey] { return cached }
        if let icon = NSImage(named: iconName) {
            // Assets 位图不受系统外观影响，可以缓存
            iconCache[cacheKey] = icon
            return icon
        }
        // SF Symbol 兜底：MenuSymbolIcon 使用外观感知缓存。
        if let icon = templateSymbol(iconName) { return icon }
        if let fallback = iconFallbackMap[iconName] {
            return templateSymbol(fallback)
        }
        return nil
    }

    /// 构建并返回 Finder 上下文菜单
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let start = DispatchTime.now()
        let menu = buildMenu(for: menuKind)
        let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        logger.info("菜单构建耗时: \(ms, format: .fixed(precision: 1), privacy: .public)ms")
        return menu
    }

    private func buildMenu(for menuKind: FIMenuKind) -> NSMenu {
        currentMenuKind = menuKind

        // 菜单会被 Finder 复制并在 Finder 进程里跟踪，扩展拿不到点击事件。
        // 这里记下菜单打开瞬间的 Option 状态，并持续采样，覆盖用户"先开菜单、
        // 再按 Option、立即点击"的操作顺序（点击回调可能晚于松开按键）。
        menuOptionPressed = isOptionKeyPressed()
        optionSeenAt = menuOptionPressed ? Date() : nil
        startOptionPolling()
        logger.info("菜单打开时 Option 状态: \(self.menuOptionPressed) [\(self.optionKeySnapshot(), privacy: .public)]")
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
        // 关闭自动校验：FIFinderSync 的菜单跨进程交给 Finder 显示，跟踪循环在 Finder
        // 进程里执行，扩展侧的 validateMenuItem 不会被回调——启用状态必须在构建时
        // （menu(for:) 调用时刻）通过显式 isEnabled 定死。
        menu.autoenablesItems = false

        // 主程序离线时快链路项（复制路径）照常可用，其余项由 make*Item 置灰，
        // 菜单尾部追加说明。
        let offline = !isHostAppRunning

        // 如果缓存为空，触发请求并返回加载中的菜单
        guard let config = cachedMenuConfig else {
            if offline {
                appendOfflineHint(menu, offline: true)
            } else {
                requestMenuConfig()
                menu.addItem(withTitle: AppLocalization.localized("RClick (loading...)"), action: nil, keyEquivalent: "")
            }
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

        // Apply the same per-app visibility to default and custom layouts.
        let visibleApps = config.apps.filter { $0.isVisible(for: getTriggerForMenuKind()) }
        if !visibleApps.isEmpty {
            if config.appsCollapsed {
                // 折叠：使用子菜单
                let appsTitle = AppLocalization.localized("Open With")
                let appsSubMenu = NSMenu(title: appsTitle)
                for app in visibleApps {
                    let item = makeAppItem(app)
                    appsSubMenu.addItem(item)
                }
                let appsItem = NSMenuItem(title: appsTitle, action: nil, keyEquivalent: "")
                appsItem.submenu = appsSubMenu
                appsItem.image = templateSymbol("square.and.arrow.up.on.square")
                menu.addItem(appsItem)
            } else {
                // 不折叠：直接显示菜单项
                for app in visibleApps {
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

        appendOfflineHint(menu, offline: offline)
        return menu
    }

    /// 主程序离线时在菜单尾部追加持灰说明（快链路项不受影响，仍可点击）。
    /// 两行提示均可点击：启动主程序（仅菜单栏常驻，不弹设置窗口）。
    private func appendOfflineHint(_ menu: NSMenu, offline: Bool) {
        guard offline else { return }
        menu.addItem(NSMenuItem.separator())
        let gray = [NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor]
        let titles = [
            AppLocalization.localized("RClick is not running"),
            AppLocalization.localized("Restart RClick to restore the menu"),
        ]
        for title in titles {
            let item = menu.addItem(withTitle: "", action: #selector(handleLaunchHostClick(_:)), keyEquivalent: "")
            item.attributedTitle = NSAttributedString(string: title, attributes: gray)
            item.target = self
        }
    }

    /// 点击离线提示：启动主程序。不带任何文档 URL，纯启动不受 TCC 文件弹窗限制；
    /// activates = false 不抢焦点。主程序对这种启动保持静默（不打开设置窗口），
    /// 识别信号见 HintClickLaunch。
    @objc private func handleLaunchHostClick(_ sender: NSMenuItem) {
        let hostURL = Bundle.main.bundleURL
            .deletingLastPathComponent()   // PlugIns/
            .deletingLastPathComponent()   // Contents/
            .deletingLastPathComponent()   // RClick.app
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        // RC_QUIET_LAUNCH=1 只在「本次真的拉起新进程」时送达主程序；App 已在运行
        // （刚点过退出还没退完、或启动后菜单尚未刷新）时系统会忽略环境变量、只
        // 派发 reopen——所以同时写一个时间戳，主程序在两条路径上都能识别提示点击
        config.environment = ["RC_QUIET_LAUNCH": "1"]
        HintClickLaunch.mark()
        NSWorkspace.shared.openApplication(at: hostURL, configuration: config) { _, error in
            if let error {
                logger.warning("Launch host app failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func makeActionItem(_ action: ActionMenuItem) -> NSMenuItem {
        // 菜单打开时按住了 Option：直接改标题告诉用户本次会跳过确认。
        // Finder 只复制 title/action/tag 等有限属性，标题是最可靠的提示通道。
        let title: String
        if menuOptionPressed, action.id == Self.deleteDirectActionId {
            title = String(format: AppLocalization.localized("%@ (skip confirmation)"), action.name)
        } else {
            title = action.name
        }
        let item = NSMenuItem(title: title, action: #selector(handleActionClick(_:)), keyEquivalent: "")
        item.tag = hashForAction(action)
        item.target = self
        if let icon = templateSymbol(action.icon) {
            item.image = icon
        }
        // 主程序离线时只有复制路径是快链路，其余动作需要主程序的授权与执行，置灰
        if !isHostAppRunning && action.id != Self.copyPathActionId {
            item.isEnabled = false
        }
        return item
    }

    private func makeAppItem(_ app: AppMenuItem) -> NSMenuItem {
        let item = NSMenuItem(title: app.name, action: #selector(handleAppClick(_:)), keyEquivalent: "")
        item.tag = hashForApp(app)
        item.target = self
        item.image = cachedAppIcon(app: app)
        // 沙盒限制：扩展内 NSWorkspace.open 传递文件 URL 必触发 TCC 弹窗，
        // 离线快开不可行，维持与主程序一致的离线置灰
        if !isHostAppRunning {
            item.isEnabled = false
        }
        return item
    }

    private func makeNewFileItem(_ newFile: NewFileMenuItem) -> NSMenuItem {
        let item = NSMenuItem(title: newFile.name, action: #selector(handleNewFileClick(_:)), keyEquivalent: "")
        item.tag = hashForNewFile(newFile)
        item.target = self
        item.image = iconProvider.icon(for: newFile.ext, fallbackSymbol: newFile.icon)
        item.image?.accessibilityDescription = newFile.name
        // 新建文件需要往目标目录写入，必须由主程序执行，离线置灰
        if !isHostAppRunning {
            item.isEnabled = false
        }
        return item
    }

    private func makeCommonDirItem(_ commonDir: CommonDirMenuItem) -> NSMenuItem {
        let item = NSMenuItem(title: commonDir.name, action: #selector(handleCommonDirClick(_:)), keyEquivalent: "")
        item.tag = hashForCommonDir(commonDir)
        item.target = self
        item.image = loadIcon(named: commonDir.icon, accessibilityDescription: commonDir.name)
        // 打开目录需要主程序执行，离线置灰
        if !isHostAppRunning {
            item.isEnabled = false
        }
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
        stopOptionPolling()

        // 获取选中的文件/目录
        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        let itemPaths = selectedItems.map { $0.path }
        logger.info("[Action] selectedItemURLs 返回 \(selectedItems.count) 个文件: \(itemPaths)")

        // 快链路：复制路径是纯剪贴板操作，扩展内直接完成（零 IPC）
        if action.id == Self.copyPathActionId {
            copyPathsLocally(itemPaths)
            return
        }

        // 慢链路：删除/隐藏/取消隐藏/AirDrop 需要主程序的 bookmark 授权与执行
        // 发送点击事件到主程序。Finder 的点击回调可能晚于用户松开 Option，
        // 所以把三个来源合并：菜单打开时的状态、菜单期间轮询到的状态、点击瞬间的状态。
        let optionPressed = resolvedOptionState()
        logger.info("Action click option pressed: \(optionPressed) [\(self.optionKeySnapshot(), privacy: .public)]")
        let event = ClickEventPayload(
            itemId: action.id,
            itemType: .action,
            target: itemPaths,
            trigger: getTriggerForMenuKind(),
            optionKeyPressed: optionPressed
        )
        sendClickEvent(event)
    }

    /// 快链路：复制路径（与主程序 ActionService.copyPath 语义一致，取第一项）
    private func copyPathsLocally(_ itemPaths: [String]) {
        guard let first = itemPaths.first else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(first.removingPercentEncoding ?? first, forType: .string)
    }

    @objc private func handleAppClick(_ sender: NSMenuItem) {
        stopOptionPolling()
        logger.debug("handleAppClick called with sender: \(sender.title), tag: \(sender.tag)")

        guard let config = cachedMenuConfig,
              let app = config.apps.first(where: { hashForApp($0) == sender.tag }) else {
            logger.warning("App not found for tag: \(sender.tag)")
            return
        }

        logger.debug("App clicked: \(app.name) (id: \(app.id))")

        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        var itemPaths = selectedItems.map { $0.path }
        logger.info("[App] selectedItemURLs 返回 \(selectedItems.count) 个文件: \(itemPaths)")

        // 工具栏触发没有选中项：用当前 Finder 窗口目录作为打开目标
        if itemPaths.isEmpty, let targetURL = FIFinderSyncController.default().targetedURL() {
            itemPaths = [targetURL.path]
        }

        // 打开动作统一由主程序处理 bookmark 授权与失败重试。
        // 主程序离线时，makeAppItem 会将应用菜单项置灰。
        let event = ClickEventPayload(
            itemId: app.id,
            itemType: .app,
            target: itemPaths,
            trigger: getTriggerForMenuKind()
        )
        sendClickEvent(event)
    }

    @objc private func handleNewFileClick(_ sender: NSMenuItem) {
        stopOptionPolling()
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
        stopOptionPolling()
        guard let config = cachedMenuConfig,
              let commonDir = config.commonDirs.first(where: { hashForCommonDir($0) == sender.tag }) else {
            logger.warning("CommonDir not found for tag: \(sender.tag)")
            return
        }

        logger.debug("CommonDir clicked: \(commonDir.name) (id: \(commonDir.id))")

        // 打开目录统一交给主程序，由 ActionService 检查 bookmark 权限，
        // 必要时请求用户授权；扩展只转发目标路径。
        let event = ClickEventPayload(
            itemId: commonDir.id,
            itemType: .commonDir,
            target: commonDir.url.map { [$0] } ?? [],
            trigger: getTriggerForMenuKind()
        )
        sendClickEvent(event)
    }

    // MARK: - Helper Methods

    /// 综合判断本次点击是否应视为"按住 Option"。
    ///
    /// 用户可能在菜单打开后才按下 Option，也可能点完立刻松开；而 Finder 的
    /// 回调到达扩展时按键状态可能已经消失。三者取并集可以覆盖这几种时序。
    private func resolvedOptionState() -> Bool {
        if isOptionKeyPressed() { return true }
        if menuOptionPressed { return true }
        if let seen = optionSeenAt, Date().timeIntervalSince(seen) <= Self.optionRecentWindow {
            return true
        }
        return false
    }

    /// 菜单打开期间持续采样修饰键状态。点击回调通常只有几十毫秒的延迟，
    /// 1 秒的窗口足以覆盖"按住 Option → 点击 → 立即松开"。
    private func startOptionPolling() {
        stopOptionPolling()
        let timer = Timer(timeInterval: 0.1, target: self, selector: #selector(pollOptionKey), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        optionPollTimer = timer
        // 用户打开菜单但什么都不点时也要回收计时器。只回收自己这一轮，
        // 避免旧菜单的超时回调误停掉新菜单的计时器。
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self, weak timer] in
            guard let self, let timer, self.optionPollTimer === timer else { return }
            self.stopOptionPolling()
        }
    }

    private func stopOptionPolling() {
        optionPollTimer?.invalidate()
        optionPollTimer = nil
    }

    @objc private func pollOptionKey() {
        if isOptionKeyPressed() {
            optionSeenAt = Date()
        }
    }

    /// 当前是否按住 Option。
    ///
    /// 扩展进程里通常没有自己的 `NSEvent`，所以除了 `NSEvent.modifierFlags`
    /// 还要查窗口服务器的修饰键状态；沙盒下这两条读取通道都可用。
    private func isOptionKeyPressed() -> Bool {
        if NSEvent.modifierFlags.contains(.option) { return true }
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.option) { return true }
        if CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate) { return true }
        if CGEventSource.flagsState(.hidSystemState).contains(.maskAlternate) { return true }
        return false
    }

    /// 供诊断日志使用：各来源分别看到什么。
    private func optionKeySnapshot() -> String {
        let combined = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)
        let hid = CGEventSource.flagsState(.hidSystemState).contains(.maskAlternate)
        let current = NSApp.currentEvent?.modifierFlags.contains(.option)
        return "NSEvent=\(NSEvent.modifierFlags.contains(.option)) current=\(current.map(String.init) ?? "nil") combined=\(combined) hid=\(hid)"
    }

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
