# RClick 通信协议设计

> 最后更新：2026-03-21
> 状态：设计规范
> 基于：DistributedNotificationCenter + Codable 协议层

---

## 一、概述

RClick 的主应用程序（Main App）和 FinderSync 扩展（Extension）之间通过 `DistributedNotificationCenter` 进行进程间通信（IPC）。本协议定义了类型安全的消息格式和传输机制。

### 1.1 通信模型

```
┌─────────────┐                    ┌─────────────┐
│   Main App  │ ◄───────┬─────────► │  Extension  │
│  (发送配置)  │         │          │ (发送事件)  │
│             │         │          │             │
│             │ ────────┴─────────►│             │
│             │   MenuConfig       │             │
│             │ ◄──────────────────│             │
│             │   ClickEvent       │             │
│             │ ◄──────────────────│             │
│             │   Heartbeat        │             │
└─────────────┘                    └─────────────┘
```

### 1.2 设计原则

| 原则 | 说明 |
|------|------|
| **类型安全** | 使用枚举替代字符串，编译时检查 |
| **Codable 协议** | 所有消息体实现 Codable，支持 JSON 编解码 |
| **消息 ID** | 每个消息带 UUID，支持追踪和去重 |
| **单向传输** | Main→Extension 和 Extension→Main 独立通道 |

---

## 二、消息类型定义

### 2.1 主程序 → Extension 消息

```swift
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
```

### 2.2 Extension → 主程序消息

```swift
/// Extension 发送给主程序的消息类型
enum ExtensionToMainAction: String, Codable {
    /// 菜单点击事件
    case click = "click"

    /// 心跳消息
    case heartbeat = "heartbeat"

    /// 请求菜单配置
    case requestConfig = "request-config"
}
```

---

## 三、消息载体结构

### 3.1 主程序 → Extension 消息

```swift
/// 主程序发送给 Extension 的消息
struct MainToExtensionMessage: Codable {
    /// 消息 ID，用于追踪和去重
    let id: UUID

    /// 消息类型
    let action: MainToExtensionAction

    /// JSON 编码的载荷数据
    let data: Data?

    init(id: UUID = UUID(),
         action: MainToExtensionAction,
         data: Codable? = nil) {
        self.id = id
        self.action = action
        self.data = try? JSONEncoder().encode(data)
    }
}
```

### 3.2 Extension → 主程序消息

```swift
/// Extension 发送给主程序的消息
struct ExtensionToMainMessage: Codable {
    /// 消息 ID，用于追踪和去重
    let id: UUID

    /// 消息类型
    let action: ExtensionToMainAction

    /// JSON 编码的载荷数据
    let data: Data?

    init(id: UUID = UUID(),
         action: ExtensionToMainAction,
         data: Codable? = nil) {
        self.id = id
        self.action = action
        self.data = try? JSONEncoder().encode(data)
    }
}
```

---

## 四、消息载荷定义

### 4.1 菜单配置载荷（Main → Extension）

```swift
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
}
```

#### 4.1.1 动作菜单项

```swift
/// 动作菜单项（复制路径、删除等）
struct ActionMenuItem: Codable {
    /// 菜单项唯一标识
    let id: String

    /// 菜单项显示名称
    let name: String

    /// SF Symbol 图标名称
    let icon: String

    /// 是否启用
    let enabled: Bool
}
```

#### 4.1.2 应用菜单项

```swift
/// 应用菜单项（用外部应用打开）
struct AppMenuItem: Codable {
    /// 菜单项唯一标识
    let id: String

    /// 菜单项显示名称
    let name: String

    /// 应用程序路径（Extension 据此加载图标）
    let appURL: URL
}
```

#### 4.1.3 新建文件菜单项

```swift
/// 新建文件菜单项
struct NewFileMenuItem: Codable {
    /// 菜单项唯一标识
    let id: String

    /// 菜单项显示名称
    let name: String

    /// 文件扩展名
    let ext: String

    /// SF Symbol 图标名称
    let icon: String
}
```

#### 4.1.4 常用目录菜单项

```swift
/// 常用目录菜单项
struct CommonDirMenuItem: Codable {
    /// 菜单项唯一标识
    let id: String

    /// 菜单项显示名称
    let name: String

    /// SF Symbol 图标名称
    let icon: String
}
```

### 4.2 点击事件载荷（Extension → Main）

```swift
/// 点击事件消息载荷
struct ClickEventPayload: Codable {
    /// 点击的动作类型
    let action: ExtensionToMainAction

    /// 点击的菜单项 ID
    let itemId: String

    /// 菜单项类型
    let itemType: MenuItemType

    /// 目标文件/目录路径列表
    let target: [String]

    /// 触发来源
    let trigger: MenuTrigger

    /// 目标类型列表（文件/文件夹）
    let itemTypes: [ItemType]
}
```

#### 4.2.1 菜单项类型

