# FinderSync Extension 重连方案设计

> 创建时间：2026-03-21
> 最后更新：2026-03-21
> 状态：设计 v2（基于专家评审优化）
> 架构原则：**推 + 拉混合模式**

---

## 一、问题背景

### 1.1 问题描述

用户反馈：**主 App 已打开，但 FinderSync Extension 没有加载**，导致右键菜单不显示。

### 1.2 FinderSync Extension 生命周期

| 阶段 | 说明 | 控制方 |
|------|------|--------|
| **加载** | 系统决定何时加载 Extension | macOS |
| **初始化** | `init()` 方法执行，注册消息处理器 | Extension |
| **监听** | `beginObservingDirectory(at:)` 被调用 | Extension |
| **菜单构建** | `menu(for:)` 每次右键时调用 | Extension |
| **卸载** | 系统资源回收时终止 | macOS |

### 1.3 问题原因分析

1. **系统未激活 Extension**：Finder 可能尚未需要加载 Extension
2. **Extension 进程被终止**：内存压力或长时间未使用
3. **消息不同步**：
   - 主 App 启动了，但 Extension 还未收到 `running` 消息
   - Extension 的 `isHostAppOpen` 标志仍为 `false`
4. **心跳机制失效**：Extension 心跳发送了，但主 App 未正确响应

---

## 二、核心设计原则

### 2.1 四条基本原则（必须遵守）

| 原则 | 说明 | 违反后果 |
|------|------|----------|
| **Notification ≠ 状态** | 通知只能当"信号"，不能当"真相" | 丢消息=状态错乱 |
| **必须存在状态快照** | 否则无法恢复一致性 | 重启后数据丢失 |
| **Extension 必须支持主动拉取** | 不能只靠推送 | 无法自愈 |
| **所有通信必须幂等** | 重复消息不能出错 | 重复执行风险 |

### 2.2 架构升级：从"纯推"到"推 + 拉混合"

```
之前：纯推送模式
Main App → 发送消息 → Extension（靠运气接收）

升级：推 + 拉混合模式
Main App ←→ 发送/请求 ←→ Extension（可主动拉取）
```

---

## 三、设计方案 v2

### 3.1 四层防护策略

| 层级 | 机制 | 作用 | 状态 |
|------|------|------|------|
| L1 | **状态快照** | 主 App 保存最后菜单状态 | ✅ 新增 |
| L2 | **心跳重试** | 主 App 启动后定期发送 running | ✅ 保留 |
| L3 | **主动请求** | Extension 启动/过期时主动请求 | ✅ 新增 |
| L4 | **自动重连** | 心跳超时后自动恢复 | ✅ 保留 |
| L5 | **手动刷新** | 用户菜单触发 | ✅ 保留 |

### 3.2 架构图

```
┌─────────────────────────┐
│      Main App           │
│─────────────────────────│
│  状态源（唯一真相）      │
│  - MenuSnapshot 缓存    │
│  - 版本计数器           │
│  - Action Handler       │
└───────────┬─────────────┘
            │
    ┌───────┼────────────────┐
    │       │                │
    ▼       ▼                ▼
推送    请求/响应        心跳检测
(信号)   (拉取补偿)        (可选)
    │
    ▼
┌──────────────────────────────┐
│   FinderSync Extension       │
│──────────────────────────────│
│  内存缓存（menu snapshot）    │
│  UI 渲染（只读缓存）           │
│  用户点击 → 发消息            │
│  缓存过期 → 发送 request      │
└──────────────────────────────┘
```

---

## 四、详细设计

### 4.1 状态快照机制（核心）

#### 主 App 端

**设计要点**：
- 主 App 保存最后发送的菜单配置（内存缓存）
- 每次数据变更时更新快照和版本号
- 响应 Extension 的 `requestConfig` 消息
- `running` 消息携带 `MenuSnapshot`

