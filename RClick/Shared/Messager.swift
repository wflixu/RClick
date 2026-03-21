//
//  Messager.swift
//  RClick
//
//  进程间通信（IPC）管理器
//  基于：DistributedNotificationCenter + Codable 协议
//

import Foundation
import OSLog
import AppKit

// MARK: - 消息类型枚举

/// 主程序发送给 Extension 的消息类型
enum MainToExtensionAction: String, Codable {
    /// 发送完整菜单配置
    case menuConfig = "menu-config"
    /// 主程序启动通知
    case running = "running"
    /// 主程序退出通知
    case quit = "quit"
    /// 请求菜单配置（Extension 主动请求）
    case requestConfig = "request-config"
}

/// Extension 发送给主程序的消息类型
enum ExtensionToMainAction: String, Codable {
    /// 菜单点击事件
    case click = "click"
    /// 心跳消息
    case heartbeat = "heartbeat"
    /// 请求菜单配置
    case requestConfig = "request-config"
}

// MARK: - 消息载荷

/// 菜单配置消息载荷
struct MenuConfigPayload: Codable {
    /// 动作菜单项列表
    let actions: [ActionMenuItem]
    /// 应用菜单项列表
    let apps: [AppMenuItem]
    /// 新建文件菜单项列表
    let newFiles: [NewFileMenuItem]
    /// 常用目录菜单项列表
    let commonDirs: [CommonDirMenuItem]

    init(
        actions: [ActionMenuItem] = [],
        apps: [AppMenuItem] = [],
        newFiles: [NewFileMenuItem] = [],
        commonDirs: [CommonDirMenuItem] = []
    ) {
        self.actions = actions
        self.apps = apps
        self.newFiles = newFiles
        self.commonDirs = commonDirs
    }
}

/// 点击事件消息载荷
struct ClickEventPayload: Codable {
    /// 点击的菜单项 ID
    let itemId: String
    /// 菜单项类型
    let itemType: MenuItemType
    /// 目标文件/目录路径列表
    let target: [String]
    /// 触发来源
    let trigger: MenuTrigger

    init(
        itemId: String,
        itemType: MenuItemType,
        target: [String] = [],
        trigger: MenuTrigger
    ) {
        self.itemId = itemId
        self.itemType = itemType
        self.target = target
        self.trigger = trigger
    }
}

// MARK: - 辅助类型

/// 菜单项类型
enum MenuItemType: String, Codable {
    case action = "action"  // 动作菜单
    case app = "app"  // 应用菜单
    case newFile = "new-file"  // 新建文件
    case commonDir = "common-dir"  // 常用目录
}

/// 触发来源
enum MenuTrigger: String, Codable {
    /// 选中文件/文件夹右键
    case contextualItems = "ctx-items"
    /// 空白处右键
    case contextualContainer = "ctx-container"
    /// 侧边栏右键
    case contextualSidebar = "ctx-sidebar"
    /// 工具栏
    case toolbar = "toolbar"
}

/// 项目类型（文件/文件夹）
enum ItemType: String, Codable {
    case file = "file"
    case folder = "folder"
    case unknown = "unknown"
}

// MARK: - 消息结构

/// 主程序发送给 Extension 的消息
struct MainToExtensionMessage: Codable {
    /// 消息 ID，用于追踪和去重
    let id: UUID
    /// 消息类型
    let action: MainToExtensionAction
    /// JSON 编码的载荷数据
    let data: Data?

    init<T: Encodable>(
        id: UUID = UUID(),
        action: MainToExtensionAction,
        data: T? = nil
    ) {
        self.id = id
        self.action = action
        self.data = try? JSONEncoder().encode(data)
    }
}

/// Extension 发送给主程序的消息
struct ExtensionToMainMessage: Codable {
    /// 消息 ID，用于追踪和去重
    let id: UUID
    /// 消息类型
    let action: ExtensionToMainAction
    /// JSON 编码的载荷数据
    let data: Data?

    init<T: Encodable>(
        id: UUID = UUID(),
        action: ExtensionToMainAction,
        data: T? = nil
    ) {
        self.id = id
        self.action = action
        self.data = try? JSONEncoder().encode(data)
    }
}

