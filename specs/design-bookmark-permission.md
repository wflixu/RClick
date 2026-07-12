# 设计文档：用 Security-Scoped Bookmark 替代 Full Disk Access

## 一、背景

### 现状

RClick 当前依赖 **Full Disk Access (FDA)** 获取文件系统权限：

| 机制 | 说明 |
|------|------|
| FDA 检测 | `PermissionChecker.hasFullDiskAccess()` 通过读取 `~/Library/Application Support/com.apple.TCC` 来探测 |
| 启动引导 | `checkFDAAndGuideIfNeeded()` 在首次启动时弹 Alert 引导用户去系统设置开启 FDA |
| 沙箱例外 | `com.apple.security.temporary-exception.files.home-relative-path.read-write` = `/`，覆盖 home 目录 |
| 文件操作 | `deleteFoldorFile` / `createFile` / `hideFilesAndDirs` 等直接调用 `FileManager`，无运行时权限检查 |
| 无 bookmark | 代码库中零处使用 `startAccessingSecurityScopedResource` / `bookmarkData` |

### 问题

- FDA 是**全局权限**，用户越来越不愿意授予
- 设置界面的 "Full Disk Access" 行始终显示 `未授权`，用户体验差
- 依赖沙箱例外 entitlement，不是 Apple 推荐的权限模型

### 目标

用 **按需授权 + Security-Scoped Bookmark** 模式替代 FDA。参考 iMonet 项目的模式：操作文件时检查是否有该目录的 bookmark → 没有则弹出 `NSOpenPanel` 让用户授权具体文件夹 → 缓存 bookmark 供后续使用。

---

## 二、数据模型

### 2.1 新增 `BookmarkEntity`（SwiftData）

```
BookmarkEntity
├── id: String              @Attribute(.unique)  主键
├── bookmarkData: Data      安全作用域 bookmark 凭证
├── pathString: String      目录路径（匹配操作 + 设置页展示）
└── createdAt: Date         创建时间
```

**设计理由：**
- 独立实体，不依附于 `CommonDirEntity`。CommonDir 的语义是"快速打开的收藏夹"，Bookmark 的语义是"持有安全访问凭证"—— 两者是不同的领域概念
- 三个字段刚好满足当前需求：匹配目录 + 持有凭证 + 设置页列表展示
- 不过度设计：需要扩展时（如加 `accessScope`），SwiftData 迁移成本很低
- 使用 SwiftData 而非 UserDefaults，与项目现有架构一致

### 2.2 注册到 ModelContainer

在 `ModelContainer.swift` 的 `ModelContainer(for:)` 中增加 `BookmarkEntity.self`：

```swift
let container = try ModelContainer(
    for: AppEntity.self,
         ActionEntity.self,
         NewFileTypeEntity.self,
         CommonDirEntity.self,
         BookmarkEntity.self,   // 新增
         DataVersion.self,
    configurations: configuration
)
```

### 2.3 与 CommonDirEntity 的关系

两者**并存但不耦合**：

| | CommonDirEntity | BookmarkEntity |
|---|---|---|
| 业务意图 | "我常用这个文件夹" | "持有这个文件夹的访问凭证" |
| 创建方式 | 用户手动添加 | 文件操作时自动生成 |
| 出现在右键菜单 | ✅ 是 | ❌ 否 |
| 可独立增删 | ✅ | ✅ |
| 未来扩展方向 | 排序、分组、自定义图标 | 作用域、关联动作/脚本 |

---

## 三、BookmarkManager

### 3.1 职责

新建 `RClick/Shared/BookmarkManager.swift`，`@MainActor` + `ObservableObject`：

```
BookmarkManager
├── 持久化层：通过 ModelContext 读写 BookmarkEntity
├── 权限恢复：启动时 resolve 所有 bookmark → startAccessing
├── 访问检查：ensureAccess(to:) → 已有 bookmark 直接通过
├── 授权提示：promptForPermission(for:) → NSOpenPanel → 保存新 bookmark
└── 权限管理：addDirectory() / removeDirectory() 供设置页使用
```

