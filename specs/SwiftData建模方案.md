# SwiftData 建模方案

## 一、当前状态分析

### 1.1 现有模型
- ✅ **PermDir**: 已使用 `@Model`
- ❌ **OpenWithApp**: 普通 Struct，存储在 UserDefaults
- ❌ **RCAction**: 普通 Struct，存储在 UserDefaults
- ❌ **NewFile**: 普通 Struct，存储在 UserDefaults
- ❌ **CommonDir**: 普通 Struct，存储在 UserDefaults

### 1.2 数据存储策略
```
当前（双轨制）：
- SwiftData: PermDir
- UserDefaults: OpenWithApp[], RCAction[], NewFile[], CommonDir[], PermissiveDir[]

目标（统一SwiftData）：
- SwiftData: 所有数据模型
- UserDefaults: 仅存储配置项（showMenuBarExtra, copyOption等）
```

## 二、SwiftData 模型设计

### 2.1 核心模型定义

#### 模型1: AppEntity (应用实体)
```swift
import SwiftData
import Foundation

@Model
final class AppEntity {
    @Attribute(.unique) var id: String
    var urlString: String  // 存储为String，SwiftData对URL支持有限
    var itemName: String
    var inheritFromGlobalArguments: Bool
    var inheritFromGlobalEnvironment: Bool
    var argumentsData: Data?  // 编码后的数组
    var environmentData: Data? // 编码后的字典
    var sortOrder: Int
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         url: URL,
         itemName: String = "",
         inheritFromGlobalArguments: Bool = true,
         inheritFromGlobalEnvironment: Bool = true,
         arguments: [String] = [],
         environment: [String: String] = [:],
         sortOrder: Int = 0,
         isEnabled: Bool = true) {
        self.id = id
        self.urlString = url.path()
        self.itemName = itemName
        self.inheritFromGlobalArguments = inheritFromGlobalArguments
        self.inheritFromGlobalEnvironment = inheritFromGlobalEnvironment
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.updatedAt = Date()

        // 编码复杂数据
        self.argumentsData = try? JSONEncoder().encode(arguments)
        self.environmentData = try? JSONEncoder().encode(environment)
    }

    // 计算属性：从存储的数据解码
    var url: URL {
        URL(fileURLWithPath: urlString)
    }

    var arguments: [String] {
        guard let data = argumentsData,
              let args = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return args
    }

    var environment: [String: String] {
        guard let data = environmentData,
              let env = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return env
    }
}
```

#### 模型2: ActionEntity (动作实体)
```swift
@Model
final class ActionEntity {
    @Attribute(.unique) var id: String
    var name: String
    var icon: String
    var isEnabled: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         name: String,
         icon: String,
         isEnabled: Bool = true,
         sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // 预定义动作的工厂方法
    static func createDefaultActions() -> [ActionEntity] {
        return [
            ActionEntity(id: "copy-path", name: "复制路径", icon: "doc.on.doc", sortOrder: 0),
            ActionEntity(id: "copy-filename", name: "复制文件名", icon: "doc.text", sortOrder: 1),
            ActionEntity(id: "reveal", name: "在Finder中显示", icon: "folder", sortOrder: 2),
            ActionEntity(id: "airdrop", name: "AirDrop", icon: "paperplane", sortOrder: 3),
            ActionEntity(id: "delete", name: "删除", icon: "trash", sortOrder: 4),
            ActionEntity(id: "hide", name: "隐藏", icon: "eye.slash", sortOrder: 5),
            ActionEntity(id: "unhide", name: "显示", icon: "eye", sortOrder: 6),
        ]
    }
}
```

#### 模型3: NewFileTypeEntity (新建文件类型实体)
```swift
@Model
final class NewFileTypeEntity {
    @Attribute(.unique) var id: String
    var fileExtension: String
    var name: String
    var icon: String
    var isEnabled: Bool
    var sortOrder: Int
    var templatePath: String?
    var openAppPath: String?
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         fileExtension: String,
         name: String,
         icon: String = "doc",
         isEnabled: Bool = true,
         sortOrder: Int = 0,
         templatePath: String? = nil,
         openAppPath: String? = nil) {
        self.id = id
        self.fileExtension = fileExtension
        self.name = name
        self.icon = icon
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.templatePath = templatePath
        self.openAppPath = openAppPath
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // 预定义文件类型的工厂方法
    static func createDefaultFileTypes() -> [NewFileTypeEntity] {
        return [
            NewFileTypeEntity(id: "txt", fileExtension: ".txt", name: "TXT", icon: "icon-file-txt", sortOrder: 0),
            NewFileTypeEntity(id: "md", fileExtension: ".md", name: "Markdown", icon: "icon-file-md", sortOrder: 1),
            NewFileTypeEntity(id: "json", fileExtension: ".json", name: "JSON", icon: "icon-file-json", sortOrder: 2),
            NewFileTypeEntity(id: "docx", fileExtension: ".docx", name: "DOCX", icon: "icon-file-docx", sortOrder: 3),
            NewFileTypeEntity(id: "xlsx", fileExtension: ".xlsx", name: "XLSX", icon: "icon-file-xlsx", sortOrder: 4),
            NewFileTypeEntity(id: "pptx", fileExtension: ".pptx", name: "PPTX", icon: "icon-file-pptx", sortOrder: 5),
        ]
    }
}
```

