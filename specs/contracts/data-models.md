# RClick 数据模型设计

> 最后更新：2026-03-21
> 状态：设计规范
> 基于：SwiftData + 瘦 Extension 架构

---

## 一、概述

### 1.1 架构调整：完全磁盘访问权限

由于采用**完全磁盘访问权限**（用户手动授权），不再需要 Bookmark 缓存机制。

| 之前的设计 | 当前设计 |
|-----------|---------|
| PermissiveDir + Bookmark 缓存 | 不需要，依赖完全磁盘访问权限 |
| 按需请求权限 | 一次性授权，全盘访问 |

### 1.2 模型分类

| 模型类别 | 用途 | 存储方式 |
|---------|------|---------|
| **应用模型** | 外部应用程序配置 | SwiftData |
| **动作模型** | 右键菜单动作配置 | SwiftData |
| **文件类型模型** | 新建文件模板配置 | SwiftData |
| **目录模型** | 常用目录配置 | SwiftData |
| **内存模型** | 运行时数据表示 | 纯 Swift 结构 |
| **消息模型** | 进程间通信数据传输 | Codable 协议 |

### 1.3 设计原则

1. **SwiftData 模型**：只存储配置数据，@Model 标记
2. **内存模型**：RCBase 协议，运行时使用
3. **消息模型**：Codable 协议，IPC 通信使用
4. **模型转换**：SwiftData ↔ 内存模型 ↔ 消息模型

### 1.4 模型关系图

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  SwiftData 模型   │ <-> │  内存模型 (RCBase) │ <-> │  消息模型        │
│  (持久化存储)     │     │  (运行时使用)     │     │  (IPC 通信)       │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ AppEntity       │     │ OpenWithApp     │     │ AppMenuItem     │
│ ActionEntity    │     │ RCAction        │     │ ActionMenuItem  │
│ NewFileTypeEntity│    │ NewFile         │     │ NewFileMenuItem │
│ CommonDirEntity │     │ CommonDir       │     │ CommonDirMenuItem│
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## 二、SwiftData 持久化模型

### 简化设计原则

1. **移除 Data 字段**：直接用 SwiftData 的 @Relationship 或 @Attribute 存储
2. **移除时间戳**：配置数据不需要 createdAt/updatedAt
3. **移除 PermissiveDir**：完全磁盘访问权限无需 Bookmark

### 模型简化对比

| 属性 | 之前设计 | 简化后设计 |
|------|---------|-----------|
| 复杂数据 | `argumentsData: Data?` | `arguments: [String]` (SwiftData 6.0+ 支持) |
| 时间戳 | `createdAt`, `updatedAt` | 移除 |
| Bookmark | `PermissiveDir` | 移除 |
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
}
```

#### 预定义文件类型

```swift
extension NewFileTypeEntity {
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

---

### 2.4 常用目录实体（CommonDirEntity）

存储快速访问目录配置。

```swift
import SwiftData
import Foundation

/// 常用目录实体 - 用于存储快速访问目录
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
        get { URL(fileURLWithPath: pathString) }
        set { pathString = newValue.path() }
    }
}
```

#### 预定义常用目录

```swift
extension CommonDirEntity {
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

---

## 三、基础协议和模型（RCBase）

### 3.1 基础协议

```swift
/// 所有数据模型的基础协议
protocol RCBase: Hashable, Identifiable, Codable {
    var id: String { get }
}
```

### 3.2 打开应用（OpenWithApp）

用于内存中的应用表示，可转换为 AppEntity。

```swift
struct OpenWithApp: RCBase {
    var id: String
    var url: URL
    var itemName: String
    var inheritFromGlobalArguments: Bool
    var inheritFromGlobalEnvironment: Bool
    var arguments: [String]
    var environment: [String: String]

    var appName: String {
        FileManager.default.displayName(atPath: url.path)
    }

    var name: String {
        itemName.isEmpty ? appName : itemName
    }

    init(id: String = UUID().uuidString, appURL url: URL) {
        self.id = id
        self.url = url
        self.itemName = url.deletingPathExtension().lastPathComponent
    }
}

extension OpenWithApp {
    init?(bundleIdentifier identifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            return nil
        }
        self.init(appURL: url)
    }

