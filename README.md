
[![](./RClick/Assets.xcassets/AppIcon.appiconset/AppIcon@1x.png)](https://github.com/wflixu/RClick/releases)

# RClick

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-ED523F.svg?style=flat)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-orange)](https://developer.apple.com/xcode/swiftui/)
[![macOS 15.6+](https://img.shields.io/badge/macOS_15.6+-Compatible-green)](https://www.apple.com/macos/macos-sequoia/)
[![Xcode 26+](https://img.shields.io/badge/Xcode-26%2B-blue)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/wflixu/RClick)](https://github.com/wflixu/RClick/releases)
[![GitHub downloads](https://img.shields.io/github/downloads/wflixu/RClick/total)](https://github.com/wflixu/RClick/releases)

Enhance your macOS Finder context menu with custom actions. Built with Swift 6.2 and SwiftUI for macOS 15.6+. Full dark mode support with adaptive icons.

## 🚀 Features

- [x] **Open with External App** — Open files or directories with any installed application, with support for custom arguments and environment variables. Ships with presets for popular editors, terminals and IDEs, per-app visibility for the toolbar and context menus, and none/simple/original icon styles.
- [x] **Copy Path / File Name** — Copy the full path or just the file name of the selected item to the clipboard.
- [x] **Delete Direct** — Delete files or folders directly, bypassing Trash. RClick asks for confirmation first; hold **Option** while choosing the action to skip it.
- [x] **Hide / Unhide** — Toggle file visibility in Finder.
- [x] **AirDrop** — Share files instantly via AirDrop.
- [x] **Create New Files** — Generate new files from templates directly in Finder. Supports `.txt`, `.json`, `.md`, `.docx`, `.pptx`, `.xlsx`, as well as Apple iWork formats: `.pages`, `.key`, `.numbers`.
- [x] **Quick Access Folders** — Pin frequently used directories to the right-click menu.
- [x] **Terminal-aware Opening** — Terminal presets hand the containing folder to the app by default, with an automatic/on/off override per app.
- [x] **Dark Mode** — Full light/dark appearance support with adaptive icons and SF Symbols.

## 📱 More Apps

If RClick is useful to you, here are two other apps I maintain:

| App | What it does | Download |
|-----|--------------|----------|
| [![iMonet icon](images/apps/imonet-icon.png)](https://apps.apple.com/cn/app/imonet/id6770070921?mt=12) **iMonet** | A mouse-first image viewer for macOS. Zoom follows your cursor, with native animated GIF, APNG and WebP playback. | [Mac App Store](https://apps.apple.com/cn/app/imonet/id6770070921?mt=12) |
| [![LiveCam icon](images/apps/livecam-icon.png)](https://apps.apple.com/cn/app/livecam/id6476108478?mt=12) **LiveCam** | Show your avatar while recording your screen or live streaming, with configurable size, border and shape. | [Mac App Store](https://apps.apple.com/cn/app/livecam/id6476108478?mt=12) |

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

- Requires **Xcode 26+** and **macOS 15.6+**
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

Recent contributions:

- **[@SonneFish](https://github.com/SonneFish)** — built-in app presets, per-app visibility and icon styles ([#168](https://github.com/wflixu/RClick/pull/168)); Finder icon-cache and heartbeat performance ([#167](https://github.com/wflixu/RClick/pull/167)); permission status refresh ([#169](https://github.com/wflixu/RClick/pull/169)); quiet offline relaunch and settings reopen ([#170](https://github.com/wflixu/RClick/pull/170))
- **[@Consciencieux](https://github.com/Consciencieux)** — confirmation before Direct Delete ([#163](https://github.com/wflixu/RClick/pull/163))
- **[@Juns-g](https://github.com/Juns-g)** — watching mounted volumes so external and network drives show the menu ([#152](https://github.com/wflixu/RClick/pull/152))
- **[@Dam0rt](https://github.com/Dam0rt)** — French localization ([#149](https://github.com/wflixu/RClick/pull/149))
- **[@stors789](https://github.com/stors789)** — App Groups provisioning in the release pipeline ([#141](https://github.com/wflixu/RClick/pull/141))
- **[@EliasMatDev](https://github.com/EliasMatDev)** — Latin American Spanish localization ([#138](https://github.com/wflixu/RClick/pull/138))
- **[@shoal-rat](https://github.com/shoal-rat)** — Finder observation fix, so the menu appears in every folder ([#126](https://github.com/wflixu/RClick/pull/126))
- **[@P013onEr](https://github.com/P013onEr)** — string catalogs and trilingual localization ([#120](https://github.com/wflixu/RClick/pull/120)), draggable menu ordering ([#121](https://github.com/wflixu/RClick/pull/121))
- **[@chunyang-wen](https://github.com/chunyang-wen)** — removed a needless `await` ([#21](https://github.com/wflixu/RClick/pull/21))

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