### 3.2 核心 API

```swift
@MainActor
final class BookmarkManager: ObservableObject {
    /// 当前已激活访问的目录（内存）
    @Published var authorizedDirectories: [URL] = []

    /// 启动时调用：从 SwiftData 恢复所有 bookmark 并 startAccessing
    func restoreBookmarks(context: ModelContext)

    /// 确保对某个文件/目录有安全访问权限
    /// - 已有 bookmark → 返回 true
    /// - 无 bookmark → 返回 false（调用方决定是否 prompt）
    func hasAccess(to fileURL: URL) -> Bool

    /// 弹出 NSOpenPanel 请求目录访问权限
    func promptForPermission(for directoryURL: URL) async -> URL?

    /// 保存 bookmark 到 SwiftData
    func saveBookmark(for directoryURL: URL, context: ModelContext)

    /// 从设置页添加目录
    func addDirectory(context: ModelContext) async -> URL?

    /// 从设置页移除目录及其 bookmark
    func removeDirectory(_ url: URL, context: ModelContext)
}
```

### 3.3 关键设计决策

**NSOpenPanel 呈现方式：**
- RClick 是菜单栏应用（`activationPolicy: .accessory`），无主窗口
- 使用 `.runModal()` 而非 `.beginSheetModal()`（与 iMonet 不同）
- 弹出前调用 `NSApp.activate(ignoringOtherApps: true)` 确保面板在前台

**`startAccessing` 生命周期：**
- 启动时 resolve bookmark → `startAccessing` → 保持到 app 终止（会话级）
- 新的 NSOpenPanel 授权后也调用 `startAccessing`，同样保持会话级
- 不调用 `stopAccessing`，系统在 app 退出时自动释放

**防并发：**
- `private var isPrompting = false` 防止多个 NSOpenPanel 同时出现

**路径匹配：**
- `hasAccess(to:)` 将 target URL 的父目录路径与 `authorizedDirectories` 做前缀匹配
- 路径标准化使用 `resolvingSymlinksInPath()` 处理符号链接

---

## 四、文件操作改动

### 4.1 改动范围

`RClickApp.swift` 中的文件操作需要增加权限检查：

| 操作 | 是否需要 ensureAccess | 原因 |
|------|---------------------|------|
| `deleteFoldorFile` | ✅ | `FileManager.removeItem` 需要写权限 |
| `createFile` | ✅ | `Data().write` / `FileManager.copyItem` 需要写权限 |
| `hideFilesAndDirs` | ✅ | `setResourceValues` 修改 isHidden 需要写权限 |
| `unhideFilesAndDirs` | ✅ | 同上 |
| `showAirDrop` | ✅ | 读文件需要访问权限 |
| `copyPath` | ❌ | 只操作 NSPasteboard |
| `openApp` | ❌ | `NSWorkspace.open` 不需要文件系统写权限 |
| `openCommonDirs` | ❌ | 同上 |

### 4.2 改动模式

以 `deleteFoldorFile` 为例：

```swift
func deleteFoldorFile(_ target: [String], _ trigger: String) async {
    // ... 现有 ctx-container guard 和 isProtectedFolder 检查不变 ...

    for item in target {
        let decodedPath = item.removingPercentEncoding ?? item
        let url = URL(fileURLWithPath: decodedPath)

        // 新增：确保有父目录的访问权限
        let dirURL = url.deletingLastPathComponent()
        if !bookmarkManager.hasAccess(to: dirURL) {
            guard let _ = await bookmarkManager.promptForPermission(for: dirURL) else {
                continue  // 用户取消
            }
        }

        // 现有删除逻辑不变
        do {
            try FileManager.default.removeItem(atPath: decodedPath)
        } catch {
            logger.error("delete error: \(error)")
        }
    }
}
```

其他操作（`createFile`、`hideFilesAndDirs`、`unhideFilesAndDirs`、`showAirDrop`）遵循相同模式。

### 4.3 异步化

`handleClickEvent` 中原本同步调用的操作需要改为 `Task { @MainActor in await ... }`：

