import Foundation
import Testing

@testable import RClick

/// Covers the one-time move of the layout toggles out of the app's own defaults and
/// into the shared group.
///
/// Both stores are throwaway suites. The real ones - and the real App Group - must
/// never be touched by a test.
@MainActor
struct AppStateDefaultsMigrationTests {
    private struct ScratchStore {
        let name: String
        let defaults: UserDefaults

        static func make() throws -> ScratchStore {
            let name = "rclick-migration-\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: name))
            return ScratchStore(name: name, defaults: defaults)
        }

        func cleanUp() {
            defaults.removePersistentDomain(forName: name)
        }
    }

    private func withStores(_ body: (UserDefaults, UserDefaults) throws -> Void) throws {
        let old = try ScratchStore.make()
        let new = try ScratchStore.make()
        defer {
            old.cleanUp()
            new.cleanUp()
        }
        try body(old.defaults, new.defaults)
    }

    @Test func existingValuesSurviveTheMove() throws {
        try withStores { old, new in
            // The value that matters: leaving it behind would turn common folders
            // off, which takes any custom menu referencing one down with it.
            old.set(true, forKey: "showCommonDirs")
            old.set(false, forKey: "foldAppsMenu")

            AppState.migrateLayoutToggles(from: old, to: new)

            #expect(new.bool(forKey: "showCommonDirs"))
            #expect(new.object(forKey: "foldAppsMenu") as? Bool == false)
        }
    }

    @Test func theOldCopyIsRemovedSoThereIsOnlyOneSourceOfTruth() throws {
        try withStores { old, new in
            old.set(true, forKey: "showCommonDirs")

            AppState.migrateLayoutToggles(from: old, to: new)

            #expect(old.object(forKey: "showCommonDirs") == nil)
        }
    }

    @Test func aValueAlreadyInTheNewStoreWins() throws {
        try withStores { old, new in
            old.set(true, forKey: "showCommonDirs")
            new.set(false, forKey: "showCommonDirs")

            AppState.migrateLayoutToggles(from: old, to: new)

            #expect(new.object(forKey: "showCommonDirs") as? Bool == false)
        }
    }

    @Test func untouchedSwitchesStayAbsent() throws {
        try withStores { old, new in
            // Nothing stored anywhere. The migration must not materialise a value,
            // or every switch would be pinned to `false` instead of falling back to
            // its declared default - `foldNewFileMenu` and `foldCommonDirMenu`
            // default to true.
            AppState.migrateLayoutToggles(from: old, to: new)

            for key in AppState.layoutToggleKeys {
                #expect(new.object(forKey: key) == nil, "\(key) should not have been written")
            }
        }
    }

    @Test func runningItAgainIsHarmless() throws {
        try withStores { old, new in
            old.set(true, forKey: "showCommonDirs")
            AppState.migrateLayoutToggles(from: old, to: new)

            // Second launch: the old store is empty and the new one already has the
            // value, so nothing moves and nothing is lost.
            AppState.migrateLayoutToggles(from: old, to: new)

            #expect(new.bool(forKey: "showCommonDirs"))
        }
    }

    @Test func everyDeclaredToggleKeyIsCovered() {
        // A new layout switch added without joining this list would silently keep
        // whatever the old store held.
        #expect(AppState.layoutToggleKeys.contains("showCommonDirs"))
        #expect(AppState.layoutToggleKeys.contains("foldCommonDirMenu"))
        #expect(AppState.layoutToggleKeys.count == 5)
    }
}
