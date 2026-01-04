# Tasks: RClick - macOS Finder Context Menu Extension

**Input**: Design documents from `/specs/001-macos-app-macos/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: DB, middleware, logging
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Single project**: `src/`, `tests/` at repository root
- **Web app**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below assume single project - adjust based on plan.md structure

## Phase 3.1: Setup
- [ ] T001 Create project structure per implementation plan with RClick/, FinderSyncExt/, Views/, Models/, Services/, Extensions/, Assets.xcassets/, Localizations/ directories
- [ ] T002 Initialize Swift project with SwiftUI, Foundation, AppKit, FinderSync, os.log dependencies
- [ ] T003 [P] Configure Xcode project for macOS 15+ with Swift 6.2 and create shared app group for UserDefaults

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [ ] T004 [P] Unit test for Swift 6.2 syntax compliance in RClick/Tests/RClickTests/TestSwift6Syntax.swift
- [ ] T005 [P] Integration test for macOS 15+ API usage in RClick/Tests/RClickTests/TestMacOS15API.swift
- [ ] T006 [P] UI test for SwiftUI components in RClick/Tests/RClickUITests/TestSwiftUIComponents.swift
- [ ] T007 [P] Internationalization test for English/Simplified Chinese in RClick/Tests/RClickTests/TestLocalization.swift
- [ ] T008 [P] Contract test for app-extension communication protocol in RClick/Tests/RClickTests/TestAppExtensionCommunication.swift
- [ ] T009 [P] Unit test for UpdateManager functionality in RClick/Tests/RClickTests/TestUpdateManager.swift
- [ ] T010 [P] Integration test for context menu actions in RClick/Tests/RClickTests/TestContextMenuActions.swift

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [ ] T011 [P] ContextMenuAction model implementation in RClick/Models/ContextMenuAction.swift with Swift 6.2 syntax and validation
- [ ] T012 [P] CustomFileType model implementation in RClick/Models/CustomFileType.swift with Swift 6.2 syntax and validation
- [ ] T013 [P] ExternalApplication model implementation in RClick/Models/ExternalApplication.swift with Swift 6.2 syntax and validation
- [ ] T014 [P] UserConfiguration model implementation in RClick/Models/UserConfiguration.swift with Swift 6.2 syntax and validation
- [ ] T015 [P] UpdateInfo model implementation in RClick/Models/UpdateInfo.swift with Swift 6.2 syntax and validation
- [ ] T016 [P] UpdateManager service implementation in RClick/Services/UpdateManager.swift with GitHub release checking, auto-update functionality, and version ignore tracking
- [ ] T017 [P] AppState shared state management in RClick/Models/AppState.swift with UserDefaults synchronization
- [ ] T018 [P] Messager service for DistributedNotificationCenter communication in RClick/Services/Messager.swift
- [ ] T019 [P] MenuBarView SwiftUI component in RClick/Views/MenuBarView.swift with internationalization support
- [ ] T020 [P] SettingsView SwiftUI component in RClick/Views/SettingsView.swift with configuration UI
- [ ] T021 [P] FinderSyncExt implementation in FinderSyncExt/FinderSyncExt.swift with context menu population
- [ ] T022 [P] URL extensions for file operations in RClick/Extensions/URL+Extensions.swift
- [ ] T023 [P] Localizable strings files for English and Simplified Chinese in RClick/Localizations/en.lproj/Localizable.strings and RClick/Localizations/zh-Hans.lproj/Localizable.strings
- [ ] T024 [P] RClickApp entry point implementation in RClick/RClickApp.swift with SwiftUI lifecycle and update checking on startup
- [ ] T025 [P] Auto-update functionality implementation including GitHub API integration, update checking on startup, version comparison, and installation process in RClick/Services/UpdateManager.swift

## Phase 3.4: Integration
- [ ] T026 Connect UpdateManager with RClickApp lifecycle to check for updates on startup
- [ ] T027 Integrate UserConfiguration with UserDefaults for persistence
- [ ] T028 Connect FinderSyncExt with AppState to update context menu based on configuration
- [ ] T029 Configure FinderSyncExt entitlements and Info.plist for proper extension functionality
- [ ] T030 Implement communication between Finder extension and main app via DistributedNotificationCenter
- [ ] T031 Add file operation security checks to prevent unauthorized access

## Phase 3.5: Polish
- [ ] T032 [P] Unit tests for all models in RClick/Tests/RClickTests/ with 100% coverage
- [ ] T033 [P] UI tests for all views in RClick/Tests/RClickUITests/
- [ ] T034 [P] Integration tests for app-extension communication in RClick/Tests/RClickTests/
- [ ] T035 Performance tests to ensure <200ms response for context menu actions in RClick/Tests/RClickTests/
- [ ] T036 [P] Update documentation in docs/README.md
- [ ] T037 Add complex code documentation as required by constitution to all service implementations
- [ ] T038 Run manual-testing.md verification steps

## Dependencies
- Tests (T004-T010) before implementation (T011-T025)
- T016 blocks T026 (UpdateManager before connecting to app lifecycle)
- T017 blocks T028 (AppState before integration with FinderSync)
- T014 (UserConfiguration) blocks T027 (UserDefaults integration)
- Implementation before polish (T032-T038)

## Parallel Example
```
# Launch T011-T015 together:
Task: "ContextMenuAction model implementation in RClick/Models/ContextMenuAction.swift with Swift 6.2 syntax and validation"
Task: "CustomFileType model implementation in RClick/Models/CustomFileType.swift with Swift 6.2 syntax and validation"
Task: "ExternalApplication model implementation in RClick/Models/ExternalApplication.swift with Swift 6.2 syntax and validation"
Task: "UserConfiguration model implementation in RClick/Models/UserConfiguration.swift with Swift 6.2 syntax and validation"
Task: "UpdateInfo model implementation in RClick/Models/UpdateInfo.swift with Swift 6.2 syntax and validation"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing
- Commit after each task
- Avoid: vague tasks, same file conflicts

