# RClick CI/CD 与自动更新改进方案

## 背景

RClick 决定放弃 App Store 发布，转为纯开源项目。需要两个关键基础设施：
1. **GitHub CI/CD**：PR 时自动构建测试，推送 tag 时自动签名、公证、发布
2. **自动更新改进**：现有更新器功能基础，参考 capcap 项目的成熟实现进行增强

### 参考项目
- **iMonet** (`/Users/lixu/code/iMonet`)：完整的签名+公证+DMG 发布流程（已禁用自动触发，仅 workflow_dispatch）
- **capcap** (`/Users/lixu/repos/capcap-main`)：成熟的自定义更新器（状态机、SHA-256 校验、ditto 解压、分离交换脚本）

---

## 1. CI/CD 方案

### 1.1 PR 构建测试工作流

**文件**: `.github/workflows/pr-build.yml`

- **触发**: PR 到 `main` 或 `dev`
- **策略**: `CODE_SIGNING_ALLOWED=NO`，对 fork PR 友好
- **步骤**: Checkout → Select Xcode → Build (Debug) → Run Unit Tests (RClickTests)

关键点：
- RClick 是 `.xcodeproj` 项目，使用 `-project RClick.xcodeproj -scheme RClick`
- 主 App 嵌入 FinderSyncExt 扩展，构建时自动包含
- **仅跑单元测试，不跑 UI 测试**：UI 测试是空壳（只启动+截屏），且菜单栏 App 无法被 XCTest UI 测试有效覆盖
- 单元测试虽也是空壳，但框架已搭好（Swift Testing），后续可添加模型层/协议层测试
- 使用 `concurrency` 取消同一 PR 的旧构建

**平台约束（PR 和 Release 一致）**：
- `ARCHS=arm64` — 仅支持 Apple Silicon，**不支持 x86_64**
- `MACOSX_DEPLOYMENT_TARGET=15.6` — 最低系统要求 macOS 15.6

### 1.2 Tag 触发自动发布工作流

**文件**: `.github/workflows/release.yml`

- **触发**: 推送 `v*` tag（如 `v2.0.2`）
- **权限**: `contents: write`
- **平台约束**: `ARCHS=arm64`，`MACOSX_DEPLOYMENT_TARGET=15.6`（与 PR 工作流一致）

**产出两个包**（版本号从 tag 提取，如推送 `v2.0.2` 则版本为 `2.0.2`）：

| 文件 | 命名 | 用途 |
|------|------|------|
| .app.zip | `RClick-v{version}.app.zip` | 自动更新器下载使用 |
| .sha256 | `RClick-v{version}.app.zip.sha256` | 自动更新器校验完整性 |
| .dmg | `RClick-v{version}.dmg` | 用户手动下载安装 |

示例（tag `v2.0.2`）：
- `RClick-v2.0.2.app.zip`
- `RClick-v2.0.2.app.zip.sha256`
- `RClick-v2.0.2.dmg`

**完整流程（10步）**：

| 步骤 | 说明 | 工具 |
|------|------|------|
| 0. 准备 | Checkout, 选 Xcode, 从 tag 提取版本号 | `actions/checkout@v4` |
| 1. 导入证书 | 创建临时 keychain, 导入 Developer ID 证书 | `security import` |
| 2. 构建 | xcodebuild Release, `CODE_SIGNING_ALLOWED=NO`, `ARCHS=arm64` | `xcodebuild` |
| 3. 分层签名 | Frameworks → Extensions → Main App, `--options runtime` | `codesign` |
| 4. 打包 ZIP | `ditto -c -k` 打包用于公证 | `ditto` |
| 5. 公证 | `notarytool submit` 使用 App Store Connect API Key (p8) | `xcrun notarytool` |
| 6. 装订票据 | `stapler staple` + `spctl --assess` 验证 | `xcrun stapler` |
| 7. 创建 DMG | `create-dmg` 生成带拖拽安装界面的 DMG，签名+公证 | `create-dmg` |
| 8. 创建 .app.zip | 给自动更新器用的 ZIP + `.sha256` | `ditto` + `shasum` |
| 9. 创建 Release | 上传 **DMG** + **.app.zip** + **.sha256** | `softprops/action-gh-release@v2` |
| 10. 失败清理 | 自动删除远程 tag | `git push origin --delete` |

### 1.3 需要的 GitHub Secrets

| Secret | 说明 |
|--------|------|
| `MACOS_CERT_P12` | Developer ID Application 证书的 base64 |
| `MACOS_CERT_PASSWORD` | 证书导出密码 |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `NOTARY_KEY_ID` | App Store Connect API Key ID |
| `NOTARY_ISSUER_ID` | API Key Issuer ID |
| `NOTARY_PRIVATE_KEY` | .p8 私钥文件内容 |