// MARK: - 菜单项模型（用于 Extension 渲染）

/// 新建文件菜单项
struct NewFileMenuItem: Codable {
    let id: String
    let name: String
    let ext: String
    let icon: String

    init(id: String, name: String, ext: String, icon: String) {
        self.id = id
        self.name = name
        self.ext = ext
        self.icon = icon
    }
}

/// 常用目录菜单项
struct CommonDirMenuItem: Codable {
    let id: String
    let name: String
    let icon: String

    init(id: String, name: String, icon: String) {
        self.id = id
        self.name = name
        self.icon = icon
    }
}

// MARK: - Logger

/// Logger for Messager operations
private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "RClick",
    category: "Messager"
)

// MARK: - 消息管理器

/// 消息管理器 - 处理主程序和 Extension 之间的通信
class Messager {
    static let shared = Messager()

    private let center: DistributedNotificationCenter = .default()

    // 消息处理器存储
    private var mainToExtensionHandlers: [MainToExtensionAction: (Data?) -> Void] = [:]
    private var extensionToMainHandlers: [ExtensionToMainAction: (Data?) -> Void] = [:]

    // 通知名称
    static let mainToExtensionNotification = "RClick.MainToExtension"
    static let extensionToMainNotification = "RClick.ExtensionToMain"

    // 兼容旧 API 的存储
    private var legacyBus: [String: (MessagePayload) -> Void] = [:]

    private init() {
        setupNotificationObservers()
    }

    // MARK: - 设置通知观察者

    private func setupNotificationObservers() {
        // 监听主程序发送给 Extension 的消息
        center.addObserver(
            self,
            selector: #selector(handleMainToExtensionMessage(_:)),
            name: NSNotification.Name(Self.mainToExtensionNotification),
            object: nil
        )

        // 监听 Extension 发送给主程序的消息
        center.addObserver(
            self,
            selector: #selector(handleExtensionToMainMessage(_:)),
            name: NSNotification.Name(Self.extensionToMainNotification),
            object: nil
        )
    }

    // MARK: - 发送消息

    /// 主程序发送消息给 Extension
    func sendToExtension<T: Encodable>(_ action: MainToExtensionAction, data: T? = nil) {
        let message = MainToExtensionMessage(action: action, data: data)
        sendMessage(message, via: Self.mainToExtensionNotification)
    }

    /// Extension 发送消息给主程序
    func sendToMain<T: Encodable>(_ action: ExtensionToMainAction, data: T? = nil) {
        let message = ExtensionToMainMessage(action: action, data: data)
        sendMessage(message, via: Self.extensionToMainNotification)
    }

    /// 发送消息到通知中心
    private func sendMessage(_ message: some Encodable, via notificationName: String) {
        guard let jsonData = try? JSONEncoder().encode(message) else {
            logger.error("Failed to encode message")
            return
        }

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            logger.error("Failed to convert message to string")
            return
        }

