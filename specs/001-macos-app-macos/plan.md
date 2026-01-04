# Implementation Plan: RClick - macOS Finder Context Menu Extension

**Branch**: `001-macos-app-macos` | **Date**: 2025-10-02 | **Spec**: [link]
**Input**: Feature specification from `/specs/001-macos-app-macos/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
RClick is a macOS application that extends Finder's context menu with additional functionality such as copying file paths, creating files, opening with custom applications, and deleting files directly. The application uses Swift 6.2 and SwiftUI, supports macOS 15+, includes a FinderSync extension, and communicates between the extension and main app via DistributedNotificationCenter. User data is stored locally using UserDefaults.

## Technical Context
**Language/Version**: Swift 6.2 (RClick Constitution requirement)  
**Primary Dependencies**: SwiftUI, Foundation, AppKit (for system integration only), FinderSync, os.log, DistributedNotificationCenter, UserDefaults  
**Storage**: UserDefaults for local data persistence and sharing between main app and extension  
**Testing**: XCTest for unit and integration testing  
**Target Platform**: macOS 15 Sequoia and above (RClick Constitution requirement)  
**Project Type**: native macOS application with FinderSync extension - determines source structure  
**Performance Goals**: <200ms response for context menu actions, smooth UI interactions  
**Constraints**: SwiftUI-first UI (RClick Constitution requirement), no AppKit UI components, complex code requires documentation (RClick Constitution requirement)  
**Scale/Scope**: 50+ context menu options, supporting file types (JSON, Markdown, DOCX, PPTX, custom types), custom applications for opening files

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

1. Swift 6.2 syntax compliance: All code MUST use modern Swift 6.2 language features
2. macOS 15+ target: Implementation MUST NOT include compatibility for earlier macOS versions
3. SwiftUI-first architecture: All UI elements MUST be implemented using SwiftUI (no AppKit UI components)
4. Internationalization compliance: All user-facing strings MUST be localized using String(localized:) or similar mechanisms
5. Code documentation: Complex implementations MUST include comprehensive comments explaining design decisions

## Project Structure

### Documentation (this feature)
```
specs/001-macos-app-macos/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
RClick/
├── RClickApp.swift              # Main application entry point
├── Views/                       # SwiftUI views directory
│   ├── SettingsView.swift       # Settings UI
│   ├── ContentView.swift        # Main app UI
│   └── MenuBarView.swift        # Menu bar UI
├── Models/                      # Data models using Swift 6.2 syntax
│   ├── AppState.swift           # Shared application state
│   ├── RCItem.swift             # Context menu item model
│   ├── CustomFileType.swift     # Custom file type model
│   └── ExternalApp.swift        # External application model
├── Services/                    # Business logic services
│   ├── UpdateManager.swift      # GitHub release update service
│   ├── Messager.swift           # Communication service using DistributedNotificationCenter
│   └── Utils.swift              # Utility functions
├── Extensions/                  # Swift extensions
│   └── URL+Extensions.swift     # URL helper extensions
├── Assets.xcassets/             # App assets
├── Localizations/               # English and Simplified Chinese strings
│   ├── en.lproj/
│   └── zh-Hans.lproj/
├── RClick.xcodeproj/            # Xcode project
├── FinderSyncExt/               # FinderSync extension
│   ├── FinderSyncExt.swift      # FinderSync extension logic
│   ├── MenuItemClickable.swift  # Clickable menu item in extension
│   └── Info.plist               # Extension configuration
└── Tests/                       # Unit and UI tests
    ├── RClickTests/
    └── RClickUITests/
```

**Structure Decision**: Single native macOS application with separate FinderSync extension target. The main app handles UI and data management using SwiftUI, while the extension provides context menu functionality. Both targets share code through a common framework or shared files. Communication occurs via DistributedNotificationCenter and data is synchronized through shared UserDefaults container.

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - Research: FinderSync extension implementation patterns
   - Research: DistributedNotificationCenter communication between app and extension
   - Research: SwiftUI localization with String(localized:) for English and Simplified Chinese

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research FinderSync extension implementation patterns for context menu items"
   For each technology choice:
     Task: "Find best practices for DistributedNotificationCenter communication between app and extension"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh qwen`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Each contract → contract test task [P]
- Each entity → model creation task [P] 
- Each user story → integration test task
- Implementation tasks to make tests pass

**Ordering Strategy**:
- TDD order: Tests before implementation 
- Dependency order: Models before services before UI
- Mark [P] for parallel execution (independent files)

**Estimated Output**: 25-30 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [x] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [ ] Complexity deviations documented

---
*Based on Constitution v1.0.0 - See `/memory/constitution.md`*