### 1.4 Entitlements 与签名策略

**现有 Entitlements 文件**（项目已配置，xcodebuild 自动引用）：

| 文件 | 对象 | 关键权限 |
|------|------|---------|
| `RClick/RClick.entitlements` | 主 App (Release) | app-groups, bookmarks, user-selected.read-write, **temporary-exception.apple-events**, **temporary-exception.files.home-relative-path.read-write(/)**, app-sandbox(通过 build setting) |
| `RClick/RClickDebug.entitlements` | 主 App (Debug) | app-groups, bookmarks, temporary-exception.files.home-relative-path.read-write(/) |
| `FinderSyncExt/FinderSyncExt.entitlements` | 扩展 | app-groups, bookmarks, app-sandbox(通过 build setting) |

**Release 签名策略**：**不创建动态 entitlements**，直接使用项目已有文件。

构建时 `CODE_SIGNING_ALLOWED=NO`，然后分层手动签名：
1. **Frameworks**（如有）：`codesign --force --options runtime --timestamp --sign "$CERT_NAME"`
2. **FinderSyncExt.appex**：`codesign` + 使用 `FinderSyncExt/FinderSyncExt.entitlements`
3. **RClick.app**：`codesign` + 使用 `RClick/RClick.entitlements` + `--options runtime`

**公证注意事项**：`RClick.entitlements` 包含 `temporary-exception.files.home-relative-path.read-write` 设为 `/`（整个家目录），这是一个宽泛的临时例外。RClick 作为 Finder 右键扩展需要访问用户在 Finder 中选中的任意文件，功能上合理。公证时 Apple 可能会审查此项，若不通过则需要收紧权限范围。

### 1.5 构建参数汇总

所有 CI 构建（PR + Release）统一设置：

| 参数 | 值 | 说明 |
|------|-----|------|
| `ARCHS` | `arm64` | 仅 Apple Silicon，**不包含 x86_64** |
| `MACOSX_DEPLOYMENT_TARGET` | `15.6` | 最低 macOS 15.6 |
| `-destination` | `generic/platform=macOS` | 通用 macOS 目标 |
| `-scheme` | `RClick` | 主 scheme（自动包含 FinderSyncExt） |

---

## 2. 自动更新改进方案

### 2.1 自动更新原理

**核心挑战**：一个正在运行的 .app 无法替换自己。

**整体流程**：
1. **检查更新**：向 GitHub API 查询最新 release 版本号，与本地版本做语义化比较
2. **下载**：下载 `.app.zip` + `.sha256` 校验文件到临时目录
3. **校验与解压**：CryptoKit 验证 SHA-256 → `ditto -x -k` 解压 → 移除 quarantine 隔离属性
4. **分离脚本交换**：启动独立 bash 子进程，然后 RClick 自己退出 → 脚本等待进程退出 → 替换 .app → 启动新版本

**关键——分离交换脚本（capcap 模式）**：

```
RClick 启动 bash 子进程，传入：
  - 新 .app 路径（/tmp/rclick-update-xxx/RClick.app）
  - 旧 .app 路径（/Applications/RClick.app）
  - 当前进程 PID

RClick 调用 NSApp.terminate() 退出
       │
       ▼
   bash 脚本接管:
   ├─ 等待 PID 进程退出（轮询 kill -0，最多15秒）
   ├─ mv old.app → old.app.rclick-backup-<PID>
   ├─ ditto new.app → old.app
   ├─ 成功: 删备份, 删临时目录
   ├─ 失败: 恢复备份
   └─ open old.app 重新启动
```

### 2.2 当前状态 vs 改进目标

文件：`RClick/Shared/Updater.swift` (495行), `RClick/Shared/UpdaterView.swift` (123行)

| 问题 | 当前实现 | 改进后 |
|------|---------|--------|
| 状态管理 | 分散 @Published bool (`isChecking`, `isDownloading`, `availableUpdate`, `updateError`) | 单一 `UpdateState` 枚举状态机 |
| 下载进度 | 无 | URLSessionDownloadDelegate 报告百分比 |
| 解压工具 | `/usr/bin/unzip -o` | `/usr/bin/ditto -x -k`（更好保留元数据） |
| SHA-256 | 无 | CryptoKit 校验，缺文件时安全降级 |
| 备份回滚 | 无 | mv 备份，失败自动恢复 |
| 隔离属性 | 无 | `xattr -dr com.apple.quarantine` |
| 残留清理 | 无 | 每次更新前清理 `rclick-update-*` |
| 安装方式 | NSOpenPanel 让用户选文件夹 | isWritableFile 检查 + 分离脚本 |
| 进程交换 | 运行时直接复制（不可靠） | 分离 bash 脚本等待退出后交换 |
| 安装阶段 | 无区分 | InstallPhase 枚举（verifying, unzipping, installing） |