        logger.info("Sending message via \(notificationName)")
        center.postNotificationName(
            NSNotification.Name(notificationName),
            object: jsonString,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    // MARK: - 注册处理器

    /// Extension 注册主程序消息处理器
    func onMainMessage(_ action: MainToExtensionAction, handler: @escaping (Data?) -> Void) {
        mainToExtensionHandlers[action] = handler
    }

    /// 主程序注册 Extension 消息处理器
    func onExtensionMessage(_ action: ExtensionToMainAction, handler: @escaping (Data?) -> Void) {
        extensionToMainHandlers[action] = handler
    }

    // MARK: - 处理消息

    @objc private func handleMainToExtensionMessage(_ notification: NSNotification) {
        guard let jsonString = notification.object as? String,
              let jsonData = jsonString.data(using: .utf8) else {
            logger.error("Invalid message format")
            return
        }

        do {
            let message = try JSONDecoder().decode(MainToExtensionMessage.self, from: jsonData)
            logger.info("Received main-to-extension message: \(message.action.rawValue)")

            if let handler = mainToExtensionHandlers[message.action] {
                handler(message.data)
            } else {
                logger.warning("No handler registered for action: \(message.action.rawValue)")
            }
        } catch {
            logger.error("Failed to decode message: \(error)")
        }
    }

    @objc private func handleExtensionToMainMessage(_ notification: NSNotification) {
        guard let jsonString = notification.object as? String,
              let jsonData = jsonString.data(using: .utf8) else {
            logger.error("Invalid message format")
            return
        }

        do {
            let message = try JSONDecoder().decode(ExtensionToMainMessage.self, from: jsonData)
            logger.info("Received extension-to-main message: \(message.action.rawValue)")

            if let handler = extensionToMainHandlers[message.action] {
                handler(message.data)
            } else {
                logger.warning("No handler registered for action: \(message.action.rawValue)")
            }
        } catch {
            logger.error("Failed to decode message: \(error)")
        }
    }

    // MARK: - 便捷方法

    /// 主程序发送菜单配置给 Extension
    func sendMenuConfig(_ config: MenuConfigPayload) {
        sendToExtension(.menuConfig, data: config)
    }

    /// 发送主程序启动通知
    func sendRunningNotification(directories: [String] = []) {
        let payload = MessagePayload(action: "running", target: directories, rid: "", trigger: "")
        sendToExtension(.running, data: payload)
    }

    /// 发送主程序退出通知
    func sendQuitNotification() {
        sendToExtension(.quit, data: Optional<Int>.none)
    }

    /// Extension 发送心跳
    func sendHeartbeat() {
        sendToMain(.heartbeat, data: Optional<Int>.none)
    }

    /// 请求菜单配置
    func requestMenuConfig() {
        sendToMain(.requestConfig, data: Optional<Int>.none)
    }

    /// Extension 发送点击事件
    func sendClickEvent(_ event: ClickEventPayload) {
        sendToMain(.click, data: event)
    }

    // MARK: - 解码辅助

    /// 解码数据为指定类型
    func decode<T: Codable>(_ data: Data?) -> T? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - 兼容旧的 API

extension Messager {
    /// 兼容旧的 sendMessage 方法
    func sendMessage(name: String, data: MessagePayload) {
        let notificationName = name == Key.messageFromFinder
            ? Self.extensionToMainNotification
            : Self.mainToExtensionNotification
        let message = ExtensionToMainMessage(action: .click, data: data)
        sendMessage(message, via: notificationName)
    }

    /// 兼容旧的 on 方法
    func on(name: String, handler: @escaping (MessagePayload) -> Void) {
        center.addObserver(
            self,
            selector: #selector(legacyRecievedMessage(_:)),
            name: NSNotification.Name(name),
            object: nil
        )
        legacyBus[name] = handler
    }

    @objc private func legacyRecievedMessage(_ notification: NSNotification) {
        guard let jsonString = notification.object as? String,
              let jsonData = jsonString.data(using: .utf8) else {
            return
        }

        if let payload = try? JSONDecoder().decode(MessagePayload.self, from: jsonData) {
            if let handler = legacyBus[notification.name.rawValue] {
                handler(payload)
            }
        }
    }
}

/// 兼容旧版本的消息载荷
struct MessagePayload: Codable {
    var action: String = ""
    var target: [String] = []
    var rid: String = ""
    /// ctx-items, ctx-container, ctx-sidebar, toolbar
    var trigger: String = ""

    var description: String {
        "MessagePayload(action: \(action), target: \(target), rid: \(rid), trigger: \(trigger))"
    }

    init(action: String = "", target: [String] = [], rid: String = "", trigger: String = "") {
        self.action = action
        self.target = target
        self.rid = rid
        self.trigger = trigger
    }
}

// MARK: - Icon Cache (临时，待 Phase 5 统一)

@MainActor
class IconCacheManager: ObservableObject {
    static let shared = IconCacheManager()

    private var memoryCache: [String: NSImage] = [:]
    private let iconSize = CGSize(width: 32, height: 32)

    private init() {}

    func icon(for url: URL) -> NSImage {
        let cacheKey = url.path
        if let cached = memoryCache[cacheKey] {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = iconSize
        memoryCache[cacheKey] = icon
        return icon
    }

    func clearMemoryCache() {
        memoryCache.removeAll()
    }

    func preloadIcons(for urls: [URL]) {
        for url in urls {
            _ = icon(for: url)
        }
    }

    var cacheSize: Int {
        memoryCache.count
    }
}
