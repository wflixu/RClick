import AppKit
import Testing

@testable import RClick

/// Covers what the custom menu file currently *means*, and how failures are
/// explained. Every case passes an explicit URL: under the test host the default
/// URL resolves to the real App Group container, which tests must never touch.
@MainActor
struct CustomMenuStatusTests {
    private var catalog: MenuConfigPayload {
        MenuConfigPayload(
            actions: [ActionMenuItem(id: "copy-path", name: "Copy Path", icon: "doc", tag: 1)],
            apps: [
                AppMenuItem(id: "zed-id", name: "Zed", icon: "app", tag: 2,
                            appURL: "/Applications/Zed.app")
            ],
            newFiles: [
                NewFileMenuItem(id: "txt-id", name: "TXT", ext: ".txt", icon: "doc")
            ]
        )
    }

    private func temporaryFile(_ json: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-status-\(UUID()).json")
        try Data(json.utf8).write(to: url)
        return url
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-status-\(UUID())")
    }

    /// The settled state: the file on disk is exactly what is in effect.
    private func appliedStatus(of json: String, config: MenuConfigPayload? = nil) throws -> CustomMenuStatus {
        let url = try temporaryFile(json)
        defer { try? FileManager.default.removeItem(at: url) }
        return MenuService.customMenuStatus(at: url, appliedData: Data(json.utf8),
                                            config: config ?? catalog)
    }

    /// The file exists but was never applied, so nothing of it is in effect.
    private func draftStatus(of json: String, config: MenuConfigPayload? = nil) throws -> CustomMenuStatus {
        let url = try temporaryFile(json)
        defer { try? FileManager.default.removeItem(at: url) }
        return MenuService.customMenuStatus(at: url, appliedData: nil, config: config ?? catalog)
    }