```swift
case .action:
    Task { @MainActor in
        await self.actionHandler(rid: event.itemId, target: event.target, trigger: event.trigger.rawValue)
    }
case .newFile:
    Task { @MainActor in
        await self.createFile(rid: event.itemId, target: event.target)
    }
```

---

## 五、移除 FDA 相关代码

### 5.1 RClickApp.swift

- **删除** `checkFDAAndGuideIfNeeded()` 方法（lines 274-304）
- **删除** `applicationDidFinishLaunching` 中对其的调用（line 167）

### 5.2 AppState.swift

- **删除** `@Published var hasFullDiskAccess: Bool = false`
- **删除** `func checkFullDiskAccess()`
- **新增** `let bookmarkManager = BookmarkManager()`
- `init()` 中添加 `bookmarkManager.restoreBookmarks(context: modelContext)`

### 5.3 PermissionChecker.swift

- **删除** `hasFullDiskAccess()` 和 `protectedTestPaths`
- **删除** `openFullDiskAccessSettings()`
- **保留** `hasAccessibilityPermission()` 和 `openAccessibilitySettings()`（与 FDA 无关，`revealInFinderAndRename` 仍需要）

### 5.4 StringExtension.swift

- **删除** `static let hasSeenFDAGuide = "HAS_SEEN_FDA_GUIDE"`

---

## 六、设置界面改动

### GeneralSettingsTabView.swift

Permissions 区域的改动：

**删除：**
- `@State private var fullDiskAccessStatus: PermissionStatus`
- "Full Disk Access" 行（lines 97-105）
- FDA 相关的 footer 引导文字（lines 127-143）
- `updatePermissionStatus()` 中的 `store.checkFullDiskAccess()` 调用

**新增：**
- "Folder Permissions" 行，显示已授权目录数量 + "Manage…" 按钮
- 点击 "Manage…" 打开 sheet：
  - 列表展示 `bookmarkManager.authorizedDirectories`，每个路径可删除
  - "Add Folder…" 按钮调用 `bookmarkManager.addDirectory()`

```swift
// Folder Permissions 行
LabeledContent {
    HStack {
        Text("\(bookmarkManager.authorizedDirectories.count) folders authorized")
            .foregroundColor(.secondary)
        Button("Manage…") { showFolderPermissionsSheet = true }
    }
} label: {
    Label("Folder Permissions", systemImage: "folder.badge.person.crop")
}
```

---

## 七、保持不变的部分

- **entitlements**：保留 `home-relative-path.read-write` 作为非 TCC 目录的后备
- **Accessibility 权限**：`revealInFinderAndRename` 仍然需要，不动
- **Finder Extension 权限**：不动
- **CommonDirEntity**：不动，独立于 Bookmark

---

## 八、涉及的本地化字符串

| Key | 用途 |
|-----|------|
| `Folder Permissions` | 设置页权限行标签 |
| `Manage…` | 打开管理 sheet 的按钮 |
| `Add Folder…` | 添加目录按钮 |
| `No folders authorized` | 空状态 |
| `Grant Access` | NSOpenPanel 的 prompt 文案 |
| `RClick needs permission to access this folder to perform file operations.` | NSOpenPanel 的 message |

---

## 九、文件清单

| 文件 | 改动类型 |
|------|---------|
| `RClick/Model/BookmarkEntity.swift` | **新增** |
| `RClick/Shared/BookmarkManager.swift` | **新增** |
| `RClick/Model/ModelContainer.swift` | 注册 BookmarkEntity |
| `RClick/AppState.swift` | 删 FDA、加 BookmarkManager |
| `RClick/RClickApp.swift` | 删 FDA 引导、文件操作加 ensureAccess、异步化 |
| `RClick/Settings/GeneralSettingsTabView.swift` | 替换 FDA 行为 Folder Permissions |
| `RClick/Shared/PermissionChecker.swift` | 删 hasFullDiskAccess |
| `RClick/Shared/StringExtension.swift` | 删 hasSeenFDAGuide key |
| `README.md` | FDA → Folder Access |
| `SECURITY.md` | 更新 bookmark 描述的准确性 |
