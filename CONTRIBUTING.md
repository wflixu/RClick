# Contributing to RClick

Thank you for your interest in contributing to RClick! 🎉

RClick is a macOS Finder enhancement tool built with Swift 6.2 and SwiftUI. This guide will help you get set up and make your first contribution.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
  - [Development Environment](#development-environment)
  - [Building the Project](#building-the-project)
  - [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
  - [Branching Strategy](#branching-strategy)
  - [Commit Conventions](#commit-conventions)
  - [Pull Request Process](#pull-request-process)
- [Coding Guidelines](#coding-guidelines)
  - [Swift Style](#swift-style)
  - [SwiftUI Best Practices](#swiftui-best-practices)
  - [Architecture Constraints](#architecture-constraints)
- [Testing](#testing)
- [Finding Issues to Work On](#finding-issues-to-work-on)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## Getting Started

### Development Environment

| Tool | Version |
|------|---------|
| **macOS** | 15.6 (Sequoia) or later |
| **Xcode** | 16.4 or later |
| **Swift** | 6.2 or later |

### Building the Project

```bash
# Clone the repository
git clone https://github.com/wflixu/RClick.git
cd RClick

# Open in Xcode
open RClick.xcodeproj

# Or build from CLI
xcodebuild -project RClick.xcodeproj -scheme RClick -destination 'platform=macOS'
```

> **Note:** The FinderSync Extension requires code signing. When building for development, Xcode will automatically use your development team. You may need to adjust the signing settings in **Signing & Capabilities**.

### Project Structure

```
RClick/
├── RClick/                    # Main application target
│   ├── RClickApp.swift        # App entry point
│   ├── AppState.swift         # Global state management
│   ├── Model/                 # SwiftData models
│   ├── Settings/              # Settings UI (SwiftUI)
│   ├── Shared/                # Utilities & services
│   └── Assets.xcassets/       # Images, icons, templates
├── FinderSyncExt/             # Finder extension target
│   ├── FinderSyncExt.swift    # Extension entry point
│   └── MenuItemClickable.swift # Menu item handlers
└── specs/                     # Feature specifications & contracts
```

## Development Workflow

### Branching Strategy

- **`main`** — Production-ready releases. Always stable.
- **`dev`** — Integration branch. All feature branches merge here first.
- **Feature branches** — `feature/your-feature-name` or `fix/your-bug-fix`

```bash
# Start new feature
git checkout dev
git pull origin dev
git checkout -b feature/my-new-feature

# Start a bug fix
git checkout -b fix/my-bug-fix
```

### Commit Conventions

We follow [Conventional Commits](https://www.conventionalcommits.org/). Please structure your commit messages as:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**

| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `refactor` | Code refactoring (no feature/fix) |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `chore` | Build, CI, dependencies |
| `style` | Formatting, whitespace |

**Examples:**
```
feat(settings): add dark mode toggle to general settings
fix(finder): resolve menu item not appearing on first launch
docs: update README with installation guide
refactor(ipc): simplify messaging layer with async/await
```

### Pull Request Process

1. **Fork** the repository and create your branch from `dev`.
2. **Implement** your changes, following the coding guidelines below.
3. **Test** your changes thoroughly (build, run, verify in Finder).
4. **Update documentation** if your changes affect user-facing behavior.
5. **Submit a PR** targeting the `dev` branch.
6. **Fill out the PR template** — describe what changed, why, and how to test.
7. **Wait for review** — a maintainer will review your PR. CI checks must pass.

**PR titles** should also follow Conventional Commits, e.g., `feat: add AirDrop sharing support`.

## Coding Guidelines

### Swift Style

- Use **Swift 6.2** syntax — no legacy patterns.
- Prefer `let` over `var` where possible.
- Use `async/await` for concurrency. Avoid completion handlers.
- Use `@MainActor` when updating `@Published` properties from background contexts.
- Mark types and methods with appropriate access control (`private`, `internal`).
- Use `guard` for early returns, not nested `if` statements.
- Prefer value types (`struct`, `enum`) over reference types when identity isn't needed.

### SwiftUI Best Practices

- **All UI must be SwiftUI** — no AppKit UI components (e.g., no `NSViewRepresentable` wrappers for visual elements).
- **AppKit is ONLY for system integration**: `NSWorkspace`, `NSPasteboard`, file operations, etc.
- Use `@StateObject` for view-owned `ObservableObject` instances; use `@ObservedObject` for injected ones.
- Keep views small and composable. Extract reusable components.
- Use SF Symbols for icons to ensure native look and dark mode support.

### Architecture Constraints

These are **hard constraints** from the project constitution:

1. **Swift 6.2 syntax only** — no older Swift patterns.
2. **SwiftUI for all UI** — no AppKit UI components.
3. **AppKit limited to system integration** — `NSWorkspace`, `NSPasteboard`, file operations, etc.
4. **Target macOS 15 Sequoia and above only** — no backward compatibility hacks.

**Dual-Process Communication:**
- Main app and FinderSync Extension communicate via `DistributedNotificationCenter`.
- Message protocol is defined in `RClick/Shared/Messager.swift`.
- Always handle `isHostAppOpen` state — don't block if the main app isn't running.

## Testing

Before submitting a PR, please verify:

```bash
# Build the main app
xcodebuild -project RClick.xcodeproj -scheme RClick -destination 'platform=macOS'

# Build the extension
xcodebuild -project RClick.xcodeproj -scheme FinderSyncExt -destination 'platform=macOS'

# Run tests (if applicable)
xcodebuild test -project RClick.xcodeproj -scheme RClick -destination 'platform=macOS'
```

**Manual testing checklist:**
- [ ] App launches and appears in the menu bar
- [ ] Right-click menu appears in Finder with all configured items
- [ ] Dark mode works correctly (icons adapt)
- [ ] Settings persist across app restarts
- [ ] File operations work (create, delete, copy path, etc.)
- [ ] Extension loads after system restart

## Finding Issues to Work On

- Browse [open issues](https://github.com/wflixu/RClick/issues) — look for **`good first issue`** or **`help wanted`** labels.
- If you have an idea, [open a discussion](https://github.com/wflixu/RClick/issues) first to get feedback before writing code.

---

Thank you for contributing! 🚀
