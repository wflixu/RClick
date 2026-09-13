# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RClick is a macOS desktop application that extends Finder's context menu with custom functionality. It's a menu bar application that adds various right-click actions to macOS Finder, built with Swift 6.2+ and SwiftUI.

**Key Technologies:**
- Swift 6.2+ (required)
- SwiftUI (all UI components)
- AppKit (system integration only, no UI)
- SwiftData (persistence)
- FinderSync framework (Finder extension)
- DistributedNotificationCenter (inter-process communication)
- Xcode 16+ (required for development)

## Architecture

RClick follows a dual-process architecture:

### 1. Main Application (`RClick/`)
- SwiftUI-based menu bar application
- Manages global settings and state via `AppState.swift`
- Provides settings interface (Settings window)
- Handles file operations triggered from context menu
- Entry point: [RClickApp.swift](RClick/RClickApp.swift)

### 2. FinderSync Extension (`FinderSyncExt/`)
- Runs as a separate process, injected into Finder
- Injects custom context menu items into Finder
- Communicates with main app via `Messager` class
- Entry point: [FinderSyncExt.swift](FinderSyncExt/FinderSyncExt.swift)

### 3. Communication Layer
The main app and extension communicate via `DistributedNotificationCenter`:
- **Extension → App**: `RClick.ExtensionToMain` (click events, heartbeat, requestConfig)
- **App → Extension**: `RClick.MainToExtension` (menu config, running, quit, actionAck)
- Messages are HMAC-SHA256 signed (`MessageSecurity`) and JSON-encoded via `Messager`
- Implementation: [Messager.swift](Shared/Messager.swift)

### 4. State Management
- **AppState**: `@MainActor ObservableObject` holding runtime state (in-memory config arrays, fold toggles, `BookmarkManager`)
- **ConfigService**: SwiftData config load/save/reset (persistence separated from runtime state)
- **RCRuntime**: in-process dependency container (`RClick/Runtime/`) holding AppState + ConfigService + MenuService + ActionService + PermissionService + Messager. **It is NOT a separate process / Helper.**
- **BookmarkManager**: security-scoped bookmarks — the only folder-authorization mechanism (mandatory for the sandboxed App Store build)
- Data categories: Apps (external apps), Actions (context menu actions), NewFiles (file templates), CommonDirs (quick access folders), BookmarkEntity (authorized folder credentials)
- Persistence: SwiftData with shared App Group container between app and extension
- Location: [AppState.swift](RClick/AppState.swift) / [RClick/Runtime/](RClick/Runtime/)

### 5. Data Models
SwiftData `@Model` entities are in [RClick/Model/](RClick/Model/), one file per entity:
- `AppEntity.swift`, `ActionEntity.swift`, `NewFileTypeEntity.swift`, `CommonDirEntity.swift`, `BookmarkEntity.swift`, `DataVersion.swift`
- In-memory models & IPC DTOs are in [Shared/RCBase.swift](Shared/RCBase.swift) (`OpenWithApp`, `RCAction`, `NewFile`, `CommonDir`, `AppMenuItem`, `ActionMenuItem`, …)
- `ModelContainer.swift`: Shared App Group SwiftData container configuration

## Build and Development Commands

### Building
```bash
# Build the project
xcodebuild -project RClick.xcodeproj -scheme RClick -destination 'platform=macOS'

# Build for release
xcodebuild -project RClick.xcodeproj -scheme RClick -configuration Release
```

### Running
- Open `RClick.xcodeproj` in Xcode 16+
- Select the RClick scheme
- Press Cmd+R to build and run
- The FinderSync extension will be automatically registered

### Testing
```bash
# Run tests (if test targets exist)
xcodebuild test -project RClick.xcodeproj -scheme RClick -destination 'platform=macOS'
```

### Linting
```bash
# Run SwiftLint (if configured)
swiftlint
```

## Key Development Patterns

### Adding New Context Menu Actions

1. Define action model in [Shared/RCBase.swift](Shared/RCBase.swift)
2. Add to `RCAction.all` static property
3. Handle action in [ActionService.swift](RClick/Runtime/ActionService.swift) in `actionHandler()` method
4. Extension receives action via menu callback and sends `.click` message to main app (via `Messager`)

### Adding New File Templates

1. Add to `NewFile` model in [Shared/RCBase.swift](Shared/RCBase.swift)
2. Add template file to [Assets.xcassets](RClick/Assets.xcassets/)
3. Handle creation in [ActionService.swift](RClick/Runtime/ActionService.swift) in `createFile()` method

### Inter-Process Communication

When adding new message types:
1. Define the message enum case + payload in [Messager.swift](Shared/Messager.swift)
2. Register message handler in the appropriate `init` / `applicationDidFinishLaunching`
3. If the extension needs to detect whether the main app received a message, add a matching ack message