**实现方案**：
```swift
// RClick/RClickApp.swift
class RClickApp: NSObject, NSApplicationDelegate {
    // 状态快照（真相源）
    private var lastMenuSnapshot: Data?
    private var menuVersion: Int = 0

    // 状态变更时
    func updateMenuConfig() {
        menuVersion += 1
        let snapshot = MenuSnapshot(version: menuVersion, config: buildMenuConfig())
        lastMenuSnapshot = try? JSONEncoder().encode(snapshot)
        // 发送 running 消息时携带 snapshot
        sendRunningMessage(snapshot)
    }

    // 响应 Extension 的 config 请求
    func handleConfigRequest() {
        if let data = lastMenuSnapshot {
            Messager.shared.sendToExtension(.menuConfig, data: data)
        }
    }
}

struct MenuSnapshot: Codable {
    let version: Int
    let config: MenuConfigPayload
}

// 发送 running 消息
func sendRunningMessage(_ snapshot: MenuSnapshot) {
    Messager.shared.sendToExtension(.running, data: snapshot)
}
```

#### Extension 端

**设计要点**：
- 启动时主动发送 `menu.request`
- 接收 `menu.update` 时检查版本号（防重复、防乱序）
- `menu(for:)` 只读内存缓存，不做任何 IO

**实现方案**：
```swift
// FinderSyncExt/FinderSyncExt.swift
class FinderSyncExt: FIFinderSync {
    private var currentVersion: Int = 0
    private var cachedMenuConfig: MenuConfigPayload?

    override init() {
        super.init()
        // 启动时主动请求
        sendMenuRequest()
        setupMessageHandlers()
    }

    private func handleMenuUpdate(_ data: Data) {
        guard let snapshot = decode<MenuSnapshot>(data) else { return }

        // 版本检查：只接受更新的版本
        guard snapshot.version > currentVersion else { return }

        currentVersion = snapshot.version
        cachedMenuConfig = snapshot.config
    }

    // 菜单构建：只读缓存
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        guard let config = cachedMenuConfig else {
            // 缓存为空，触发请求
            sendMenuRequest()
            return NSMenu(title: "RClick (loading...)")
        }
        // 使用缓存构建菜单...
    }
}
```

---

### 4.2 心跳重试机制（保留）

**设计思路**：
- 主 App 启动后发送 `running` 消息（携带 `MenuSnapshot`）
- 每 5 秒重试一次，持续 30 秒（6 次）
- 确保 Extension 加载后能收到消息

**修改要点**：
- `running` 消息携带 `MenuSnapshot`，而非单独发送菜单配置
- Extension 收到 `running` 后进行版本检查，更新缓存

---

### 4.3 主动请求机制（新增）

#### 触发时机

| 时机 | 说明 |
|------|------|
| Extension 启动时 | `init()` 中发送 `requestConfig` |
| 缓存为空时 | `menu(for:)` 发现缓存为空 |
| 缓存过期时 | 超时未收到更新（可选：30 秒） |
| 版本不匹配时 | 检测到数据不一致 |

#### 请求流程

```
Extension → requestConfig → Main App
                            ↓
Main App → menuConfig → Extension
                            ↓
Extension → 版本检查 → 缓存更新
```

#### 实现方案

```swift
// Extension 端
class FinderSyncExt: FIFinderSync {
    private var currentVersion: Int = 0
    private var cachedMenuConfig: MenuConfigPayload?

    override init() {
        super.init()
        setupMessageHandlers()
        // 启动时主动请求配置
        sendMenuRequest()
    }

    private func handleRunning(_ data: Data?) {
        guard let snapshot = decode<MenuSnapshot>(data) else { return }
        // 版本检查：只接受更新的版本
        guard snapshot.version > currentVersion else { return }
        currentVersion = snapshot.version
        cachedMenuConfig = snapshot.config
    }

    private func handleMenuConfig(_ data: Data?) {
        guard let config = decode<MenuConfigPayload>(data) else { return }
        cachedMenuConfig = config
    }

    // 菜单构建：只读缓存
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        guard let config = cachedMenuConfig else {
            // 缓存为空，触发请求
            sendMenuRequest()
            return NSMenu(title: "RClick (loading...)")
        }
        // 使用缓存构建菜单...
    }
}
```