    static let vscode = OpenWithApp(bundleIdentifier: "com.microsoft.VSCode")
    static let terminal = OpenWithApp(bundleIdentifier: "com.apple.Terminal")
    static var defaultApps: [OpenWithApp] { [.terminal, .vscode].compactMap { $0 } }
}
```

### 3.3 动作（RCAction）

```swift
struct RCAction: RCBase {
    var id: String
    var name: String
    var enabled: Bool
    var idx: Int
    var icon: String

    init(id: String, name: String, enabled: Bool = true, idx: Int, icon: String) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.idx = idx
        self.icon = icon
    }
}

extension RCAction {
    static let copyPath = RCAction(id: "copy-path", name: "Copy Path", idx: 0, icon: "doc.on.doc")
    static let deleteDirect = RCAction(id: "delete-direct", name: "Delete Direct", idx: 1, icon: "trash")
    static let hideFileDir = RCAction(id: "hide", name: "Hide", idx: 2, icon: "eye.slash")
    static let unhideFileDir = RCAction(id: "unhide", name: "Unhide", idx: 3, icon: "eye")
    static let airdrop = RCAction(id: "airdrop", name: "AirDrop", idx: 4, icon: "paperplane")

    static var all: [RCAction] = [.copyPath, .deleteDirect, .airdrop, .hideFileDir, .unhideFileDir]
}
```

### 3.4 新建文件（NewFile）

```swift
struct NewFile: RCBase {
    var ext: String
    var name: String
    var enabled: Bool
    var idx: Int
    var icon: String
    var id: String
    var openApp: URL?
    var template: URL?

    init(ext: String, name: String, enabled: Bool = true, idx: Int, icon: String = "document", id: String = UUID().uuidString) {
        self.ext = ext
        self.name = name
        self.enabled = enabled
        self.idx = idx
        self.icon = icon
        self.id = id
    }
}

extension NewFile {
    static var all: [NewFile] = [.txt, .md, .json, .docx, .pptx, .xlsx]

    static let json = NewFile(ext: ".json", name: "JSON", idx: 0, icon: "icon-file-json")
    static let txt = NewFile(ext: ".txt", name: "TXT", idx: 1, icon: "icon-file-txt")
    static let md = NewFile(ext: ".md", name: "Markdown", idx: 2, icon: "icon-file-md")
    static let docx = NewFile(ext: ".docx", name: "DOCX", idx: 3, icon: "icon-file-docx")
    static let pptx = NewFile(ext: ".pptx", name: "PPTX", idx: 4, icon: "icon-file-pptx")
    static let xlsx = NewFile(ext: ".xlsx", name: "XLSX", idx: 5, icon: "icon-file-xlsx")
}
```

### 3.5 常用目录（CommonDir）

```swift
struct CommonDir: RCBase {
    var id: String
    var name: String
    var url: URL
    var icon: String

    init(id: String, name: String, url: URL, icon: String) {
        self.id = id
        self.name = name
        self.url = url
        self.icon = icon
    }
}
```

---

## 四、消息传输模型（Codable）

这些模型用于主程序和 Extension 之间的通信，不持久化。

### 4.1 动作菜单项（ActionMenuItem）

```swift
/// Menu item for custom actions (copy path, delete, etc.)
struct ActionMenuItem: Codable {
    let id: String
    let name: String
    let icon: String
    let enabled: Bool

    init(id: String, name: String, icon: String, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.icon = icon
        self.enabled = enabled
    }
}
```

### 4.2 应用菜单项（AppMenuItem）

```swift
/// Menu item for opening files with external applications
struct AppMenuItem: Codable {
    let id: String
    let name: String
    let appURL: URL  // Extension 根据路径加载图标

    init(id: String, name: String, appURL: URL) {
        self.id = id
        self.name = name
        self.appURL = appURL
    }
}
```

### 4.3 新建文件菜单项（NewFileMenuItem）

```swift
/// Menu item for creating new files
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
```

### 4.4 常用目录菜单项（CommonDirMenuItem）

```swift
/// Menu item for common directories
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
```

---

## 五、模型转换

### 5.1 SwiftData → Codable（用于发送菜单配置）

```swift
extension ActionEntity {
    func toMenuItem() -> ActionMenuItem {
        ActionMenuItem(
            id: id,
            name: name,
            icon: icon,
            enabled: isEnabled
        )
    }
}

extension AppEntity {
    func toMenuItem() -> AppMenuItem {
        AppMenuItem(
            id: id,
            name: itemName.isEmpty ? url.lastPathComponent : itemName,
            appURL: url
        )
    }
}

