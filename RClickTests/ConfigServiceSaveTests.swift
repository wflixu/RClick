import Foundation
import SwiftData
import Testing

@testable import RClick

/// `ConfigService.save` replaces the whole store: it deletes every row of each
/// entity and inserts the in-memory arrays back.
///
/// Every entity carries `@Attribute(.unique)` on its `id`, and the ids survive the
/// round trip (`OpenWithApp(id: entity.id, ...)`), so the second save re-inserts
/// ids the context is still holding as pending deletions. These tests use an
/// in-memory container - the real store in the App Group must not be touched.
@MainActor
struct ConfigServiceSaveTests {
    /// Backed by a real file, not `isStoredInMemoryOnly`: the failure this is
    /// chasing only shows up against actual SQLite, and a temp file is as close to
    /// the App Group store as a test may get.
    private func makeService() throws -> (ConfigService, ModelContext) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-config-\(UUID()).sqlite")
        let configuration = ModelConfiguration(url: url, allowsSave: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: AppEntity.self,
            ActionEntity.self,
            NewFileTypeEntity.self,
            CommonDirEntity.self,
            BookmarkEntity.self,
            DataVersion.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        return (ConfigService(modelContext: context), context)
    }

    private var payload: AppConfigData {
        AppConfigData(
            apps: [OpenWithApp(id: "zed-id", appURL: URL(fileURLWithPath: "/Applications/Zed.app"))],
            actions: [RCAction(id: "copy-path", name: "Copy Path", enabled: true, idx: 0, icon: "doc")],
            newFiles: [NewFile(ext: ".txt", name: "TXT", enabled: true, idx: 0, icon: "doc", id: "txt-id")],
            commonDirs: [CommonDir(id: "desktop", name: "Desktop",
                                   url: URL(fileURLWithPath: "/Users/x/Desktop"), icon: "folder")]
        )
    }

    @Test func theFirstSaveStoresEverything() throws {
        let (service, context) = try makeService()

        try service.save(payload)

        #expect(try context.fetch(FetchDescriptor<AppEntity>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<ActionEntity>()).count == 1)
    }

    @Test func savingAgainWithTheSameIDsDoesNotThrow() throws {
        let (service, _) = try makeService()
        try service.save(payload)

        // This is what every mutation in AppState does to an already-populated store.
        try service.save(payload)
    }

    @Test func savingAfterAddingAnAppKeepsBoth() throws {
        let (service, context) = try makeService()
        try service.save(payload)

        var grown = payload
        grown.apps.append(OpenWithApp(id: "ghostty-id",
                                      appURL: URL(fileURLWithPath: "/Applications/Ghostty.app")))
        try service.save(grown)

        #expect(try context.fetch(FetchDescriptor<AppEntity>()).count == 2)
    }
}
