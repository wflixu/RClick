
[![](./RClick/Assets.xcassets/AppIcon.appiconset/AppIcon@1x.png)](https://github.com/wflixu/RClick/releases)

# RClick

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-ED523F.svg?style=flat)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-orange)](https://developer.apple.com/xcode/swiftui/)
[![macOS 15.6+](https://img.shields.io/badge/macOS_15.6+-Compatible-green)](https://www.apple.com/macos/macos-sequoia/)
[![Xcode 16.4+](https://img.shields.io/badge/Xcode-16.4+-blue)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/wflixu/RClick)](https://github.com/wflixu/RClick/releases)
[![GitHub downloads](https://img.shields.io/github/downloads/wflixu/RClick/total)](https://github.com/wflixu/RClick/releases)

Enhance your macOS Finder context menu with custom actions. Built with Swift 6.2 and SwiftUI for macOS 15.6+. Full dark mode support with adaptive icons.

## 🚀 Features

- [x] **Open with External App** — Open files or directories with any installed application, with support for custom arguments and environment variables.
- [x] **Copy Path** — Copy the full path of selected files or folders to clipboard.
- [x] **Delete Directly** — Delete files or folders directly, bypassing Trash.
- [x] **Hide / Unhide** — Toggle file visibility in Finder.
- [x] **AirDrop** — Share files instantly via AirDrop.
- [x] **Create New Files** — Generate new files from templates directly in Finder. Supports `.txt`, `.json`, `.md`, `.docx`, `.pptx`, `.xlsx`, as well as Apple iWork formats: `.pages`, `.key`, `.numbers`.
- [x] **Quick Access Folders** — Pin frequently used directories to the right-click menu.
- [x] **Dark Mode** — Full light/dark appearance support with adaptive icons and SF Symbols.

## 🏗 Architecture

RClick uses a dual-process architecture:

| Component | Description |
|-----------|-------------|
| **Main App** (`RClick/`) | SwiftUI menu bar app — manages settings, state, and file operations |
| **FinderSync Extension** (`FinderSyncExt/`) | Injected into Finder — renders custom context menu items |

Communication between the two processes uses `DistributedNotificationCenter`. Settings are persisted via SwiftData with a shared App Group container.

## 📸 Screenshots


![](./images/rclick-v2.0.1-screenshot.png)



## 📦 Installation

### Download

Get the latest release from the [Releases page](https://github.com/wflixu/RClick/releases).

Download the `.dmg`, open it, and drag **RClick** to your Applications folder.

> **Note:** On first launch, you may need to enable the Finder extension in **System Settings → Privacy & Security → Extensions → Added Extensions**.

### Build from Source

```bash
git clone https://github.com/wflixu/RClick.git
cd RClick
open RClick.xcodeproj
```

- Requires **Xcode 16.4+** and **macOS 15.6+**
- Select the **RClick** scheme, then **Product → Build** (⌘B)
- The FinderSync extension will be automatically registered

### Requirements

| Requirement | Details |
|-------------|---------|
| **Folder Access** | Per-folder authorization for file operations (prompted automatically) |
| **Accessibility** | Required for certain automation features |
| **Finder Extension** | Must be enabled in System Settings |

## 🔧 Development

```bash
# Build
xcodebuild -project RClick.xcodeproj -scheme RClick -destination 'platform=macOS'

# Build for Release
xcodebuild -project RClick.xcodeproj -scheme RClick -configuration Release
```

### Key Technologies
- **Swift 6.2** with full concurrency checking
- **SwiftUI** for all UI components
- **AppKit** for system integration only (NSWorkspace, NSPasteboard)
- **SwiftData** for persistence with shared container
- **FinderSync** framework for Finder extension
- **DistributedNotificationCenter** for IPC

### 🌐 Localization

RClick supports five languages with the following priority:

| Language | Code | Notes |
|----------|------|-------|
| **English** | `en` | Default/base language |
| **Simplified Chinese** | `zh-Hans` | Primary localization target |
| **Japanese** | `ja` | Activated when system language is Japanese |
| **Spanish** | `es` | Activated when system language is Spanish |
| **French** | `fr` | Activated when system language is French |

**Principles:**
- Default language is English (also the fallback for unsupported system languages)
- All string keys are in English in the code, localized via `Localizable.xcstrings`
- System language is auto-detected — no manual language picker in the app
- To add a new language, add an entry to `Localizable.xcstrings` and register it in the Xcode project

## 👥 Contributors

Thanks to all the people who have contributed to RClick!

<a href="https://github.com/wflixu/RClick/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=wflixu/RClick" />
</a>

## Similar Projects

- [SzContext](https://github.com/RoadToDream/SzContext)
- [MenuHelper](https://github.com/Kyle-Ye/MenuHelper)
- [SwiftyMenu](https://github.com/lexrus/SwiftyMenu)
- [OpenInTerminal](https://github.com/Ji4n1ng/OpenInTerminal)

## 🤝 Contributing

We welcome contributions! Here's how you can help:

- **[Report a Bug](https://github.com/wflixu/RClick/issues/new?template=bug_report.md)** — Found something broken? Let us know.
- **[Request a Feature](https://github.com/wflixu/RClick/issues/new?template=feature_request.md)** — Have an idea? We'd love to hear it.
- **[Submit a PR](CONTRIBUTING.md)** — Read our contribution guide to get started.
- **[Security Policy](SECURITY.md)** — How to responsibly report vulnerabilities.

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

## 自定义菜单层级

支持一级常用项与任意嵌套子菜单混排、分隔线及自定义标题/图标。
把声明式 `custom_menu.json` 放进 App Group 容器后，需到 **设置 → 通用 → 自定义菜单** 点「应用配置」才会生效——改动文件本身不会自动应用，这样编辑到一半的半成品不至于把菜单弄坏。缺失文件时使用默认布局；配置无效时菜单保持原样，并在设置中显示具体出错项。
参见 [配置示例与使用说明](examples/README.md)。
