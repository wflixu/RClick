# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
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
- [ ] T001 Create project structure per implementation plan
- [ ] T002 Initialize [language] project with [framework] dependencies
- [ ] T003 [P] Configure linting and formatting tools

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [ ] T004 [P] Unit test for Swift 6.2 syntax compliance in tests/unit/test_swift6_syntax.swift
- [ ] T005 [P] Integration test for macOS 15+ API usage in tests/integration/test_macos15_api.swift
- [ ] T006 [P] UI test for SwiftUI components in tests/ui/test_swiftui_components.swift
- [ ] T007 [P] Internationalization test for English/Simplified Chinese in tests/i18n/test_localization.swift

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [ ] T008 [P] SwiftUI View implementation in RClick/Views/ in accordance with SwiftUI-first principle
- [ ] T009 [P] Model implementation with Swift 6.2 syntax in RClick/Models/
- [ ] T010 [P] Service layer for macOS 15+ exclusive features in RClick/Services/
- [ ] T011 Internationalization implementation with English/Simplified Chinese support in RClick/Localization/
- [ ] T012 Complex code documentation as required by constitution in appropriate files
- [ ] T013 Error handling and logging using os.log
- [ ] T014 AppKit usage limited to system integration only (not UI)

## Phase 3.4: Integration
- [ ] T015 Connect UserService to DB
- [ ] T016 Auth middleware
- [ ] T017 Request/response logging
- [ ] T018 CORS and security headers

## Phase 3.5: Polish
- [ ] T019 [P] Unit tests for validation in tests/unit/test_validation.py
- [ ] T020 Performance tests (<200ms)
- [ ] T021 [P] Update docs/api.md
- [ ] T022 Remove duplication
- [ ] T023 Run manual-testing.md

## Dependencies
- Tests (T004-T007) before implementation (T008-T014)
- T008 blocks T009, T015
- T016 blocks T018
- Implementation before polish (T019-T023)

## Parallel Example
```
# Launch T004-T007 together:
Task: "Contract test POST /api/users in tests/contract/test_users_post.py"
Task: "Contract test GET /api/users/{id} in tests/contract/test_users_get.py"
Task: "Integration test registration in tests/integration/test_registration.py"
Task: "Integration test auth in tests/integration/test_auth.py"
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

## Validation Checklist
*GATE: Checked by main() before returning*

- [ ] All contracts have corresponding tests
- [ ] All entities have model tasks
- [ ] All tests come before implementation
- [ ] Parallel tasks truly independent
- [ ] Each task specifies exact file path
- [ ] No task modifies same file as another [P] task