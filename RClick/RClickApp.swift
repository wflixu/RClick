//
//  RClickApp.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//
import AppKit
import ApplicationServices
import Foundation
import SwiftUI
import SwiftData

import FinderSync
import os.log

extension NSNotification.Name {
    static let menuConfigShouldUpdate = NSNotification.Name("RClick.menuConfigShouldUpdate")
    static let openSettingsRequested = NSNotification.Name("RClick.openSettingsRequested")
}

@main
struct RClickApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(Key.showMenuBarExtra, store: .group) private var showMenuBarExtra = true

    @Environment(\.openWindow) var openWindow

    @AppLog(category: "main")
    private var logger
    let messager = Messager.shared

    @StateObject var appState = AppState.shared

    @StateObject private var updateManager = UpdateManager(
        owner: "wflixu",
        repo: "RClick",
        currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    )

    var body: some Scene {
        SettingsWindow(appState: appState, onAppear: {})
            .defaultAppStorage(.group)
            .environmentObject(updateManager)
            .modelContainer(SharedDataManager.sharedModelContainer)

        // showMenuBarExtra 为 true 时显示菜单条。label 必须用自定义视图
        // （MenuBarExtraLabel）：openSettingsRequested 的订阅挂在那里，默认的
        // 字符串+图片标签里没有我们的代码可挂。
        MenuBarExtra(
            isInserted: $showMenuBarExtra
        ) {
            MenuBarView()
        } label: {
            MenuBarExtraLabel()
        }
        .defaultAppStorage(.group)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    @AppLog(category: "AppDelegate")
    private var logger

    /// 惰性求值：`AppState.shared` 会一路构造到 `ModelContext(sharedModelContainer)`，
    /// 所以必须等 `init` 里 `bootstrap()` 成功之后才碰它。写成默认值属性会在 init 体
    /// 之前求值，正好把顺序反过来。
    lazy var appState: AppState = .shared
    private var pluginActivity = PeerActivity()
    var pluginRunning: Bool { pluginActivity.isActive() }
    var heartBeatCount = 0

    let messager = Messager.shared
    var showMenuBarExtra = UserDefaults.group.bool(forKey: Key.showMenuBarExtra)
    var settingsWindow: NSWindow!

    override init() {
        super.init()

        // 先把共享库打开：失败就带着原因退出，而不是等到 AppState 构造时才崩。
        // 这是启动路径上唯一一处主动打开容器的地方，其余访问都指望它先跑过。
        do {
            try SharedDataManager.bootstrap()
        } catch {
            StartupFailure.presentAndExit(error)
        }
    }

    // MARK: - 重连机制状态

    /// 最大重试次数
    private let maxRunningMessageRetryCount: Int = 6

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("applicationDidFinishLaunching called")

        // 设置窗口打开策略。注意 RClick 是 LSUIElement 应用，启动时系统不会
        // 激活它（NSApp.isActive 恒为 false），无法用激活状态区分启动来源，
        // 改用两个显式信号：
        // - 扩展离线提示点击 → OpenConfiguration.environment 带 RC_QUIET_LAUNCH=1，
        //   外加 HintClickLaunch 时间戳（环境变量对已运行的 App 无效，见其注释）
        // - 开机自启 → 系统运行时长 < 3 分钟（实测 SMAppService 登录项与手动
        //   open 的 launchd 标签格式一致，环境变量无法区分，时长是唯一可用信号）
        // 其余（手动 open/双击、崩溃后重启）→ 打开设置窗口
        // App 已运行时再次 open 不会重跑本方法，由 applicationShouldHandleReopen
        // 接住，同样打开设置窗口
        // 时长判定仅在登录项开启时参与：用户没开自启就不存在"开机自启"场景，
        // 开机后手动打开的行为与任何时刻一致
        let processInfo = ProcessInfo.processInfo
        let isHintClickLaunch = processInfo.environment["RC_QUIET_LAUNCH"] == "1" || HintClickLaunch.isRecent()
        let isBootLaunch = LaunchAtLogin.isEnabled && processInfo.systemUptime < 180
        let willOpenSettings = !isHintClickLaunch && !isBootLaunch
        logger.info("launch decision: hintClick=\(isHintClickLaunch, privacy: .public) bootLaunch=\(isBootLaunch, privacy: .public) uptime=\(Int(processInfo.systemUptime), privacy: .public)s openSettings=\(willOpenSettings, privacy: .public)")
        if willOpenSettings {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
            }
        }

        // 监听菜单配置更新通知（设置页 toggle 动作时触发）
        NotificationCenter.default.addObserver(
            forName: .menuConfigShouldUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.sendMenuConfigurationUpdate()
            }
        }

        // RClick 是菜单栏应用，Dock 里不该出现它。这件事由 Info.plist 的
        // `LSUIElement`（构建设置 `INFOPLIST_KEY_LSUIElement`）声明，进程从第一
        // 瞬间就是 agent —— 不再像以前那样先作为普通 App 启动、再在这里用
        // `setActivationPolicy(.accessory)` 补救：那条路要求本次启动走到这一行，
        // 而启动早期的失败路径（见 AppDelegate.init）和首启异常都会留下一个带
        // Dock 图标的普通 App。曾经读 `SHOW_IN_DOCK` 做开关，但没有任何代码写过
        // 那个键、设置页也没有开关，只有"看起来可配"的假象，一并删掉了。

        // 迁移旧的"开机登录"设置（修复前该开关只写入 UserDefaults，未真正注册登录项）
        migrateLegacyLaunchAtLoginSetting()

        // 执行数据迁移
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // 初始化默认数据
            let context = ModelContext(SharedDataManager.sharedModelContainer)
            await SharedDataManager.initializeDefaultData(context: context)

            // 补齐全默认动作后刷新内存快照，让新增动作在本次启动就进入菜单
            appState.refresh()
            sendMenuConfigurationUpdate()

            // Preload icons for all apps to improve performance
            Task { @MainActor in
                IconCache.shared.preloadIcons(for: appState.apps.map { $0.url })
            }

            // Register message handlers using type-safe API
            logger.info("Registering message handlers")
            messager.onExtensionMessage(.click) { [weak self] data in
                guard let self = self else { return }
                if let event: ClickEventPayload = messager.decodeSignedData(data) {
                    // 确认收到，供扩展判断主程序可通信性（操作成败另议）
                    messager.sendActionAck()
                    Task { @MainActor in
                        await self.handleClickEvent(event)
                    }
                } else {
                    logger.warning("Invalid click event data")
                }
            }

            messager.onExtensionMessage(.heartbeat) { [weak self] _ in
                guard let self = self else { return }
                logger.debug("Received heartbeat from extension")
                // Acknowledge every heartbeat without re-sending the menu configuration.
                // The extension needs a reply to keep its own liveness cache online.
                let reconnected = pluginActivity.receive()
                messager.sendRunningNotification()
                if reconnected {
                    sendMenuConfigurationUpdate()
                }
            }

            // 处理 Extension 请求菜单配置
            messager.onExtensionMessage(.requestConfig) { [weak self] _ in
                guard let self = self else { return }
                logger.info("Received menu config request from extension")
                self.sendMenuConfigurationUpdate()
            }

            // 启动 running 消息重试机制
            startRunningMessageRetry()

            sendObserveDirMessage()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// 用户在 App 已运行时再次打开（Finder 双击 / `open` 命令）：launch 流程不会
    /// 重跑，applicationDidFinishLaunching 不再执行——这正是"App 明明开着，
    /// 再点一次却什么都没发生"的原因。这里把它转成与首次手动启动一致的行为：
    /// 调出设置窗口。订阅方是 MenuBarExtra 的标签视图（MenuBarExtraLabel），
    /// 它从启动起就存在。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 提示点击落在「App 已在运行 / 正在退出收尾」的窗口里时，系统忽略
        // RC_QUIET_LAUNCH 环境变量、只派发 reopen——时间戳是识别这种点击的唯一
        // 信号，此时保持静默，不把设置页弹出来
        if HintClickLaunch.isRecent() {
            logger.info("reopen suppressed: recent hint-click launch")
            return true
        }
        logger.info("reopen: hasVisibleWindows=\(flag, privacy: .public)")
        NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        messager.sendQuitNotification()
        logger.info("applicationWillTerminate")
    }

    /// 迁移旧的"开机登录"设置。
    /// 修复前该开关仅写入 UserDefaults("launchAtLogin")，并未真正调用 SMAppService 注册登录项。
    /// 若检测到旧值为开启，则补齐注册，并清除旧标记避免重复迁移。
    private func migrateLegacyLaunchAtLoginSetting() {
        let legacyKey = "launchAtLogin"
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: legacyKey) else { return }

        defaults.removeObject(forKey: legacyKey)

        if !LaunchAtLogin.isEnabled {
            LaunchAtLogin.isEnabled = true
        }
    }

    // MARK: - Message Handlers

    func sendObserveDirMessage() {
        let directories: [String] = []
        messager.sendRunningNotification(directories: directories)
        if !pluginRunning {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                sendObserveDirMessage()
            }
        }
    }

    func sendMenuConfigurationUpdate() {
        let config = RCRuntime.shared.menuService.buildConfig(from: appState)
        messager.sendMenuConfig(config)
        logger.debug("Sent menu configuration to extension: \(config.actions.count) actions, \(config.apps.count) apps")
    }

    func handleClickEvent(_ event: ClickEventPayload) async {
        // 是否跳过删除确认以扩展在菜单构建时定下的标记为准。主程序不再读取
        // 实时按键状态，避免与扩展显示的菜单标题不一致。旧版扩展未携带该字段
        // 时按 false 处理，即弹出确认框——这是安全方向。
        let optionKeyPressed = event.optionKeyPressed ?? false
        logger.info("Click option: payload=\(String(describing: event.optionKeyPressed)) resolved=\(optionKeyPressed)")
        logger.debug("Handling click event: \(event.itemId) type=\(event.itemType.rawValue) trigger=\(event.trigger.rawValue) target=\(event.target)")

        let actionService = RCRuntime.shared.actionService

        switch event.itemType {
        case .app:
            await actionService.openApp(rid: event.itemId, target: event.target)
        case .action:
            await actionService.actionHandler(
                rid: event.itemId,
                target: event.target,
                trigger: event.trigger.rawValue,
                optionKeyPressed: optionKeyPressed
            )
        case .newFile:
            await actionService.createFile(rid: event.itemId, target: event.target)
        case .commonDir:
            await actionService.openCommonDirs(target: event.target)
        }
    }

    // MARK: - 重连机制

    /// 启动 running 消息重试机制（每 5 秒发送一次，持续 30 秒）
    private func startRunningMessageRetry() {
        Task { @MainActor in
            for retryCount in 0..<self.maxRunningMessageRetryCount {
                try? await Task.sleep(for: .seconds(5))
                guard !self.pluginRunning else { break }
                self.messager.sendRunningNotification()
                self.logger.debug("Sending running message retry \(retryCount + 1)/\(self.maxRunningMessageRetryCount)")
            }
            logger.debug("Running message retry completed")
        }
    }

}
