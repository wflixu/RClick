# Tasks: SwiftData Transformation

**Version**: 1.7.2 (Build 20260104001)
**Updated**: 2026-01-04
**Input**: Design documents for SwiftData migration of PermissiveDir model
**Prerequisites**: Existing SwiftData setup in RClick app, including shared ModelContainer

## Execution Flow (main)
```
1. Load implementation details from existing codebase
   → Extract: current SwiftData setup, PermDir model, PermissiveDir struct
2. Identify data migration requirements:
   → From UserDefaults storage to SwiftData for PermissiveDir
   → Ensure compatibility between main app and extension via App Group
3. Generate tasks by category:
   → Setup: Extend existing SwiftData models
   → Tests: Data persistence and access tests
   → Core: Model transformation and migration
   → Integration: Extension access to SwiftData models
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **RClick app**: `RClick/` directory
- **FinderSync extension**: `FinderSyncExt/` directory
- **Models**: `RClick/Model/` directory

## Phase 3.1: Setup
- [ ] T001 Extend Models.swift to include PermissiveDir SwiftData model in RClick/Model/Models.swift
- [ ] T002 Update ModelContainer.swift to include PermissiveDir in model schema
- [ ] T003 [P] Verify existing SwiftData setup works correctly

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

- [ ] T004 [P] Unit test for PermDir SwiftData model operations in tests/unit/test_perm_dir_model.swift
- [ ] T005 [P] Unit test for PermissiveDir SwiftData model operations in tests/unit/test_permissive_dir_model.swift
- [ ] T006 [P] Integration test for SwiftData access from main app in tests/integration/test_main_app_data_access.swift
- [ ] T007 [P] Integration test for SwiftData access from extension in tests/integration/test_extension_data_access.swift
- [ ] T008 [P] Test data migration from UserDefaults to SwiftData in tests/unit/test_data_migration.swift

## Phase 3.3: Core Implementation (ONLY after tests are failing)

- [ ] T009 Implement PermissiveDir SwiftData model in RClick/Model/Models.swift
- [ ] T010 Create helper functions to convert between PermissiveDir struct and model in RClick/Model/Models.swift
- [ ] T011 Update AppState.swift to use SwiftData instead of UserDefaults for PermissiveDir storage
- [ ] T012 Implement data migration from UserDefaults to SwiftData in AppState.swift
- [ ] T013 Update FinderSyncExt to access PermissiveDir data from SwiftData
- [ ] T014 Implement proper error handling for SwiftData operations in all components
- [ ] T015 Add documentation for complex SwiftData operations as required by constitutional requirement

## Phase 3.4: Integration
- [ ] T016 Connect SwiftData model access in both main app and extension
- [ ] T017 Verify data synchronization between main app and extension via shared database
- [ ] T018 Test security-scoped resource access with SwiftData stored bookmarks

## Phase 3.5: Polish
- [ ] T019 [P] Unit tests for all SwiftData operations
- [ ] T020 Performance tests to ensure <200ms response for context menu actions
- [ ] T021 [P] Update documentation for SwiftData model usage
- [ ] T022 Verify data consistency between main app and extension
- [ ] T023 Run manual testing of folder permission features

## Dependencies
- T001-T002 before T009, T010 (model definitions)
- Tests (T004-T008) before implementation (T009-T015)
- T009 blocks T010, T011
- T010 blocks T012
- T011 blocks T013
- Implementation before polish (T019-T023)

## Parallel Example
```
# Launch T004-T008 together:
Task: "Unit test for PermDir SwiftData model operations in tests/unit/test_perm_dir_model.swift"
Task: "Unit test for PermissiveDir SwiftData model operations in tests/unit/test_permissive_dir_model.swift"
Task: "Integration test for SwiftData access from main app in tests/integration/test_main_app_data_access.swift"
Task: "Integration test for SwiftData access from extension in tests/integration/test_extension_data_access.swift"
Task: "Test data migration from UserDefaults to SwiftData in tests/unit/test_data_migration.swift"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing
- Commit after each task
- Avoid: vague tasks, same file conflicts

## Task Generation Rules
*Applied during main() execution*

1. **From Requirements**:
   - PermissiveDir model migration → SwiftData compliant model task [P]
   - Extension access requirement → extension integration task
   - Data synchronization → shared database task
   
2. **From Existing Implementation**:
   - Current PermDir model → model extension task [P]
   - PermissiveDir struct in RCBase.swift → transformation to @Model task [P]
   - UserDefaults usage in AppState.swift → migration task
   
3. **From User Stories**:
   - Folder permission management → UI access to SwiftData models
   - Data synchronization between app and extension → shared database access

4. **Ordering**:
   - Setup → Tests → Model Transformation → Integration → Polish
   - Dependencies block parallel execution
   
5. **Constitution Compliance**:
   - Each implementation task must verify SwiftUI-first requirement where applicable
   - Complex implementations must include documentation as per constitution

## Validation Checklist
*GATE: Checked by main() before returning*

- [ ] All SwiftData model migrations have corresponding tests
- [ ] All models have SwiftData migration tasks
- [ ] All tests come before implementation
- [ ] Parallel tasks truly independent
- [ ] Each task specifies exact file path
- [ ] No task modifies same file as another [P] task
- [ ] Extension can access SwiftData models correctly
- [ ] Data migration from UserDefaults to SwiftData is implemented