## Task Generation Rules
*Applied during main() execution*

1. **From Contracts**:
   - Each contract file → Swift 6.2 compliant contract test task [P]
   - Each endpoint → implementation task using SwiftUI-first approach
   
2. **From Data Model**:
   - Each entity → Swift 6.2 model creation task [P]
   - Relationships → service layer tasks for macOS 15+ only
   
3. **From User Stories**:
   - Each story → SwiftUI UI test [P]
   - Each story → internationalization validation test
   - Quickstart scenarios → validation tasks

4. **Ordering**:
   - Setup → Tests → Models → Services → SwiftUI Components → Polish
   - Dependencies block parallel execution
   
5. **Constitution Compliance**:
   - Each implementation task must verify SwiftUI-first requirement
   - Complex implementations must include documentation as per constitution
   - Internationalization tasks must be created for all user-facing elements

## Update Manager Specific Tasks
- [ ] T025.1 Implement GitHub API client in RClick/Services/UpdateManager.swift to fetch latest release information from wflixu/RClick repository
- [ ] T025.2 Implement version comparison logic in RClick/Services/UpdateManager.swift to check if current version is outdated
- [ ] T025.3 Implement update notification UI in RClick/Views/SettingsView.swift that appears when new version is available
- [ ] T025.4 Implement "ignore this version" functionality in RClick/Services/UpdateManager.swift to store ignored versions in UserDefaults
- [ ] T025.5 Implement download and installation process for updates in RClick/Services/UpdateManager.swift with proper error handling
- [ ] T025.6 Implement update check trigger from UI button in RClick/Views/SettingsView.swift
- [ ] T025.7 Implement restart application after successful update installation in RClick/Services/UpdateManager.swift
- [ ] T025.8 Add update checking logic on application startup in RClick/RClickApp.swift
- [ ] T025.9 Implement user defaults key for storing ignored versions in Key.swift
- [ ] T025.10 Add proper error handling and logging for update operations using os.log framework

## Validation Checklist
*GATE: Checked by main() before returning*

- [x] All contracts have corresponding tests
- [x] All entities have model tasks
- [x] All tests come before implementation
- [x] Parallel tasks truly independent
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task