---

### 4.4 自动重连机制（优化）

**设计要点**：
- 主 App 端添加心跳超时检测（15 秒）
- 超时后标记 Extension 为离线状态
- 用户可点击"刷新 Extension"按钮触发重连

**实现方案**：
```swift
// Main App 端
private var heartbeatTimeoutTimer: Timer?
private var isExtensionOnline: Bool = false

func handleHeartbeat() {
    isExtensionOnline = true
    // 重置超时定时器
    heartbeatTimeoutTimer?.invalidate()
    heartbeatTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
        self?.handleHeartbeatTimeout()
    }
}

func handleHeartbeatTimeout() {
    isExtensionOnline = false
    // 菜单栏显示"扩展未响应"
    // 用户可点击"刷新 Extension"按钮
}

// 用户点击"刷新 Extension"时
func refreshExtension() {
    if let snapshot = lastMenuSnapshot {
        Messager.shared.sendToExtension(.running, data: snapshot)
    }
}
```

---

### 4.5 手动刷新机制（保留）

**设计要点**：
- 用户点击"刷新 Extension"按钮
- 触发主 App 重新发送快照
- 同时通知用户结果

---

## 五、消息协议设计

### 5.1 消息类型定义

**基于通信协议**：

| 消息类型 | 方向 | 枚举值 | 说明 |
|---------|------|--------|------|
| `requestConfig` | Ext→App | `ExtensionToMainAction.requestConfig` | Extension 请求菜单配置 |
| `menuConfig` | App→Ext | `MainToExtensionAction.menuConfig` | 主 App 推送菜单配置 |
| `running` | App→Ext | `MainToExtensionAction.running` | 主 App 启动通知（携带 MenuSnapshot） |
| `click` | Ext→App | `ExtensionToMainAction.click` | 用户点击菜单项 |
| `heartbeat` | Ext→App | `ExtensionToMainAction.heartbeat` | 心跳消息 |

### 5.2 菜单数据结构

```swift
struct MenuSnapshot: Codable {
    let version: Int          // 版本号，用于防重防乱序
    let config: MenuConfigPayload
}

// running 消息携带 MenuSnapshot
func sendRunningMessage() {
    let snapshot = MenuSnapshot(version: menuVersion, config: buildMenuConfig())
    Messager.shared.sendToExtension(.running, data: snapshot)
}
```

---

## 六、实施步骤

### Phase 1: 状态快照（P0）⭐ 核心

**目标**：建立"真相源"

**步骤**：
1. 在 `RClickApp.swift` 添加 `lastMenuSnapshot` 和 `menuVersion`
2. 每次菜单配置变更时更新快照
3. 注册 `requestConfig` 消息处理器
4. `running` 消息携带 `MenuSnapshot`

**验收标准**：
- [ ] 主 App 保存最后菜单状态
- [ ] `running` 消息携带 `MenuSnapshot`
- [ ] 响应 `requestConfig` 请求时发送快照

---

### Phase 2: 主动请求（P0）⭐ 核心

**目标**：Extension 支持主动拉取

**步骤**：
1. 在 `FinderSyncExt.swift` 添加 `sendMenuRequest()` 方法
2. `init()` 中启动时发送请求
3. `menu(for:)` 中缓存为空时触发请求
4. 接收更新时检查版本号

**验收标准**：
- [ ] Extension 启动后主动请求菜单
- [ ] 版本检查正常工作
- [ ] 缓存为空时自动请求

---

### Phase 3: 心跳重试（P1）

**目标**：覆盖"刚启动"场景

**步骤**：
1. 在 `RClickApp.swift` 添加重试定时器
2. 每 5 秒发送 `running` 消息（携带 `MenuSnapshot`），持续 30 秒