extension NewFileTypeEntity {
    func toMenuItem() -> NewFileMenuItem {
        NewFileMenuItem(
            id: id,
            name: name,
            ext: fileExtension,
            icon: icon
        )
    }
}

extension CommonDirEntity {
    func toMenuItem() -> CommonDirMenuItem {
        CommonDirMenuItem(
            id: id,
            name: name,
            icon: icon
        )
    }
}
```

### 5.2 RCBase → SwiftData（用于保存配置）

```swift
extension AppEntity {
    convenience init(from openWithApp: OpenWithApp, sortOrder: Int = 0) {
        self.init(
            id: openWithApp.id,
            url: openWithApp.url,
            itemName: openWithApp.name,
            inheritFromGlobalArguments: openWithApp.inheritFromGlobalArguments,
            inheritFromGlobalEnvironment: openWithApp.inheritFromGlobalEnvironment,
            arguments: openWithApp.arguments,
            environment: openWithApp.environment,
            sortOrder: sortOrder
        )
    }
}

extension ActionEntity {
    convenience init(from action: RCAction) {
        self.init(
            id: action.id,
            name: action.name,
            icon: action.icon,
            isEnabled: action.enabled,
            sortOrder: action.idx
        )
    }
}

extension NewFileTypeEntity {
    convenience init(from newFile: NewFile) {
        self.init(
            id: newFile.id,
            fileExtension: newFile.ext,
            name: newFile.name,
            icon: newFile.icon,
            isEnabled: newFile.enabled,
            sortOrder: newFile.idx
        )
    }
}

extension CommonDirEntity {
    convenience init(from commonDir: CommonDir) {
        self.init(
            id: commonDir.id,
            name: commonDir.name,
            path: commonDir.url,
            icon: commonDir.icon
        )
    }
}
```

---

## 六、Bookmark 缓存管理

### 6.1 BookmarkManager

```swift
import Foundation

/// Bookmark 管理器 - 缓存用户授权的文件夹访问权限
actor BookmarkManager {
    static let shared = BookmarkManager()

    private var bookmarks: [String: Data] = [:]  // path -> bookmark data
    private let userDefaultsKey = "FolderBookmarks"

    private init() {
        loadBookmarks()
    }

    /// 加载保存的 bookmarks
    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([String: Data].self, from: data) {
            bookmarks = decoded
        }
    }

    /// 保存 bookmarks 到持久化存储
    private func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    /// 为 URL 创建 bookmark
    func createBookmark(for url: URL) throws -> Data {
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        bookmarks[url.path] = bookmark
        saveBookmarks()
        return bookmark
    }

    /// 从 bookmark 恢复 URL 访问
    func restoreAccess(from bookmark: Data, for path: String) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        // 如果 bookmark 已过期，尝试更新
        if isStale, let freshBookmark = try? createBookmark(for: url) {
            bookmarks[path] = freshBookmark
            saveBookmarks()
        }

        return url
    }

    /// 获取 URL 的 bookmark（如果存在）
    func getBookmark(for path: String) -> Data? {
        return bookmarks[path]
    }

    /// 删除 bookmark
    func removeBookmark(for path: String) {
        bookmarks.removeValue(forKey: path)
        saveBookmarks()
    }

    /// 访问授权的文件（自动管理 security scope）
    func accessFile<T>(at path: String, operation: (URL) throws -> T) -> T? {
        guard let bookmark = bookmarks[path],
              let url = restoreAccess(from: bookmark, for: path) else {
            return nil
        }

        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        return try? operation(url)
    }
}
```

---

## 七、数据持久化配置

### 7.1 SwiftData 容器

```swift
import SwiftData

final class SharedDataManager {
    static let shared = SharedDataManager()

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppEntity.self,
            ActionEntity.self,
            NewFileTypeEntity.self,
            CommonDirEntity.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
```

### 7.2 应用组配置

为了让 Extension 也能访问数据（虽然在本架构中 Extension 不直接读取），使用应用组共享容器：

```swift
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    containerIdentifier: "group.cn.wflixu.RClick"  // App Group ID
)
```

---

## 八、参考文档

- **重构设计**: [../重构设计.md](../重构设计.md)
- **通信协议**: [communication-protocol.md](communication-protocol.md)
- **RCBase 实现**: [../../RClick/Model/RCBase.swift](../../RClick/Model/RCBase.swift)
- **SwiftData 实体**: [../../RClick/Model/](../../RClick/Model/)
