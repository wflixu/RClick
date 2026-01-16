# SwiftData 跨进程数据同步方案

## 问题分析

### 1.1 架构现状
```
┌─────────────────────────────────────────────────────────┐
│                     App Group Container                  │
│                  (group.cn.wflixu.RClick)               │
├─────────────────────────────────────────────────────────┤
│  RClickDatabase.sqlite                                  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  SwiftData Models                                  │  │
│  │  - AppEntity                                      │  │
│  │  - ActionEntity                                   │  │
│  │  - NewFileTypeEntity                               │  │
│  │  - CommonDirEntity                                │  │
│  │  - PermDir                                        │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
         ↑                          ↑
         │                          │
    ┌────┴────┐              ┌─────┴─────┐
    │ Main App│              │ Extension │
    │ Process │              │  Process  │
    └─────────┘              └───────────┘

问题：
1. 两个进程各自创建独立的 ModelContainer 实例
2. 没有自动的数据变更通知机制
3. 需要手动实现同步和刷新策略
```

### 1.2 SwiftData 在多进程中的限制
- **无自动通知**: SwiftData 不提供跨进程的自动变更通知
- **缓存问题**: 每个进程维护自己的内存缓存
- **事务隔离**: 一个进程的写入可能不会立即反映到另一个进程

## 二、解决方案设计

### 2.1 三层数据同步架构

```
┌─────────────────────────────────────────────────────────────┐
│                   数据同步层 (Data Sync Layer)               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. DistributedNotificationCenter (实时通知)                  │
│     - 数据变更通知                                           │
│     - 版本号更新通知                                         │
│                                                              │
│  2. 文件系统观察者 (File System Observer)                     │
│     - 监控 SQLite 文件修改时间                                │
│     - 检测外部进程的写入                                     │
│                                                              │
│  3. 定时轮询 (Periodic Polling)                              │
│     - 定期刷新数据                                          │
│     - 作为最后的保底机制                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         ↓                                        ↓
    ┌────────┐                              ┌──────────┐
    │ Main App│                              │ Extension │
    └────────┘                              └───────────┘
```

### 2.2 核心实现：数据版本控制

#### 方案1: 版本号表 (推荐)

**创建版本控制模型**:
```swift
@Model
final class DataVersion {
    @Attribute(.unique) var key: String
    var version: Int
    var updatedAt: Date

    init(key: String, version: Int) {
        self.key = key
        self.version = version
        self.updatedAt = Date()
    }
}
```

**数据写入通知机制**:
```swift
// Main App: DataWriteHandler.swift
import SwiftData
import DistributedNotifications

class DataWriteHandler {
    static let shared = DataWriteHandler()

    @MainActor
    func writeAndNotify<T: PersistentModel>(
        _ item: T,
        context: ModelContext,
        notificationName: String
    ) throws {
        // 1. 更新版本号
        updateVersion(for: NSStringFromClass(type(of: T.self)), context: context)

        // 2. 写入数据
        context.insert(item)
        try context.save()

        // 3. 发送通知给 Extension
        let version = getCurrentVersion(for: NSStringFromClass(type(of: T.self)), context: context)

        let payload: [String: Any] = [
            "entityType": NSStringFromClass(type(of: T.self)),
            "entityId": item.id,
            "action": "update",
            "version": version,
            "timestamp": Date().timeIntervalSince1970
        ]

        // 通过 DistributedNotificationCenter 发送
        DistributedNotificationCenter.default().post(
            name: NSNotification.Name(notificationName),
            object: nil,
            userInfo: payload
        )

        logger.info("Data written and notification sent: \(notificationName)")
    }

    private func updateVersion(for entityType: String, context: ModelContext) {
        let descriptor = FetchDescriptor<DataVersion>(
            predicate: #predicate { $0.key == entityType }
        )

        if let version = try? context.fetch(descriptor).first {
            version.version += 1
            version.updatedAt = Date()
        } else {
            let newVersion = DataVersion(key: entityType, version: 1)
            context.insert(newVersion)
        }
    }

    private func getCurrentVersion(for entityType: String, context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<DataVersion>(
            predicate: #predicate { $0.key == entityType }
        )

        return (try? context.fetch(descriptor).first?.version) ?? 0
    }
}
```