### Security-Scoped Resource Access

When working with files outside the sandbox container (required for the App Store build):
1. Check `PermissionService.hasAccess(to:)` (bookmark prefix match, covers subtree)
2. If not authorized, `PermissionService.promptForPermission(for:)` shows `NSOpenPanel` (powerbox) → user grants once → bookmark cached
3. See [BookmarkManager.swift](RClick/Shared/BookmarkManager.swift) (implementation) and [ActionService.swift](RClick/Runtime/ActionService.swift) (usage in delete/create/hide/open)

## Important Constraints

### RClick Constitution Requirements
- **MUST use Swift 6.2 syntax** - no older Swift patterns
- **MUST use SwiftUI for all UI** - no AppKit UI components
- **AppKit usage limited to system integration only** (e.g., NSWorkspace, NSPasteboard, file operations)
- **Target macOS 15 Sequoia and above only**

### Extension Development
- Extension runs in separate process with limited memory (keep it a thin renderer + event forwarder)
- **Connection state is a UX cache, not a reliability mechanism**: the extension tracks "last message from main app" (`lastMainActivity`, 30s timeout) to show a disabled "RClick is not running" menu — it does NOT determine operation success
- **Real liveness check is at click time**: extension sends `.click`; main app replies `.actionAck`; if no ack in 3s, extension shows a "RClick did not respond" alert
- On `.quit` the extension immediately marks itself offline (no 30s "zombie" window)
- See [FinderSyncExt.swift](FinderSyncExt/FinderSyncExt.swift)

### Logging
- Use `@AppLog` property wrapper for structured logging
- Logs use `os.log` framework
- Category parameter should describe the subsystem
- Example: `@AppLog(category: "AppState") private var logger`

### Localization
- Default language is **English** (also the fallback)
- **Simplified Chinese** (`zh-Hans`) is the primary localization target
- **Japanese** (`ja`), **Spanish** (`es`) and **French** (`fr`) are also supported, activated when the system language matches
- All string keys in code use English, localized via `Localizable.xcstrings` (xcstrings format)
- Language detection is fully automatic via `Bundle.main.localizedString` — no manual language picker
- To add a new language: add entries to `Localizable.xcstrings` and register in Xcode project
- There are **two** catalogs — `RClick/` (app) and `FinderSyncExt/` (extension). Each target resolves against its own via `Bundle.main`, so a key the extension renders must exist in the extension's catalog too
- `scripts/check-localization.py` verifies the catalogs; run it before a release
- Edit the catalogs with exact-string text edits. Re-serializing the JSON rewrites the whole file and does not round-trip byte-for-byte

### Data Persistence
- SwiftData models use `@Model` macro
- Shared container via app group: `.group` `UserDefaults`
- Shared model container: `SharedDataManager.sharedModelContainer`
- Both app and extension access same database

## Directory Structure

```
RClick/
├── RClick/                        # Main application target
│   ├── RClickApp.swift           # App entry point & AppDelegate
│   ├── AppState.swift            # Runtime state
│   ├── Runtime/                  # In-process service layer (MenuService/ActionService/PermissionService/ConfigService/RCRuntime)
│   ├── Model/                    # SwiftData entities
│   ├── Settings/                 # Settings views (UI)
│   ├── Shared/                   # Utilities (BookmarkManager, LaunchAtLogin, Updater, …)
│   ├── Assets.xcassets/          # Images, templates, icons
│   └── Resources/                # Localization files
├── FinderSyncExt/                # Finder extension target (thin: render + forward)
│   └── FinderSyncExt.swift       # Extension main file
├── Shared/                       # Code shared by app & extension (Messager, RCBase, AppLocalization, …)
├── specs/                        # Feature specifications & contracts
└── RClick.xcodeproj             # Xcode project
```

## Common Issues

### Extension Not Loading
- Ensure extension is enabled in System Settings → Privacy & Security → Extensions
- Check that `FIFinderSyncController.default().directoryURLs` is set
- Verify heartbeat messages are being sent/received

### Security-Scope Access Fails
- Ensure bookmarks are stored and retrieved correctly
- Check `isStale` flag and refresh bookmarks if needed
- Always call `stopAccessingSecurityScopedResource()` when done

### SwiftUI Views Not Updating
- Ensure `@MainActor` annotation when updating `@Published` properties
- Use `@StateObject` instead of `@ObservedObject` for view-owned objects
- Remember `AppState.shared` is a singleton - use `@StateObject` appropriately

## Documentation References

- **Feature Specifications**: [specs/](specs/)
- **Git Branch Strategy**: [specs/contracts/git-branch-strategy.md](specs/contracts/git-branch-strategy.md)