### 2.3 状态机设计

```swift
enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String)
    case downloading(version: String, fraction: Double)
    case installing(version: String, phase: InstallPhase)
    case failed
    case installFailed(version: String)
}

enum InstallPhase: Equatable {
    case verifying    // SHA-256 校验
    case unzipping    // ditto 解压
    case installing   // 交换脚本
}
```

`UpdateManager` 用单一 `@Published var state: UpdateState` 替代多个分散的 bool。

### 2.4 App Sandbox 适配

RClick 启用了 App Sandbox，`Process()` 启动的子进程继承沙盒限制：
- 分离脚本尽力而为（`try? task.run()`）
- 沙盒下 `/Applications` 写入可能失败，回退到手动安装提示
- 开发版本通过 `temporary-exception` 可获得写入权限

---

## 3. 实施步骤

### 阶段 1: CI/CD（无代码风险，优先）

| # | 任务 | 产出 |
|---|------|------|
| 1.0 | **删除 UI 测试**：删除 `RClickUITests/` 目录，从 Xcode project 中移除 target 引用 | 清理无用代码 |
| 1.1 | 创建 `.github/workflows/pr-build.yml` | PR 构建测试 |
| 1.2 | 创建 `.github/workflows/release.yml` | Tag 自动发布 |
| 1.3 | 配置 GitHub Secrets（6个） | 仓库设置 |
| 1.4 | 测试 PR 工作流 | 验证通过 |
| 1.5 | 推送测试 tag 验证 Release 流程 | 验证通过 |

### 阶段 2: 自动更新器改进

| # | 任务 | 文件 | 风险 |
|---|------|------|------|
| 2.1 | 添加 UpdateState / InstallPhase 枚举 | `Updater.swift` | 低 |
| 2.2 | UpdateManager 迁移到状态机 | `Updater.swift` | 中 |
| 2.3 | 实现 UpdateDownloader (URLSessionDownloadDelegate) | `Updater.swift` | 中 |
| 2.4 | unzip → ditto 替换 | `Updater.swift` | 低 |
| 2.5 | SHA-256 校验逻辑 | `Updater.swift` | 低 |
| 2.6 | 备份/回滚机制 | `Updater.swift` | 中 |
| 2.7 | quarantine 移除 + cleanStaleArtifacts | `Updater.swift` | 低 |
| 2.8 | spawnSwapHelper 分离脚本 | `Updater.swift` | 高 |
| 2.9 | UpdateView 状态机 UI 适配 | `UpdaterView.swift` | 中 |
| 2.10 | AboutSettingsTabView 适配新 API | `AboutSettingsTabView.swift` | 低 |

### 阶段 3: 集成测试

- 本地构建 Release，验证完整更新流程
- 模拟失败场景（下载中断、校验失败、权限不足）
- 验证回滚机制
- 端到端：旧版本 → 检查 → 下载 → 安装 → 重启 → 新版本

---

## 4. 验证方案

### CI/CD
```bash
# PR 工作流：创建测试 PR 到 dev，确认触发并通过
# Release 工作流：推送测试 tag
git tag v2.0.2-test && git push origin v2.0.2-test
# 观察 Actions → 确认构建/签名/公证/Release 全流程
# 清理：gh release delete v2.0.2-test --yes
```

### 自动更新器检查清单
- [ ] 状态转换：idle → checking → available → downloading(0..1) → installing(verifying→unzipping→installing)
- [ ] 下载进度 0%→100%，每 1% 更新
- [ ] SHA-256 错误 → installFailed
- [ ] 解压失败 → installFailed
- [ ] 用户忽略版本 → 不再提示；强制检查 → 仍提示
- [ ] 残留清理：多次更新后 temp 目录无累积
- [ ] 回滚：交换脚本中断后旧 App 仍可用
- [ ] 重启：新版本正常启动

---

## 5. 涉及的关键文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `.github/workflows/pr-build.yml` | **新建** | PR 构建测试工作流 |
| `.github/workflows/release.yml` | **新建** | Tag 自动发布工作流 |
| `RClick/Shared/Updater.swift` | **修改** | 状态机、ditto、SHA-256、备份回滚、分离脚本 |
| `RClick/Shared/UpdaterView.swift` | **修改** | 状态驱动 UI（下载进度、安装阶段） |
| `RClick/Settings/AboutSettingsTabView.swift` | **小改** | 适配新 API |

参考代码位置：
- iMonet CI: `/Users/lixu/code/iMonet/.github/workflows/release.yml`
- capcap 更新器: `/Users/lixu/repos/capcap-main/capcap/Utilities/UpdateChecker.swift` 和 `UpdateInstaller.swift`