**Extension 监听机制**:
```swift
// FinderSyncExt.swift
@MainActor
class FinderSyncExt: FIFinderSync {
    private var modelContext: ModelContext?
    private var dataVersions: [String: Int] = [:]  // 本地版本缓存
    private var nextTag: Int = 1
    private var tagRidDict: [Int: String] = [:]

    override init() {
        super.init()

        // 初始化 SwiftData
        do {
            let container = try SharedDataManager.sharedModelContainer
            modelContext = ModelContext(container)

            // 加载初始版本号
            loadCurrentVersions()

            // 设置数据监听
            setupDataChangeListeners()

            // 设置文件系统监听
            setupFileSystemWatcher()

            logger.info("SwiftData context initialized successfully")
        } catch {
            logger.error("Failed to initialize SwiftData context: \(error)")
        }

        // 注册消息监听
        setupMessageHandlers()
    }

    private func loadCurrentVersions() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<DataVersion>()
        let versions = (try? context.fetch(descriptor)) ?? []

        for version in versions {
            dataVersions[version.key] = version.version
        }

        logger.info("Loaded \(dataVersions.count) version records")
    }

    private func setupDataChangeListeners() {
        let center = DistributedNotificationCenter.default()

        // 监听 AppEntity 变更
        center.addObserver(
            self,
            selector: #selector(handleAppEntityChange(_:)),
            name: NSNotification.Name("RClick.AppEntity.Change"),
            object: nil
        )

        // 监听 ActionEntity 变更
        center.addObserver(
            self,
            selector: #selector(handleActionEntityChange(_:)),
            name: NSNotification.Name("RClick.ActionEntity.Change"),
            object: nil
        )

        // 监听 NewFileTypeEntity 变更
        center.addObserver(
            self,
            selector: #selector(handleNewFileTypeEntityChange(_:)),
            name: NSNotification.Name("RClick.NewFileTypeEntity.Change"),
            object: nil
        )

        // 监听 CommonDirEntity 变更
        center.addObserver(
            self,
            selector: #selector(handleCommonDirEntityChange(_:)),
            name: NSNotification.Name("RClick.CommonDirEntity.Change"),
            object: nil
        )
    }

    private func setupFileSystemWatcher() {
        // 监控数据库文件修改
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.suitName
        ) else {
            return
        }

        let databaseURL = containerURL.appendingPathComponent("RClickDatabase.sqlite")

        // 使用 DispatchSourceFileSystemObject 监控文件变化
        let fileDescriptor = open(databaseURL.path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            logger.error("Failed to open database file descriptor")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.handleDatabaseFileChange()
        }

        source.resume()
        logger.info("File system watcher started")
    }

    // MARK: - 数据变更处理

    @objc private func handleAppEntityChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let entityType = userInfo["entityType"] as? String,
              let newVersion = userInfo["version"] as? Int else {
            return
        }

        let currentVersion = dataVersions[entityType] ?? 0

        if newVersion > currentVersion {
            logger.info("AppEntity data changed, refreshing... (version: \(currentVersion) -> \(newVersion))")

            // 重新加载版本
            loadCurrentVersions()

            // 刷新应用列表
            refreshAppsCache()

            // 如果菜单正在显示，触发更新
            triggerMenuUpdate()
        }
    }

    @objc private func handleActionEntityChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let entityType = userInfo["entityType"] as? String,
              let newVersion = userInfo["version"] as? Int else {
            return
        }

        let currentVersion = dataVersions[entityType] ?? 0

        if newVersion > currentVersion {
            logger.info("ActionEntity data changed, refreshing... (version: \(currentVersion) -> \(newVersion))")

            loadCurrentVersions()
            triggerMenuUpdate()
        }
    }

    @objc private func handleNewFileTypeEntityChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let entityType = userInfo["entityType"] as? String,
              let newVersion = userInfo["version"] as? Int else {
            return
        }

        let currentVersion = dataVersions[entityType] ?? 0

        if newVersion > currentVersion {
            logger.info("NewFileTypeEntity data changed, refreshing...")
            loadCurrentVersions()
            triggerMenuUpdate()
        }
    }

    @objc private func handleCommonDirEntityChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let entityType = userInfo["entityType"] as? String,
              let newVersion = userInfo["version"] as? Int else {
            return
        }

        let currentVersion = dataVersions[entityType] ?? 0

        if newVersion > currentVersion {
            logger.info("CommonDirEntity data changed, refreshing...")
            loadCurrentVersions()
            triggerMenuUpdate()
        }
    }

    private func handleDatabaseFileChange() {
        logger.debug("Database file changed, checking for updates...")

        // 防抖处理：延迟100ms再检查
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.checkAndRefreshData()
        }
    }

    private func checkAndRefreshData() {
        guard let context = modelContext else { return }

        // 检查版本号是否有变化
        let descriptor = FetchDescriptor<DataVersion>()
        let versions = (try? context.fetch(descriptor)) ?? []

        var hasChanges = false

        for version in versions {
            let oldVersion = dataVersions[version.key] ?? 0
            if version.version > oldVersion {
                logger.info("Version changed for \(version.key): \(oldVersion) -> \(version.version)")
                dataVersions[version.key] = version.version
                hasChanges = true
            }
        }

        if hasChanges {
            logger.info("Data changes detected, refreshing cache...")
            refreshAllCaches()
            triggerMenuUpdate()
        }
    }

    private func refreshAllCaches() {
        refreshAppsCache()
        // 刷新其他缓存...
    }

    private func refreshAppsCache() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<AppEntity>()
        guard let apps = try? context.fetch(descriptor) else {
            return
        }

        // 预加载图标
        let urls = apps.compactMap { URL(fileURLWithPath: $0.urlString) }
        IconCache.shared.preloadIcons(for: urls)

        logger.info("Apps cache refreshed, count: \(apps.count)")
    }

    private func triggerMenuUpdate() {
        // FinderSync 不支持手动刷新菜单
        // 但我们可以标记需要更新，下次 menu(for:) 调用时会生效
        logger.info("Menu update triggered")
    }

    // MARK: - 菜单创建（使用最新数据）

    @objc func createActionMenuItems() -> [NSMenuItem] {
        guard let context = modelContext else {
            logger.warning("ModelContext not available")
            return []
        }

        let descriptor = FetchDescriptor<ActionEntity>()
        guard let actions = try? context.fetch(descriptor) else {
            return []
        }

        return actions
            .filter { $0.isEnabled }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { action in
                let menuItem = NSMenuItem(
                    title: action.name,
                    action: #selector(actioning(_:)),
                    keyEquivalent: ""
                )

                if let icon = NSImage(systemSymbolName: action.icon, accessibilityDescription: action.name) {
                    icon.size = NSSize(width: 16, height: 16)
                    menuItem.image = icon
                }

                let tag = getUniqueTag(for: action.id)
                menuItem.tag = tag

                return menuItem
            }
    }

    @objc func createAppItems() -> [NSMenuItem] {
        guard let context = modelContext else {
            return []
        }

        let descriptor = FetchDescriptor<AppEntity>()
        guard let apps = try? context.fetch(descriptor) else {
            return []
        }

        return apps
            .filter { $0.isEnabled }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { app in
                let menuItem = NSMenuItem(
                    title: app.itemName.isEmpty ? app.url.lastPathComponent : app.itemName,
                    action: #selector(appOpen(_:)),
                    keyEquivalent: ""
                )

                let appIcon = IconCache.shared.icon(for: app.url)
                menuItem.image = appIcon

                let tag = getUniqueTag(for: app.id)
                menuItem.tag = tag

                return menuItem
            }
    }

    private func getUniqueTag(for rid: String) -> Int {
        let tag = nextTag
        nextTag += 1
        tagRidDict[tag] = rid
        return tag
    }
}
```

