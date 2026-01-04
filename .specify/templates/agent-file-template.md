# RClick Development Guidelines

Auto-generated from all feature plans. Last updated: [DATE]

## Active Technologies
- Swift 6.2 (required by RClick Constitution)
- SwiftUI (UI framework - required by RClick Constitution)
- AppKit (system integration only, no UI components per RClick Constitution)
- FinderSync (Finder extension framework)
- os.log (logging framework)
- Xcode 16+ (development environment)

## Project Structure
```
RClick/
├── RClickApp.swift          # Main application entry point
├── Views/                   # SwiftUI views directory
├── Models/                  # Data models using Swift 6.2 syntax
├── Services/                # Business logic services
├── Utils/                   # Utility functions and helpers
├── Assets.xcassets/         # App assets
├── Localizations/           # English and Simplified Chinese strings
└── Extensions/              # Swift extensions
```

## Commands
- `xcodebuild -project RClick.xcodeproj -scheme RClick -destination 'platform=macOS'` - Build project
- `swiftlint` - Run Swift code linter
- `xcodebuild test -project RClick.xcodeproj -scheme RClick -destination 'platform=macOS'` - Run tests

## Code Style
- All code MUST use Swift 6.2 syntax features
- All UI components MUST be implemented with SwiftUI (no AppKit UI)
- Target macOS 15 Sequoia and above only
- Complex implementations MUST include comprehensive documentation
- All user-facing strings MUST be internationalized (English primary, Simplified Chinese secondary)

## Recent Changes
[LAST 3 FEATURES AND WHAT THEY ADDED]

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->