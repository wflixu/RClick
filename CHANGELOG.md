# Changelog

All notable changes to RClick are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.0.4] - 2026-07-05

### Fixed
- Add sandbox entitlement for FinderSyncExt to fix menu rendering in protected directories
- Set proper icons for collapsed parent menus in FinderSync
- Isolate DMG and ZIP staging into separate subdirectories to prevent artifact corruption
- Prevent nested `.app` in release ZIP caused by stale DMG temp copy

### Changed
- Bump `actions/checkout` from v4 to v5 in CI workflows

## [2.0.3] - 2026-07-04

### Fixed
- Preserve `.app` bundle structure in release ZIP archive
- Use `cp` + `ditto` + `keepParent` for correct `.app` ZIP packaging
- Avoid nested `.app` in release ZIP and DMG artifacts
- Remove stale "Create Blank File" menu item; add missing localization entries

### Added
- CI: GitHub Actions workflows for PR build verification and tag-triggered release

### Changed
- Select latest available Xcode version on CI runner
- Lower `objectVersion` for Xcode 26.0.1 CI compatibility

## [2.0.1] - 2026-06-28

### Added
- Trilingual localization with String Catalogs (zh-Hans, en, ja)
- Editable blank file creation from templates
- Draggable settings menu ordering for customizing menu appearance
- Quick-access folders master toggle (default off)
- CI: Add GitHub Actions workflows for PR build and tag release

### Fixed
- FinderSync menu click unresponsiveness after localization refactor
- Sandbox permission issues for FinderSync Extension
- VS Code detection with percent-encoded path double-encoding
- Toolbar icons disappearing after settings refactor
- Heartbeat monitoring logic for extension health checks
- Menu item default values and collapse toggle not applying correctly
- Chinese menu title truncation in Finder context menu
- Common folders icon not matching system directory appearance
- Dark mode icon adaptation for SF Symbols using `paletteColors`
- File type icon three-level fallback strategy
- `onChange(of:)` deprecation warning on macOS 14+

### Changed
- Swift 5 → Swift 6.2 migration with full concurrency checking
- Settings UI refactored to unified `Form` layout
- macOS 15.6 + Xcode 16.4 compatibility as minimum requirement
- Menu icon loading now uses memory cache for instant display
- New file icons prioritize system app icons when available
- FDA (Full Disk Access) permission guidance and detection

### Performance
- Menu icon loading now uses memory cache for instant display on subsequent right-clicks

## [1.7.2] - 2025-09-27

### Changed
- Code signing and entitlements configuration for FinderSync Extension
- Improved extension loading reliability

## [1.7.0] - 2025-09-27

### Added
- Initial stable release with core Finder context menu features
- Open with External App support
- Copy Path functionality
- Delete Directly (bypass Trash)
- Hide / Unhide file toggle
- AirDrop sharing
- Create New Files from templates
- Quick Access Folders
- Dark Mode support

---

[2.0.4]: https://github.com/wflixu/RClick/releases/tag/v2.0.4
[2.0.3]: https://github.com/wflixu/RClick/releases/tag/v2.0.3
[2.0.1]: https://github.com/wflixu/RClick/releases/tag/v2.0.1
[1.7.2]: https://github.com/wflixu/RClick/releases/tag/v1.7.2
[1.7.0]: https://github.com/wflixu/RClick/releases/tag/v1.7.0