### 2.3 Main App 写入封装

```swift
// Main App: AppState.swift
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    private let modelContext: ModelContext
    private let writeHandler = DataWriteHandler.shared

    init(inExt: Bool = false) {
        self.modelContext = ModelContext(SharedDataManager.sharedModelContainer)

        Task {
            await refreshData()
        }
    }

    func refreshData() async {
        let appDescriptor = FetchDescriptor<AppEntity>()
        apps = (try? modelContext.fetch(appDescriptor)) ?? []

        let actionDescriptor = FetchDescriptor<ActionEntity>()
        actions = (try? modelContext.fetch(actionDescriptor)) ?? []

        let fileTypeDescriptor = FetchDescriptor<NewFileTypeEntity>()
        newFiles = (try? modelContext.fetch(fileTypeDescriptor)) ?? []

        let commonDirDescriptor = FetchDescriptor<CommonDirEntity>()
        commonDirs = (try? modelContext.fetch(commonDirDescriptor)) ?? []

        let permDirDescriptor = FetchDescriptor<PermDir>()
        permDirs = (try? modelContext.fetch(permDirDescriptor)) ?? []
    }

    // 添加应用（带通知）
    func addApp(item: AppEntity) {
        do {
            try writeHandler.writeAndNotify(
                item,
                context: modelContext,
                notificationName: "RClick.AppEntity.Change"
            )

            // 刷新本地数据
            await refreshData()

            logger.info("App added and notification sent: \(item.id)")
        } catch {
            logger.error("Failed to add app: \(error)")
        }
    }

    // 删除应用（带通知）
    func deleteApp(id: String) {
        let descriptor = FetchDescriptor<AppEntity>(
            predicate: #predicate { $0.id == id }
        )

        guard let app = try? modelContext.fetch(descriptor).first else { return }

        do {
            // 标记删除（软删除）
            app.isEnabled = false
            app.updatedAt = Date()

            try writeHandler.writeAndNotify(
                app,
                context: modelContext,
                notificationName: "RClick.AppEntity.Change"
            )

            await refreshData()

            logger.info("App deleted and notification sent: \(id)")
        } catch {
            logger.error("Failed to delete app: \(error)")
        }
    }

    // 更新应用（带通知）
    func updateApp(
        id: String,
        itemName: String,
        arguments: [String],
        environment: [String: String]
    ) {
        let descriptor = FetchDescriptor<AppEntity>(
            predicate: #predicate { $0.id == id }
        )

        guard let app = try? modelContext.fetch(descriptor).first else { return }

        app.itemName = itemName
        app.argumentsData = try? JSONEncoder().encode(arguments)
        app.environmentData = try? JSONEncoder().encode(environment)
        app.updatedAt = Date()

        do {
            try writeHandler.writeAndNotify(
                app,
                context: modelContext,
                notificationName: "RClick.AppEntity.Change"
            )

            await refreshData()

            logger.info("App updated and notification sent: \(id)")
        } catch {
            logger.error("Failed to update app: \(error)")
        }
    }

    // 类似的方法用于 actions, newFiles, commonDirs...
}
```

