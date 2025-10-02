# Data Model: RClick macOS Finder Context Menu Extension

## Entity: ContextMenuAction
- **Fields**:
  - id: String (unique identifier)
  - name: String (display name for the menu item)
  - type: ActionType (enum: copyPath, delete, createFile, openWithApp, etc.)
  - enabled: Bool (whether the action is currently enabled)
  - parameters: [String: Any] (additional parameters for the action)
- **Relationships**: None
- **Validation Rules**: 
  - id must be unique per user configuration
  - name must not be empty
  - type must be one of the allowed action types

## Entity: CustomFileType
- **Fields**:
  - id: String (unique identifier)
  - name: String (display name for the file type)
  - extension: String (file extension including the dot, e.g. ".json")
  - template: URL? (optional template file for new files)
  - icon: String? (optional icon identifier)
- **Relationships**: None
- **Validation Rules**:
  - id must be unique per user configuration
  - extension must start with a dot
  - name must not be empty

## Entity: ExternalApplication
- **Fields**:
  - id: String (unique identifier, typically bundle ID)
  - name: String (display name of the application)
  - bundlePath: String (path to the application bundle)
  - supportedTypes: [String] (file extensions this app can handle)
  - arguments: [String] (command line arguments to pass)
- **Relationships**: None
- **Validation Rules**:
  - id (bundle ID) must correspond to an actual installed application
  - bundlePath must point to a valid application
  - supportedTypes must be valid file extensions

## Entity: UserConfiguration
- **Fields**:
  - contextMenuActions: [ContextMenuAction] (list of user-defined context menu actions)
  - customFileTypes: [CustomFileType] (list of user-defined file types for creation)
  - externalApps: [ExternalApplication] (list of user-configured external applications)
  - updateCheckEnabled: Bool (whether to automatically check for updates)
  - language: String (user's preferred language)
- **Relationships**: Contains multiple ContextMenuAction, CustomFileType, and ExternalApplication entities
- **Validation Rules**:
  - Each contained entity must pass its own validation
  - Lists must not contain duplicate IDs

## Entity: UpdateInfo
- **Fields**:
  - version: String (version string of the available update)
  - downloadURL: URL (URL to download the update)
  - releaseNotes: String? (optional release notes for the update)
  - releaseDate: Date? (optional release date)
- **Relationships**: None
- **Validation Rules**:
  - version must follow semantic versioning format
  - downloadURL must be a valid HTTPS URL
  - releaseNotes should not exceed 10,000 characters

## State Transitions
- **ContextMenuAction**: 
  - Created → Configured → Active → Disabled (when system restrictions apply)
- **UserConfiguration**:
  - Created → Modified → Saved → Loaded (in app and extension)
- **UpdateInfo**:
  - Fetched → Validated → Ready to Install → Installed

## Relationships
- UserConfiguration contains collections of ContextMenuAction, CustomFileType, and ExternalApplication
- All entities support localization through the constitutional requirement of String(localized:)

## Constraints
- All user-facing strings must be localizable using String(localized:) as per constitutional requirement
- Complex implementations (like file creation with templates) must include documentation as per constitutional requirement
- All code must use Swift 6.2 syntax features as per constitutional requirement
- Data must be stored using UserDefaults as specified in the requirements