    /// Loads `json` expecting rejection, and hands back the error it raised.
    private func rejection(of json: String) throws -> any Error {
        let url = try temporaryFile(json)
        defer { try? FileManager.default.removeItem(at: url) }
        let thrown = #expect(throws: (any Error).self) {
            _ = try CustomMenu.load(from: url, config: catalog)
        }
        return try #require(thrown)
    }

    // MARK: - What the menu is rendering

    @Test func noFileMeansDefaultLayout() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-absent-\(UUID()).json")
        #expect(MenuService.customMenuStatus(at: url, appliedData: nil, config: catalog)
            == CustomMenuStatus(applied: .defaultLayout, notice: .none))
    }

    @Test func noContainerMeansUnavailable() {
        // Previously indistinguishable from "no file": both produced a nil payload.
        #expect(MenuService.customMenuStatus(at: nil, appliedData: nil, config: catalog)
            == CustomMenuStatus(applied: .unavailable, notice: .none))
    }

    @Test func emptyArrayIsEmptyNotInvalid() throws {
        // An empty array is a deliberate request for an empty menu, not a failure.
        #expect(try appliedStatus(of: "[]") == CustomMenuStatus(applied: .empty, notice: .none))
    }

    @Test func appliedLayoutReportsTopLevelCount() throws {
        let json = #"[{"type":"item","itemType":"action","id":"copy-path"},{"type":"separator"}]"#
        #expect(try appliedStatus(of: json)
            == CustomMenuStatus(applied: .custom(topLevelItems: 2), notice: .none))
    }

    // MARK: - The file relative to what is applied

    @Test func aFileThatWasNeverAppliedIsPendingAndChangesNothing() throws {
        // Generating the file no longer switches the layout, so this is what a
        // first-time user sees: a file, and a menu that has not moved.
        let status = try draftStatus(of: #"[{"type":"separator"}]"#)
        #expect(status == CustomMenuStatus(applied: .defaultLayout, notice: .edited))
    }

    @Test func editingAnAppliedFileIsPendingUntilItIsAppliedAgain() throws {
        let url = try temporaryFile(#"[{"type":"separator"}]"#)
        defer { try? FileManager.default.removeItem(at: url) }
        let applied = try Data(contentsOf: url)

        try Data(#"[{"type":"separator"},{"type":"separator"}]"#.utf8).write(to: url)

        // Editing the file is not enough: the applied bytes still describe one item.
        #expect(MenuService.customMenuStatus(at: url, appliedData: applied, config: catalog)
            == CustomMenuStatus(applied: .custom(topLevelItems: 1), notice: .edited))
        // Once the new bytes are applied, the menu catches up and nothing is pending.
        let reapplied = try Data(contentsOf: url)
        #expect(MenuService.customMenuStatus(at: url, appliedData: reapplied, config: catalog)
            == CustomMenuStatus(applied: .custom(topLevelItems: 2), notice: .none))
    }

    @Test func deletingTheFileReturnsToTheDefaultLayout() throws {
        // The documented escape hatch, and it must survive explicit-apply: a
        // snapshot that outlives its file would strand the user on a layout they
        // cannot get rid of.
        let url = temporaryDirectory().appendingPathComponent("custom_menu.json")
        let applied = Data(#"[{"type":"separator"}]"#.utf8)
        #expect(MenuService.customMenuStatus(at: url, appliedData: applied, config: catalog)
            == CustomMenuStatus(applied: .defaultLayout, notice: .none))
    }

    @Test func malformedFileIsBrokenWithAReason() throws {
        guard case .broken(let reason) = try draftStatus(of: "not JSON").notice else {
            Issue.record("expected .broken")
            return
        }
        #expect(!reason.isEmpty)
    }

    @Test func unreadablePathIsNotReportedAsAMalformedDocument() throws {
        // A folder where a file was expected. The syntax of that file is not the
        // problem, so the user must not be sent to fix its JSON.
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        guard case .broken(let reason) = MenuService.customMenuStatus(
            at: directory, appliedData: nil, config: catalog
        ).notice else {
            Issue.record("expected .broken")
            return
        }
        #expect(reason != AppLocalization.localized("The JSON file is malformed."))
    }

    // MARK: - isProblem

    @Test(arguments: [
        CustomMenuStatus(applied: .unavailable, notice: .none),
        CustomMenuStatus(applied: .defaultLayout, notice: .broken(reason: "boom")),
        CustomMenuStatus(applied: .custom(topLevelItems: 1), notice: .broken(reason: "boom"))
    ])
    func problemStatesAreFlagged(status: CustomMenuStatus) {
        #expect(status.isProblem)
    }

    @Test(arguments: [
        CustomMenuStatus(applied: .defaultLayout, notice: .none),
        CustomMenuStatus(applied: .empty, notice: .none),
        CustomMenuStatus(applied: .custom(topLevelItems: 1), notice: .none),
        // An edit waiting to be applied is the normal working state, not a problem.
        CustomMenuStatus(applied: .custom(topLevelItems: 1), notice: .edited)
    ])
    func normalStatesAreNotFlagged(status: CustomMenuStatus) {
        #expect(!status.isProblem)
    }

    // MARK: - Messages must say what is actually wrong

    @Test func layoutErrorExposesItsReasonThroughLocalizedDescription() {
        // Regression: CustomMenuError conformed only to CustomStringConvertible, so
        // the settings alert rendered the generic system sentence instead of this.
        #expect(CustomMenuError.invalid("boom").localizedDescription == "boom")
    }

    @Test func nestedReferenceErrorsPointAtTheMenuItemPath() throws {
        let json = #"[{"type":"submenu","title":"Outer","children":[{"type":"item","itemType":"app","id":"missing"}]}]"#
        let message = CustomMenuDiagnostics.message(for: try rejection(of: json))
        #expect(message.contains("[1.1]"))
    }

    @Test func decodingErrorsPointAtTheOffendingElement() throws {
        let json = #"[{"type":"item","itemType":"action","id":"copy-path"},{"type":"nope"}]"#
        let message = CustomMenuDiagnostics.message(for: try rejection(of: json))
        #expect(message.contains("[2]"))
    }

    @Test func syntaxErrorsAppendAParserPosition() throws {
        let base = AppLocalization.localized("The JSON file is malformed.")
        let message = CustomMenuDiagnostics.message(for: try rejection(of: "not JSON at all"))
        #expect(message.hasPrefix(base))
        // The line/column readout is appended on top of the generic sentence.
        #expect(message != base)
    }

    // MARK: - Removing the custom layout

    @Test func removingKeepsABackupAndDeletesTheLiveFile() throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let live = directory.appendingPathComponent("custom_menu.json")
        let contents = #"[{"type":"separator"}]"#
        try Data(contents.utf8).write(to: live)

        try MenuService.removeCustomMenu(at: live)

        #expect(!FileManager.default.fileExists(atPath: live.path))
        let backup = directory.appendingPathComponent(MenuService.customMenuBackupName)
        #expect(try Data(contentsOf: backup) == Data(contents.utf8))
    }

    @Test func removingWhenThereIsNoFileIsNotAnError() throws {
        let url = temporaryDirectory().appendingPathComponent("custom_menu.json")
        try MenuService.removeCustomMenu(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - A settings change can invalidate an applied file

    @Test func hidingCommonFoldersTakesDownAConfigThatReferencesThem() throws {
        // "Enable common folders" is not a pure layout switch: MenuService only
        // fills payload.commonDirs when it is on. A custom menu referencing a
        // common dir therefore stops resolving once the switch is turned off, and
        // the whole custom layout falls back - not just the common dir entries.
        //
        // The file itself is untouched, which is why the reason has to be surfaced:
        // otherwise the menu would simply change with nothing to explain it.
        let json = #"[{"type":"item","itemType":"common-dir","id":"desktop"}]"#
        let url = try temporaryFile(json)
        defer { try? FileManager.default.removeItem(at: url) }
        let applied = Data(json.utf8)

        let shown = MenuConfigPayload(commonDirs: [
            CommonDirMenuItem(id: "desktop", name: "Desktop", icon: "folder", url: "/Users/x/Desktop")
        ])
        #expect(MenuService.customMenuStatus(at: url, appliedData: applied, config: shown)
            == CustomMenuStatus(applied: .custom(topLevelItems: 1), notice: .none))

        let hidden = MenuConfigPayload(commonDirs: [])
        let status = MenuService.customMenuStatus(at: url, appliedData: applied, config: hidden)
        #expect(status.applied == .defaultLayout)
        guard case .broken(let reason) = status.notice else {
            Issue.record("expected .broken once common folders are hidden")
            return
        }
        #expect(reason.contains("matched 0 enabled items"))
    }
}
