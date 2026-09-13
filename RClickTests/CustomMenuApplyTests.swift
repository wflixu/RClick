import AppKit
import Testing

@testable import RClick

/// Covers the explicit-apply model: the file on disk is a draft, and only
/// `applyCustomMenu` commits it.
///
/// Every service here is built over a temporary URL. The default URL resolves to
/// the real App Group container, which tests must never touch.
@MainActor
struct CustomMenuApplyTests {
    private var catalog: MenuConfigPayload {
        MenuConfigPayload(
            actions: [ActionMenuItem(id: "copy-path", name: "Copy Path", icon: "doc", tag: 1)],
            commonDirs: [
                CommonDirMenuItem(id: "desktop", name: "Desktop", icon: "folder", url: "/Users/x/Desktop")
            ]
        )
    }

    /// `MenuNode` is deliberately not `Equatable`, so compare counts.
    private func nodeCount(_ nodes: [MenuNode]?) -> Int? {
        nodes?.count
    }

    private func temporaryFile(_ json: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-apply-\(UUID()).json")
        try Data(json.utf8).write(to: url)
        return url
    }

    // MARK: - The core of the change

    @Test func anEditOnDiskStaysInvisibleUntilItIsApplied() throws {
        let url = try temporaryFile(#"[{"type":"separator"}]"#)
        defer { try? FileManager.default.removeItem(at: url) }
        let service = MenuService(customMenuURL: url)

        try service.applyCustomMenu(at: url, config: catalog)
        #expect(nodeCount(service.customMenu(for: catalog)) == 1)

        // The user saves a longer draft. The extension heartbeat fires every ten
        // seconds and rebuilds the config every time; not one of those may pick
        // this up, which is the entire point of the change.
        try Data(#"[{"type":"separator"},{"type":"separator"}]"#.utf8).write(to: url)
        #expect(nodeCount(service.customMenu(for: catalog)) == 1)

        // Only an explicit apply moves the menu.
        try service.applyCustomMenu(at: url, config: catalog)
        #expect(nodeCount(service.customMenu(for: catalog)) == 2)
    }

    @Test func anInvalidEditThrowsAndLeavesTheMenuAlone() throws {
        let url = try temporaryFile(#"[{"type":"separator"}]"#)
        defer { try? FileManager.default.removeItem(at: url) }
        let service = MenuService(customMenuURL: url)
        try service.applyCustomMenu(at: url, config: catalog)

        try Data("not JSON".utf8).write(to: url)

        let thrown = #expect(throws: (any Error).self) {
            try service.applyCustomMenu(at: url, config: catalog)
        }
        #expect(thrown != nil)
        // The live menu must not have collapsed to the default layout.
        #expect(nodeCount(service.customMenu(for: catalog)) == 1)
    }

    @Test func applyingTheSameFileTwiceIsHarmless() throws {
        let url = try temporaryFile(#"[{"type":"separator"}]"#)
        defer { try? FileManager.default.removeItem(at: url) }
        let service = MenuService(customMenuURL: url)

        try service.applyCustomMenu(at: url, config: catalog)
        try service.applyCustomMenu(at: url, config: catalog)

        #expect(nodeCount(service.customMenu(for: catalog)) == 1)
    }

    @Test func aFileThatNoLongerMatchesTheSettingsIsRejectedAtApplyTime() throws {
        // Applying with common folders off must fail loudly rather than commit a
        // layout whose only entry would silently drop out of the menu.
        let url = try temporaryFile(#"[{"type":"item","itemType":"common-dir","id":"desktop"}]"#)
        defer { try? FileManager.default.removeItem(at: url) }
        let service = MenuService(customMenuURL: url)
        try service.applyCustomMenu(at: url, config: catalog)
        #expect(nodeCount(service.customMenu(for: catalog)) == 1)

        let thrown = #expect(throws: (any Error).self) {
            try service.applyCustomMenu(at: url, config: MenuConfigPayload())
        }
        let message = CustomMenuDiagnostics.message(for: try #require(thrown))
        #expect(message.contains("matched 0 enabled items"))
        // The layout that was already in effect survived the rejection.
        #expect(nodeCount(service.customMenu(for: catalog)) == 1)
    }

    // MARK: - Going back to the default layout

    @Test func deletingTheFileClearsTheMenuOnTheNextBuild() throws {
        let url = try temporaryFile(#"[{"type":"separator"}]"#)
        let service = MenuService(customMenuURL: url)
        try service.applyCustomMenu(at: url, config: catalog)
        #expect(nodeCount(service.customMenu(for: catalog)) == 1)

        try FileManager.default.removeItem(at: url)

        // Deleting the file is unambiguous and non-transient, so unlike an edit it
        // does not wait for an apply.
        #expect(nodeCount(service.customMenu(for: catalog)) == nil)
    }

    @Test func discardingForgetsTheLayoutEvenIfTheSameFileComesBack() throws {
        // Restoring the default layout must not be undone by reinstating the file
        // from the backup: that would bring the custom menu back with no Apply.
        let json = #"[{"type":"separator"}]"#
        let url = try temporaryFile(json)
        defer { try? FileManager.default.removeItem(at: url) }
        let service = MenuService(customMenuURL: url)
        try service.applyCustomMenu(at: url, config: catalog)

        service.discardAppliedCustomMenu()
        #expect(nodeCount(service.customMenu(for: catalog)) == nil)

        try Data(json.utf8).write(to: url)
        #expect(nodeCount(service.customMenu(for: catalog)) == nil)
    }

    // MARK: - Degenerate containers

    @Test func noContainerMeansTheDefaultLayout() {
        let service = MenuService(customMenuURL: nil)
        #expect(nodeCount(service.customMenu(for: catalog)) == nil)
    }

    @Test func noContainerMakesApplyingFail() throws {
        let service = MenuService(customMenuURL: nil)

        let thrown = #expect(throws: (any Error).self) {
            try service.applyCustomMenu(config: catalog)
        }
        #expect(thrown is CustomMenuError)
    }

    // MARK: - The empty array keeps its meaning

    @Test func anAppliedEmptyArrayRendersNoItemsRatherThanTheDefaultLayout() throws {
        // `[]` must stay distinguishable from "no file": the extension renders an
        // empty menu for the former and the categorized layout for the latter.
        let url = try temporaryFile("[]")
        defer { try? FileManager.default.removeItem(at: url) }
        let service = MenuService(customMenuURL: url)

        try service.applyCustomMenu(at: url, config: catalog)

        #expect(nodeCount(service.customMenu(for: catalog)) == 0)
    }
}