**验收标准**：
- [ ] 主 App 启动后发送 6 次 `running` 消息

---

### Phase 4: 心跳检测（P1）

**目标**：检测 Extension 存活状态

**步骤**：
1. 添加心跳超时检测（15 秒）
2. 超时后标记 Extension 离线
3. 用户可手动"刷新 Extension"

**验收标准**：
- [ ] Extension 每 10 秒发送 `heartbeat`
- [ ] 主 App 15 秒未收到心跳，标记离线
- [ ] 用户可点击"刷新 Extension"按钮

---

### Phase 5: 手动刷新（P2）

**目标**：用户兜底控制

**步骤**：
1. 菜单栏添加"刷新 Extension"按钮
2. 实现 `refreshExtension()` 方法

**验收标准**：
- [ ] 点击按钮后菜单更新
```

## 七、预期效果

### 7.1 场景覆盖

| 场景 | 行为 | 结果 |
|------|------|------|
| 主 App 启动 | 发送 `running` × 6 + 保存快照 | Extension 加载后收到消息 |
| Extension 重启 | 主动发送 `requestConfig` | 立即获取最新状态 |
| 缓存为空 | `menu(for:)` 触发请求 | 自愈恢复 |
| 消息丢失 | 下次请求获取快照 | 状态一致 |
| Extension 超时 | 15 秒未收到 `heartbeat` | 标记离线，用户可刷新 |
| 用户手动刷新 | 点击菜单按钮 | 立即刷新 |

### 7.2 能力评估

| 能力 | 之前 | 升级后 |
|------|------|--------|
| Extension 随机重启 | ❌ | ✅ |
| Notification 丢失 | ❌ | ✅ |
| 主 App 先启动 | ⚠️ | ✅ |
| Extension 后启动 | ⚠️ | ✅ |
| Finder 延迟加载 | ❌ | ✅ |
| 用户频繁点击 | ✅ | ✅ |
| 状态一致性 | 🟡 弱 | 🟢 接近强一致 |

---

## 八、验证方法

### 8.1 日志检查

```bash
# 查看主 App 日志
log show --predicate 'subsystem == "cn.wflixu.RClick"' --last 5m

# 查看 Extension 日志
log show --predicate 'subsystem == "cn.wflixu.RClick" AND category == "FinderOpen"' --last 5m
```

### 8.2 功能测试

1. **测试状态快照**：
   - 启动主 App，修改菜单配置
   - 终止 Extension
   - 重启 Extension，验证收到最新配置

2. **测试主动请求**：
   - 终止 Extension
   - 重启 Extension
   - 观察日志中 `requestConfig` 和 `menuConfig` 消息

3. **测试版本检查**：
   - 快速多次修改配置
   - 验证 Extension 只接受最新版本

4. **测试心跳检测**：
   - 启动主 App 和 Extension
   - 使用 `killall FinderSyncExt` 终止 Extension
   - 观察主 App 是否在 15 秒后标记离线

---

## 九、注意事项

### 9.1 设计约束

1. **Notification 只是信号**：通知只能当"信号"，不能当"真相"
2. **状态快照是唯一真相**：主 App 保存 `lastMenuSnapshot` 作为真相源
3. **版本号必须单调递增**：防止乱序问题
4. **消息处理必须幂等**：重复消息不能产生副作用
5. **双向心跳机制**：
   - Main → Ext: `running`（启动时 + 重试 6 次）
   - Ext → Main: `heartbeat`（每 10 秒）

### 9.2 工程建议

1. **日志记录**：所有关键操作都应记录日志
2. **版本检查**：接收更新时检查版本号
3. **去重机制**：使用消息 ID 防止重复处理
4. **防抖处理**：频繁更新时 debounce（100-300ms）

---

## 十、参考文档

- **communication-protocol.md**：通信协议设计
- **重构设计.md**：整体架构设计
- **重构计划.md**：实施计划
