# Research: RClick macOS Finder Context Menu Extension

## Decision: FinderSync Extension Implementation
**Rationale**: FinderSync extensions are the Apple-recommended approach for extending Finder's context menu with custom actions. They provide a clean separation between the main application and the Finder extension while allowing rich interaction capabilities.

## Alternatives Considered:
1. **Service Management (NSMenuItem)**: Traditional approach but requires the main app to be running and is less efficient.
2. **Quick Action Extensions**: Limited functionality and not available in macOS for custom Finder context menu items.
3. **FinderSync Extension**: Most robust and recommended by Apple for extending Finder functionality.

## Decision: DistributedNotificationCenter Communication
**Rationale**: DistributedNotificationCenter is the recommended approach for communication between a main application and its extension. It allows asynchronous messaging across process boundaries and maintains clean separation of concerns.

**Alternatives Considered**:
1. **Shared File Storage**: Could work but lacks real-time communication capabilities needed for menu updates.
2. **User Defaults**: Good for data persistence but not for real-time messaging.
3. **DistributedNotificationCenter**: Provides real-time messaging across process boundaries, ideal for app-extension communication.

## Decision: String(localized:) Internationalization
**Rationale**: Swift's `String(localized:)` function provides the modern, recommended approach for internationalization that aligns with the constitutional requirement. It leverages the `.localized` strings files and integrates well with SwiftUI.

**Alternatives Considered**:
1. **NSLocalizedString**: Traditional Objective-C approach, still valid but less modern.
2. **String(localized:)**: Modern Swift approach, clean syntax, and aligns with Swift 6.2 constitutional requirement.

## Key Findings:
- FinderSync extensions require specific entitlements and Info.plist configurations
- Communication between main app and extension should use DistributedNotificationCenter
- Data synchronization between app and extension should use shared UserDefaults container
- SwiftUI views can be localized using `String(localized:)` with appropriate .strings files in localization directories
- Context menu items in FinderSync can be dynamically updated based on user configuration in the main app
- Menu structure can be hierarchical with submenus for different types of actions (file creation, deletion, etc.)

## Implementation Considerations:
- Extension lifecycle is independent of main app and may be terminated/restarted by the system
- Configuration changes in main app need to be communicated to extension to update context menu items
- File operations should handle permissions appropriately, especially for system directories
- Custom file type creation requires template files or default content for each supported type