## 三、优化策略

### 3.1 批量写入优化

```swift
extension DataWriteHandler {
    @MainActor
    func writeBatchAndNotify<T: PersistentModel>(
        _ items: [T],
        context: ModelContext,
        notificationName: String
    ) throws {
        // 只更新一次版本号
        updateVersion(for: NSStringFromClass(type(of: T.self)), context: context)

        // 批量插入
        for item in items {
            context.insert(item)
        }

        try context.save()

        // 发送单个通知
        let version = getCurrentVersion(
            for: NSStringFromClass(type(of: T.self)),
            context: context
        )

        let payload: [String: Any] = [
            "entityType": NSStringFromClass(type(of: T.self)),
            "action": "batchUpdate",
            "count": items.count,
            "version": version,
            "timestamp": Date().timeIntervalSince1970
        ]

        DistributedNotificationCenter.default().post(
            name: NSNotification.Name(notificationName),
            object: nil,
            userInfo: payload
        )
    }
}
```

### 3.2 防抖和节流

```swift
// Extension: DebouncedRefresh.swift
class DebouncedRefresh {
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval
    private let queue: DispatchQueue

    init(delay: TimeInterval = 0.5) {
        self.delay = delay
        self.queue = DispatchQueue.main
    }

    func debounce(action: @escaping () -> Void) {
        // 取消之前的任务
        workItem?.cancel()

        // 创建新任务
        workItem = DispatchWorkItem(block: action)

        // 延迟执行
        queue.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

// 在 FinderSyncExt 中使用
class FinderSyncExt: FIFinderSync {
    private let debouncedRefresh = DebouncedRefresh(delay: 0.3)

    @objc private func handleDatabaseFileChange() {
        // 防抖处理，避免频繁刷新
        debouncedRefresh.debounce { [weak self] in
            self?.checkAndRefreshData()
        }
    }
}
```

### 3.3 心跳检测和自动重连

```swift
// Extension: ConnectionMonitor.swift
class ConnectionMonitor {
    static let shared = ConnectionMonitor()

    private var heartbeatTimer: Timer?
    private var lastHeartbeat: Date = Date()
    private let heartbeatInterval: TimeInterval = 5.0

    func startMonitoring() {
        heartbeatTimer = Timer.scheduledTimer(
            withTimeInterval: heartbeatInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkConnection()
        }

        // 监听 Main App 的心跳响应
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleHeartbeatResponse),
            name: NSNotification.Name("RClick.Heartbeat.Response"),
            object: nil
        )
    }

    private func checkConnection() {
        // 发送心跳请求
        DistributedNotificationCenter.default().post(
            name: NSNotification.Name("RClick.Heartbeat.Request"),
            object: nil
        )

        // 检查超时
        if Date().timeIntervalSince(lastHeartbeat) > heartbeatInterval * 2 {
            logger.warning("Main app heartbeat timeout, triggering data refresh...")
            NotificationCenter.default.post(
                name: NSNotification.Name("RClick.Connection.Lost"),
                object: nil
            )
        }
    }

    @objc private func handleHeartbeatResponse(_ notification: Notification) {
        lastHeartbeat = Date()
    }
}
```