#### 模型4: CommonDirEntity (常用目录实体)
```swift
@Model
final class CommonDirEntity {
    @Attribute(.unique) var id: String
    var name: String
    var pathString: String
    var icon: String
    var sortOrder: Int
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         name: String,
         path: URL,
         icon: String = "folder",
         sortOrder: Int = 0,
         isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.pathString = path.path()
        self.icon = icon
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var path: URL {
        URL(fileURLWithPath: pathString)
    }

    // 预定义常用目录的工厂方法
    static func createDefaultCommonDirs() -> [CommonDirEntity] {
        let fileManager = FileManager.default
        var dirs: [CommonDirEntity] = []

        let homeDir = fileManager.homeDirectoryForCurrentUser
        let desktop = homeDir.appendingPathComponent("Desktop")
        let documents = homeDir.appendingPathComponent("Documents")
        let downloads = homeDir.appendingPathComponent("Downloads")

        dirs.append(CommonDirEntity(id: "desktop", name: "桌面", path: desktop, icon: "desktopcomputer", sortOrder: 0))
        dirs.append(CommonDirEntity(id: "documents", name: "文档", path: documents, icon: "doc.folder", sortOrder: 1))
        dirs.append(CommonDirEntity(id: "downloads", name: "下载", path: downloads, icon: "arrow.down.circle", sortOrder: 2))
        dirs.append(CommonDirEntity(id: "applications", name: "应用程序", path: URL(fileURLWithPath: "/Applications"), icon: "app", sortOrder: 3))
        dirs.append(CommonDirEntity(id: "home", name: "用户主目录", path: homeDir, icon: "house", sortOrder: 4))

        return dirs
    }
}
```

#### 模型5: PermDir (保持不变，已正确配置)
```swift
@Model
final class PermDir {
    @Attribute(.unique) var id: String
    var urlString: String
    var bookmark: Data
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, url: URL, bookmark: Data) {
        self.id = id
        self.urlString = url.path()
        self.bookmark = bookmark
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var url: URL {
        URL(fileURLWithPath: urlString)
    }
}
```

### 2.2 更新 ModelContainer 配置

```swift
// SharedDataManager.swift
import SwiftData
import Foundation

class SharedDataManager {
    static let appGroupIdentifier = Constants.suitName

    static var sharedModelContainer: ModelContainer = {
        do {
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            ) else {
                fatalError("无法获取 App Group 共享目录: \(appGroupIdentifier)")
            }

            let storeURL = containerURL.appendingPathComponent("RClickDatabase.sqlite")

            let configuration = ModelConfiguration(
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )

            // 注册所有模型
            let container = try ModelContainer(
                for: AppEntity.self,
                     ActionEntity.self,
                     NewFileTypeEntity.self,
                     CommonDirEntity.self,
                     PermDir.self,
                configurations: configuration
            )

            return container
        } catch {
            fatalError("创建共享 ModelContainer 失败: \(error)")
        }
    }()

    /// 初始化默认数据
    static func initializeDefaultData(context: ModelContext) async {
        // 检查是否已有数据
        let actionDescriptor = FetchDescriptor<ActionEntity>()
        let actionCount = try? context.fetchCount(actionDescriptor) ?? 0

        if actionCount == 0 {
            // 插入默认动作
            for action in ActionEntity.createDefaultActions() {
                context.insert(action)
            }
        }

        let fileTypeDescriptor = FetchDescriptor<NewFileTypeEntity>()
        let fileTypeCount = try? context.fetchCount(fileTypeDescriptor) ?? 0

        if fileTypeCount == 0 {
            // 插入默认文件类型
            for fileType in NewFileTypeEntity.createDefaultFileTypes() {
                context.insert(fileType)
            }
        }

        let commonDirDescriptor = FetchDescriptor<CommonDirEntity>()
        let commonDirCount = try? context.fetchCount(commonDirDescriptor) ?? 0

        if commonDirCount == 0 {
            // 插入默认常用目录
            for dir in CommonDirEntity.createDefaultCommonDirs() {
                context.insert(dir)
            }
        }

        try? context.save()
    }
}
```

