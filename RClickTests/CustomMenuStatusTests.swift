import AppKit
import Testing

@testable import RClick

/// Covers what the custom menu file currently *means*, and how failures are
/// explained. Every case passes an explicit URL: under the test host
/// `MenuService.customMenuURL` resolves to the real App Group container, which
/// tests must never touch.
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

    private func status(of json: String) throws -> CustomMenuStatus {
        let url = try temporaryFile(json)
        defer { try? FileManager.default.removeItem(at: url) }
        return MenuService.customMenuStatus(at: url, config: catalog)
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

    // MARK: - The three states must stay distinguishable

    @Test func noFileMeansDefaultLayout() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-absent-\(UUID()).json")
        #expect(MenuService.customMenuStatus(at: url, config: catalog) == .defaultLayout)
    }

    @Test func noContainerMeansUnavailable() {
        // Previously indistinguishable from "no file": both produced a nil payload.
        #expect(MenuService.customMenuStatus(at: nil, config: catalog) == .unavailable)
    }

    @Test func emptyArrayIsEmptyNotInvalid() throws {
        // An empty array is a deliberate request for an empty menu, not a failure.
        #expect(try status(of: "[]") == .empty)
    }

    @Test func validLayoutReportsTopLevelCount() throws {
        let json = #"[{"type":"item","itemType":"action","id":"copy-path"},{"type":"separator"}]"#
        #expect(try status(of: json) == .active(topLevelItems: 2))
    }

    @Test func malformedFileIsInvalidWithAReason() throws {
        guard case .invalid(let reason) = try status(of: "not JSON") else {
            Issue.record("expected .invalid")
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

        guard case .invalid(let reason) = MenuService.customMenuStatus(at: directory, config: catalog) else {
            Issue.record("expected .invalid")
            return
        }
        #expect(reason != AppLocalization.localized("The JSON file is malformed."))
    }

    @Test(arguments: [CustomMenuStatus.unavailable, .invalid(reason: "boom")])
    func problemStatesAreFlagged(status: CustomMenuStatus) {
        #expect(status.isProblem)
    }

    @Test(arguments: [CustomMenuStatus.defaultLayout, .empty, .active(topLevelItems: 1)])
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

    // MARK: - Interaction with the common folders toggle

    @Test func hidingCommonFoldersTakesDownAConfigThatReferencesThem() throws {
        // "Enable common folders" is not a pure layout switch: MenuService only
        // fills payload.commonDirs when it is on. A custom menu referencing a
        // common dir therefore stops resolving once the switch is turned off, and
        // the whole custom layout falls back - not just the common dir entries.
        let json = #"[{"type":"item","itemType":"common-dir","id":"desktop"}]"#
        let url = try temporaryFile(json)
        defer { try? FileManager.default.removeItem(at: url) }

        let shown = MenuConfigPayload(commonDirs: [
            CommonDirMenuItem(id: "desktop", name: "Desktop", icon: "folder", url: "/Users/x/Desktop")
        ])
        #expect(MenuService.customMenuStatus(at: url, config: shown) == .active(topLevelItems: 1))

        let hidden = MenuConfigPayload(commonDirs: [])
        guard case .invalid(let reason) = MenuService.customMenuStatus(at: url, config: hidden) else {
            Issue.record("expected .invalid once common folders are hidden")
            return
        }
        #expect(reason.contains("matched 0 enabled items"))
    }
}