## 四、性能考虑

### 4.1 懒加载策略

```swift
// Extension: LazyDataManager.swift
class LazyDataManager {
    private var appsCache: [AppEntity]?
    private var actionsCache: [ActionEntity]?
    private var lastAppsFetch: Date?
    private var lastActionsFetch: Date?
    private let cacheValidDuration: TimeInterval = 60.0  // 缓存1分钟

    func getApps(context: ModelContext) -> [AppEntity] {
        // 检查缓存是否有效
        if let cached = appsCache,
           let lastFetch = lastAppsFetch,
           Date().timeIntervalSince(lastFetch) < cacheValidDuration {
            return cached
        }

        // 从数据库重新加载
        let descriptor = FetchDescriptor<AppEntity>()
        let apps = (try? context.fetch(descriptor)) ?? []

        appsCache = apps
        lastAppsFetch = Date()

        return apps
    }

    func invalidateCache() {
        appsCache = nil
        actionsCache = nil
        lastAppsFetch = nil
        lastActionsFetch = nil
    }
}
```

### 4.2 部分刷新

```swift
// 只刷新变更的实体类型
extension FinderSyncExt {
    @objc private func handleAppEntityChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let entityId = userInfo["entityId"] as? String else {
            return
        }

        // 只刷新单个应用，而非全部
        refreshSingleApp(id: entityId)
    }

    private func refreshSingleApp(id: String) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<AppEntity>(
            predicate: #predicate { $0.id == id }
        )

        if let app = try? context.fetch(descriptor).first {
            // 预加载单个应用的图标
            IconCache.shared.icon(for: app.url)

            logger.info("Single app refreshed: \(app.itemName)")
        }
    }
}
```

## 五、错误处理和降级

### 5.1 连接失败降级

```swift
// Extension: FallbackDataManager.swift
class FallbackDataManager {
    static let shared = FallbackDataManager()

    private var cachedData: [String: Any] = [:]

    func getCachedApps() -> [AppEntity] {
        return cachedData["apps"] as? [AppEntity] ?? []
    }

    func updateCache(apps: [AppEntity]) {
        cachedData["apps"] = apps
    }

    func isExtensionDisconnected() -> Bool {
        // 检查是否可以访问数据库
        do {
            let container = try SharedDataManager.sharedModelContainer
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<AppEntity>()
            _ = try context.fetch(descriptor)
            return false
        } catch {
            return true
        }
    }
}

// 在 FinderSyncExt 中使用
extension FinderSyncExt {
    @objc func createActionMenuItems() -> [NSMenuItem] {
        // 优先尝试从 SwiftData 读取
        if let context = modelContext,
           let actions = try? context.fetch(FetchDescriptor<ActionEntity>()),
           !actions.isEmpty {
            return buildMenuItems(from: actions)
        }

        // 降级到缓存数据
        logger.warning("SwiftData unavailable, using cached data")
        let fallbackActions = FallbackDataManager.shared.getCachedActions()
        return buildMenuItems(from: fallbackActions)
    }
}
```

## 六、总结

### 6.1 关键点
1. ✅ **版本控制**: 使用 DataVersion 模型追踪变更
2. ✅ **通知机制**: DistributedNotificationCenter 实时通知
3. ✅ **文件监控**: DispatchSource 监控数据库文件变化
4. ✅ **防抖优化**: 避免频繁刷新
5. ✅ **降级策略**: 数据不可用时使用缓存

### 6.2 数据流
```
Main App                          Extension
   │                                  │
   ├─ 写入数据                        │
   ├─ 更新版本号                      │
   ├─ 发送通知 ───────────────────>  ├─ 接收通知
   │                                  ├─ 对比版本号
   │                                  ├─ 重新加载数据
   │                                  ├─ 刷新菜单缓存
   │                                  │
   ├─ SQLite 文件写入 ─────────────>  ├─ DispatchSource 检测
   │                                  ├─ 防抖检查
   │                                  ├─ 刷新数据
```

### 6.3 性能指标
- **通知延迟**: < 50ms
- **数据刷新**: < 100ms
- **菜单重建**: < 200ms
- **内存占用**: Extension < 50MB