## 三、Extension 集成方案

### 3.1 Extension 中的 ModelContext 初始化

```swift
// FinderSyncExt.swift
@MainActor
class FinderSyncExt: FIFinderSync {
    private var modelContext: ModelContext?
    private var nextTag: Int = 1
    private var tagRidDict: [Int: String] = [:]
    var isHostAppOpen = false
    var isDataReady = false

    override init() {
        super.init()

        // 初始化 SwiftData
        do {
            let container = try SharedDataManager.sharedModelContainer
            modelContext = ModelContext(container)
            isDataReady = true

            // 异步初始化默认数据
            Task {
                await SharedDataManager.initializeDefaultData(context: modelContext!)
            }

            logger.info("SwiftData context initialized successfully")
        } catch {
            logger.error("Failed to initialize SwiftData context: \(error)")
            isDataReady = false
        }

        // 注册消息监听
        setupMessageHandlers()
    }

    private func setupMessageHandlers() {
        Messager.shared.on(name: Key.messageFromMain) { [weak self] payload in
            guard let self = self else { return }

            switch payload.action {
            case .running:
                self.isHostAppOpen = true
                self.refreshMenuCache()
            default:
                break
            }
        }
    }

    private func refreshMenuCache() {
        guard let context = modelContext else { return }

        // 预加载应用图标
        let appDescriptor = FetchDescriptor<AppEntity>()
        if let apps = try? context.fetch(appDescriptor) {
            let urls = apps.compactMap { URL(fileURLWithPath: $0.urlString) }
            IconCache.shared.preloadIcons(for: urls)
        }
    }

    @objc func createActionMenuItems() -> [NSMenuItem] {
        guard let context = modelContext, isDataReady else {
            logger.warning("SwiftData context not ready")
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
        guard let context = modelContext, isDataReady else {
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

## 四、数据迁移策略

### 4.1 迁移工具

```swift
// DataMigrationManager.swift
import SwiftData

class DataMigrationManager {
    static let shared = DataMigrationManager()

    @MainActor
    func migrateFromUserDefaults(context: ModelContext) async throws {
        // 1. 迁移 OpenWithApp -> AppEntity
        if let appData = UserDefaults.group.data(forKey: Key.apps) {
            let apps = try JSONDecoder().decode([OpenWithApp].self, from: appData)

            for app in apps {
                let entity = AppEntity(
                    id: app.id,
                    url: app.url,
                    itemName: app.itemName,
                    inheritFromGlobalArguments: app.inheritFromGlobalArguments,
                    inheritFromGlobalEnvironment: app.inheritFromGlobalEnvironment,
                    arguments: app.arguments,
                    environment: app.environment
                )
                context.insert(entity)
            }

            // 清除旧数据
            UserDefaults.group.removeObject(forKey: Key.apps)
        }

        // 2. 迁移 RCAction -> ActionEntity
        if let actionData = UserDefaults.group.data(forKey: Key.actions) {
            let actions = try JSONDecoder().decode([RCAction].self, from: actionData)

            for action in actions {
                let entity = ActionEntity(
                    id: action.id,
                    name: action.name,
                    icon: action.icon,
                    isEnabled: action.enabled,
                    sortOrder: action.idx
                )
                context.insert(entity)
            }

            UserDefaults.group.removeObject(forKey: Key.actions)
        }

        // 3. 迁移 NewFile -> NewFileTypeEntity
        if let fileTypeData = UserDefaults.group.data(forKey: Key.fileTypes) {
            let fileTypes = try JSONDecoder().decode([NewFile].self, from: fileTypeData)

            for fileType in fileTypes {
                let entity = NewFileTypeEntity(
                    id: fileType.id,
                    fileExtension: fileType.ext,
                    name: fileType.name,
                    icon: fileType.icon,
                    isEnabled: fileType.enabled,
                    sortOrder: fileType.idx
                )
                context.insert(entity)
            }

            UserDefaults.group.removeObject(forKey: Key.fileTypes)
        }

        // 4. 迁移 CommonDir -> CommonDirEntity
        if let commonDirData = UserDefaults.group.data(forKey: Key.commonDirs) {
            let dirs = try JSONDecoder().decode([CommonDir].self, from: commonDirData)

            for dir in dirs {
                let entity = CommonDirEntity(
                    id: dir.id,
                    name: dir.name,
                    path: dir.url,
                    icon: dir.icon
                )
                context.insert(entity)
            }

            UserDefaults.group.removeObject(forKey: Key.commonDirs)
        }

        // 保存所有更改
        try context.save()

        logger.info("数据迁移完成")
    }

