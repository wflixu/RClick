<!--
Sync Impact Report:
- Version change: N/A (initial version) → 1.0.0
- Modified principles: All principles are new in initial version
- Added sections: All sections are new (Core Principles, Technical Constraints, Development Workflow, Governance)
- Removed sections: N/A
- Templates requiring updates: 
  - .specify/templates/plan-template.md: ✅ updated
  - .specify/templates/spec-template.md: ✅ updated  
  - .specify/templates/tasks-template.md: ✅ updated
  - .specify/templates/agent-file-template.md: ✅ updated
- Follow-up TODOs: 
  - TODO(RATIFICATION_DATE): Original adoption date unknown
-->

# RClick Constitution

## Core Principles

### Swift 6.2 Modern Syntax Standard
All Swift code in the RClick project MUST utilize Swift 6.2 syntax and language features. This includes modern optional binding, pattern matching, property wrappers, and other contemporary Swift language constructs. Code written in legacy Swift syntax is prohibited unless specifically required for external library compatibility that cannot be updated.

### macOS 15+ Target Platform Exclusivity
The RClick application MUST target macOS 15 (Sequoia) and above exclusively. The application will not support earlier macOS versions, and no compatibility patches or workarounds for older systems will be accepted. This ensures optimal utilization of the latest Apple frameworks and APIs while maintaining development focus on modern systems.

### SwiftUI-First Architecture
All user interface components in the RClick project MUST be implemented using SwiftUI. UIKit and AppKit components are prohibited unless absolutely required for system-level integration that SwiftUI does not support. Complex UI implementations SHOULD leverage SwiftUI's declarative syntax, property wrappers, and ViewBuilder patterns for maintainable and readable code.

### Internationalization-First Design
Every user-facing element in RClick MUST be designed with internationalization from the start. All user-visible strings MUST be localized using Swift's `String(localized:)` syntax or similar internationalization mechanisms. English is the primary supported language with Simplified Chinese as the secondary language. Additional languages MAY be added as needed. Any code that hardcodes strings directly in the source is prohibited.

### Complex Code Documentation Requirement
Any code implementation deemed complex by the development team MUST include comprehensive documentation explaining the purpose, functionality, and design decisions. Complex code sections SHOULD be annotated with detailed comments explaining the implementation logic, edge cases handled, and potential future considerations.

## Technical Constraints

### SwiftUI vs AppKit Prohibition
The RClick project strictly prohibits the use of AppKit for UI components. SwiftUI is the exclusive UI framework. AppKit may only be used for system-level integrations where SwiftUI equivalents are not available.

### Internationalization Standards
Support for English as the first language and Simplified Chinese as the second language is mandatory. All UI strings, error messages, and user-facing content MUST be available in both languages before release. Localization files MUST be maintained for both language sets with consistent terminology and formatting.

## Development Workflow

### Code Review Compliance
All pull requests MUST be reviewed for compliance with the above principles before merging. Reviewers are required to verify that Swift 6.2 syntax is used appropriately, macOS 15+ APIs are leveraged correctly, SwiftUI is used as the exclusive UI framework, and internationalization requirements are met. Complex code sections without proper documentation will be rejected during review.

### Testing Standards
All new features MUST include appropriate unit tests and UI tests to ensure functionality across supported languages and platforms. Testing MUST verify the application functions correctly on macOS 15 and above, with special attention to internationalization behavior.

## Governance

The RClick Constitution supersedes all other development practices and guidelines. Amendments to this constitution require explicit documentation of changes, approval from project maintainers, and a migration plan for existing code. All development activities must verify compliance with these principles. Complexity in implementations must be justified through documentation as required by the Complex Code Documentation Principle.

**Version**: 1.0.0 | **Ratified**: TODO(RATIFICATION_DATE) | **Last Amended**: 2025-10-02