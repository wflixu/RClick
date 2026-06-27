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
import CryptoKit

// MARK: - 消息类型枚举

/// 主程序发送给 Extension 的消息类型
enum MainToExtensionAction: String, Codable {
    /// 发送完整菜单配置
    case menuConfig = "menu-config"
    /// 主程序启动通知
    case running = "running"
    /// 主程序退出通知
    case quit = "quit"
    /// 响应菜单配置请求（携带菜单配置）
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
    /// 菜单版本号，用于防重复和防乱序
    let version: Int
    /// 动作菜单项列表
    let actions: [ActionMenuItem]
    /// 应用菜单项列表
    let apps: [AppMenuItem]
    /// 新建文件菜单项列表
    let newFiles: [NewFileMenuItem]
    /// 常用目录菜单项列表
    let commonDirs: [CommonDirMenuItem]
    /// 是否折叠动作菜单（默认 false）
    let actionsCollapsed: Bool
    /// 是否折叠应用菜单（默认 false）
    let appsCollapsed: Bool
    /// 是否折叠新建文件菜单（默认 true）
    let newFilesCollapsed: Bool
    /// 是否折叠常用目录菜单（默认 true）
    let commonDirsCollapsed: Bool

    init(
        version: Int = 1,
        actions: [ActionMenuItem] = [],
        apps: [AppMenuItem] = [],
        newFiles: [NewFileMenuItem] = [],
        commonDirs: [CommonDirMenuItem] = [],
        actionsCollapsed: Bool = false,
        appsCollapsed: Bool = false,
        newFilesCollapsed: Bool = true,
        commonDirsCollapsed: Bool = true
    ) {
        self.version = version
        self.actions = actions
        self.apps = apps
        self.newFiles = newFiles
        self.commonDirs = commonDirs
        self.actionsCollapsed = actionsCollapsed
        self.appsCollapsed = appsCollapsed
        self.newFilesCollapsed = newFilesCollapsed
        self.commonDirsCollapsed = commonDirsCollapsed
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

/// 运行状态消息载荷（用于通知 Extension 主程序运行状态）
struct RunningPayload: Codable {
    /// 监听目录列表
    let directories: [String]

    init(directories: [String] = []) {
        self.directories = directories
    }
}

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

/// 主程序发送给 Extension 的消息（带签名）
struct MainToExtensionMessage: Codable {
    /// 消息 ID，用于追踪和去重
    let id: UUID
    /// 消息类型
    let action: MainToExtensionAction
    /// JSON 编码的签名载荷数据（SignedPayload）
    let signedData: Data?

    init<T: Codable>(
        id: UUID = UUID(),
        action: MainToExtensionAction,
        data: T? = nil
    ) {
        self.id = id
        self.action = action

        // 对 payload 进行签名
        if let data = data {
            do {
                let signedPayload = try MessageSecurity.sign(data)
                self.signedData = try? JSONEncoder().encode(signedPayload)
            } catch {
                self.signedData = nil
            }
        } else {
            self.signedData = nil
        }
    }
}

/// Extension 发送给主程序的消息（带签名）
struct ExtensionToMainMessage: Codable {
    /// 消息 ID，用于追踪和去重
    let id: UUID
    /// 消息类型
    let action: ExtensionToMainAction
    /// JSON 编码的签名载荷数据（SignedPayload）
    let signedData: Data?

    init<T: Codable>(
        id: UUID = UUID(),
        action: ExtensionToMainAction,
        data: T? = nil
    ) {
        self.id = id
        self.action = action

        // 对 payload 进行签名
        if let data = data {
            do {
                let signedPayload = try MessageSecurity.sign(data)
                self.signedData = try? JSONEncoder().encode(signedPayload)
            } catch {
                self.signedData = nil
            }
        } else {
            self.signedData = nil
        }
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
class Messager: @unchecked Sendable {
    static let shared = Messager()

    // 消息处理器存储
    // 安全说明：仅在 init/启动阶段写入一次，之后只读不写
    // 写入发生在分布式通知到达之前，无并发读写风险
    nonisolated(unsafe) private var mainToExtensionHandlers: [MainToExtensionAction: (Data?) -> Void] = [:]
    nonisolated(unsafe) private var extensionToMainHandlers: [ExtensionToMainAction: (Data?) -> Void] = [:]

    // 通知名称
    static let mainToExtensionNotification = "RClick.MainToExtension"
    static let extensionToMainNotification = "RClick.ExtensionToMain"

    private let isExtension: Bool

    private init() {
        // 判断当前是否为 Extension 进程
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        self.isExtension = bundleId.hasSuffix(".FinderSyncExt")

        // Danger note: DistributedNotificationCenter 初始化线程安全
        let center = DistributedNotificationCenter.default()
        if isExtension {
            center.addObserver(
                self,
                selector: #selector(handleMainToExtensionMessage(_:)),
                name: NSNotification.Name(Self.mainToExtensionNotification),
                object: nil
            )
        } else {
            center.addObserver(
                self,
                selector: #selector(handleExtensionToMainMessage(_:)),
                name: NSNotification.Name(Self.extensionToMainNotification),
                object: nil
            )
        }
    }

    // MARK: - 发送消息（nonisolated，不访问 @MainActor 状态）

    /// 主程序发送消息给 Extension
    func sendToExtension<T: Codable>(_ action: MainToExtensionAction, data: T? = nil) {
        let message = MainToExtensionMessage(action: action, data: data)
        sendMessage(message, via: Self.mainToExtensionNotification)
        logger.debug("Sent to extension: \(action.rawValue)")
    }

    /// Extension 发送消息给主程序
    func sendToMain<T: Codable>(_ action: ExtensionToMainAction, data: T? = nil) {
        let message = ExtensionToMainMessage(action: action, data: data)
        sendMessage(message, via: Self.extensionToMainNotification)
        logger.debug("Sent to main: \(action.rawValue)")
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

        logger.debug("Sending message via \(notificationName)")
        DistributedNotificationCenter.default().postNotificationName(
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
            logger.debug("Received main-to-extension message: \(message.action.rawValue)")

            if let handler = mainToExtensionHandlers[message.action] {
                handler(message.signedData)
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
            logger.debug("Received extension-to-main message: \(message.action.rawValue)")

            if let handler = extensionToMainHandlers[message.action] {
                handler(message.signedData)
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
        let payload = RunningPayload(directories: directories)
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

    /// 主程序响应菜单配置请求
    func respondMenuConfigRequest(_ config: MenuConfigPayload) {
        sendToExtension(.requestConfig, data: config)
    }

    // MARK: - 解码辅助

    /// 解码数据为指定类型
    func decode<T: Codable>(_ data: Data?) -> T? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// 解码并验证签名的数据为指定类型
    func decodeSignedData<T: Codable>(_ signedData: Data?, as type: T.Type = T.self) -> T? {
        guard let signedData = signedData else { return nil }

        do {
            let signedPayload = try JSONDecoder().decode(SignedPayload<T>.self, from: signedData)

            if MessageSecurity.verify(signedPayload) {
                return signedPayload.payload
            } else {
                logger.warning("Message signature verification failed, dropping message")
                return nil
            }
        } catch {
            logger.error("Failed to decode signed data: \(error)")
            return nil
        }
    }
}