    /// 检查是否需要迁移
    func needsMigration() -> Bool {
        return UserDefaults.group.data(forKey: Key.apps) != nil
    }
}
```

### 4.2 App 启动时执行迁移

```swift
// RClickApp.swift
func applicationDidFinishLaunching(_ aNotification: Notification) {
    // ... 其他初始化代码

    // 执行数据迁移
    Task { @MainActor in
        do {
            if DataMigrationManager.shared.needsMigration() {
                let context = ModelContext(SharedDataManager.sharedModelContainer)
                try await DataMigrationManager.shared.migrateFromUserDefaults(context: context)
            }
        } catch {
            logger.error("数据迁移失败: \(error)")
        }
    }

    // ...
}
```

## 五、迁移后的 AppState 简化

```swift
// AppState.swift
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var apps: [AppEntity] = []
    @Published var actions: [ActionEntity] = []
    @Published var newFiles: [NewFileTypeEntity] = []
    @Published var commonDirs: [CommonDirEntity] = []
    @Published var permDirs: [PermDir] = []

    private let modelContext: ModelContext

    init(inExt: Bool = false) {
        self.modelContext = ModelContext(SharedDataManager.sharedModelContainer)

        Task {
            await refreshData()
        }
    }

    func refreshData() async {
        // 从 SwiftData 加载所有数据
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

    // 添加应用
    func addApp(item: AppEntity) {
        modelContext.insert(item)
        try? modelContext.save()
        await refreshData()
    }

    // 删除应用
    func deleteApp(id: String) {
        let descriptor = FetchDescriptor<AppEntity>(
            predicate: #predicate { $0.id == id }
        )

        guard let app = try? modelContext.fetch(descriptor).first else { return }
        modelContext.delete(app)
        try? modelContext.save()
        await refreshData()
    }

    // 更新应用
    func updateApp(id: String, itemName: String, arguments: [String], environment: [String: String]) {
        let descriptor = FetchDescriptor<AppEntity>(
            predicate: #predicate { $0.id == id }
        )

        guard let app = try? modelContext.fetch(descriptor).first else { return }

        app.itemName = itemName
        app.argumentsData = try? JSONEncoder().encode(arguments)
        app.environmentData = try? JSONEncoder().encode(environment)
        app.updatedAt = Date()

        try? modelContext.save()
        await refreshData()
    }

    // 类似的方法用于 actions, newFiles, commonDirs, permDirs...
}
```

## 六、实施步骤

### Phase 1: 创建 SwiftData 模型
1. ✅ 创建 `AppEntity.swift`
2. ✅ 创建 `ActionEntity.swift`
3. ✅ 创建 `NewFileTypeEntity.swift`
4. ✅ 创建 `CommonDirEntity.swift`
5. ✅ 更新 `ModelContainer.swift`

### Phase 2: 实现数据迁移
1. ✅ 创建 `DataMigrationManager.swift`
2. ✅ 在 `RClickApp.swift` 中添加迁移逻辑
3. ✅ 测试迁移过程

### Phase 3: 更新 AppState
1. ✅ 重写 `AppState.swift` 使用 SwiftData
2. ✅ 删除 UserDefaults 相关代码
3. ✅ 更新所有视图和逻辑

### Phase 4: 更新 Extension
1. ✅ 在 `FinderSyncExt.swift` 中初始化 ModelContext
2. ✅ 更新菜单创建方法
3. ✅ 删除 UserDefaults 读取逻辑

### Phase 5: 清理和测试
1. ✅ 删除旧的模型代码
2. ✅ 删除转换层代码
3. ✅ 全面测试

## 七、注意事项

### 7.1 SwiftData 限制
1. **URL 类型**: SwiftData 对 URL 的支持有限，建议存储为 String
2. **复杂数据**: 数组和字典需要编码为 Data
3. **计算属性**: 使用 get 方法而非存储属性

### 7.2 性能优化
1. 使用 `FetchDescriptor` 的 predicate 进行过滤
2. 为常用查询字段添加索引
3. 实现分页加载（如果数据量大）

### 7.3 错误处理
1. 所有 SwiftData 操作都应包裹在 try-catch 中
2. 提供降级方案（如 SwiftData 失败）
3. 记录详细的错误日志

## 八、验证清单

- [ ] 所有模型都能正常插入和查询
- [ ] Extension 能成功读取 SwiftData 数据
- [ ] 数据迁移正确无误
- [ ] 菜单正确显示
- [ ] 配置更新实时生效
- [ ] 没有内存泄漏
- [ ] 日志正常输出