```swift
enum MenuItemType: String, Codable {
    case action = "action"          // 动作菜单
    case app = "app"                // 应用菜单
    case newFile = "new-file"       // 新建文件
    case commonDir = "common-dir"   // 常用目录
}
```

#### 4.2.2 触发来源

```swift
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
```

#### 4.2.3 项目类型

```swift
enum ItemType: String, Codable {
    case file = "file"
    case folder = "folder"
    case unknown = "unknown"
}
```

---

## 五、Messager 类设计

### 5.1 核心实现

```swift
import Foundation

class Messager {
    static let shared = Messager()

    private let center: DistributedNotificationCenter = .default()

    // 消息处理器存储
    private var mainToExtensionHandlers: [MainToExtensionAction: (Data?) -> Void] = [:]
    private var extensionToMainHandlers: [ExtensionToMainAction: (Data?) -> Void] = [:]

    // 通知名称
    static let mainToExtensionNotification = "RClick.MainToExtension"
    static let extensionToMainNotification = "RClick.ExtensionToMain"

    private init() {
        // 注册通知监听
        setupNotificationObservers()
    }

    // MARK: - 发送消息

    /// 主程序发送消息给 Extension
    func sendToExtension(_ action: MainToExtensionAction, data: Codable? = nil) {
        let message = MainToExtensionMessage(action: action, data: data)
        sendMessage(message, via: Self.mainToExtensionNotification)
    }

    /// Extension 发送消息给主程序
    func sendToMain(_ action: ExtensionToMainAction, data: Codable? = nil) {
        let message = ExtensionToMainMessage(action: action, data: data)
        sendMessage(message, via: Self.extensionToMainNotification)
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

    // MARK: - 便捷方法

    /// 主程序发送菜单配置给 Extension
    func sendMenuConfig(_ config: MenuConfigPayload) {
        sendToExtension(.menuConfig, data: config)
    }

    /// Extension 发送点击事件给主程序
    func sendClickEvent(_ event: ClickEventPayload) {
        sendToMain(.click, data: event)
    }

    /// 发送心跳
    func sendHeartbeat() {
        sendToMain(.heartbeat)
    }

    /// 请求菜单配置
    func requestMenuConfig() {
        sendToMain(.requestConfig)
    }
}
```

### 5.2 使用示例

#### 主程序端

```swift
// 注册点击事件处理器
Messager.shared.onExtensionMessage(.click) { data in
    guard let event: ClickEventPayload = Messager.shared.decode(data) else { return }
    // 处理点击事件
    handleClickEvent(event)
}

// 发送菜单配置
let config = MenuConfigPayload(actions: actions, apps: apps, ...)
Messager.shared.sendMenuConfig(config)
```

#### Extension 端

```swift
// 注册菜单配置处理器
Messager.shared.onMainMessage(.menuConfig) { data in
    guard let config: MenuConfigPayload = Messager.shared.decode(data) else { return }
    // 更新菜单配置
    self.menuConfig = config
}

// 发送点击事件
let event = ClickEventPayload(...)
Messager.shared.sendClickEvent(event)
```

---

## 六、通知中心配置

### 6.1 通知名称

| 方向 | 通知名称 | 用途 |
|------|---------|------|
| Main → Extension | `RClick.MainToExtension` | 主程序发送配置和指令 |
| Extension → Main | `RClick.ExtensionToMain` | Extension 发送事件和状态 |

### 6.2 消息格式

```
Notification.Object: JSON 字符串
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "action": "menu-config",
    "data": { ... }  // 可选，JSON 编码的载荷
}
```

---

## 七、错误处理

### 7.1 解码失败

```swift
func decode<T: Codable>(_ data: Data?) -> T? {
    guard let data = data else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
}
```

### 7.2 消息丢失处理

- **Extension 端**: 如果未收到菜单配置，显示空菜单或默认菜单
- **主程序端**: 如果未收到心跳，标记 Extension 为离线状态

### 7.3 超时机制

对于请求 - 响应模式的消息，建议实现超时机制：

```swift
func sendRequest<T: Codable>(
    action: MainToExtensionAction,
    data: Codable?,
    timeout: TimeInterval = 5.0,
    completion: @escaping (T?) -> Void
) {
    // 实现超时处理
}
```

---

## 八、向后兼容性

### 8.1 旧消息格式支持

为了兼容旧版本的 Extension，消息结构应保持向后兼容：

- 新增字段设为可选
- 枚举的 `rawValue` 保持与原有字符串相同
- 支持未知消息类型的降级处理

### 8.2 版本协商

未来可扩展消息结构，添加 `version` 字段：

```swift
struct MainToExtensionMessage: Codable {
    let version: Int  // 协议版本
    let id: UUID
    let action: MainToExtensionAction
    let data: Data?
}
```

---

## 九、参考文档

- **重构设计**: [../重构设计.md](../重构设计.md)
- **数据模型**: [data-models.md](data-models.md)
- **Messager 实现**: [../../RClick/Shared/Messager.swift](../../RClick/Shared/Messager.swift)
