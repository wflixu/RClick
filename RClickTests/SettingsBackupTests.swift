import Foundation
import Testing

@testable import RClick

@MainActor
struct SettingsBackupTests {
    @Test func backupRoundTripsThroughJSON() throws {
        let appPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-app-\(UUID().uuidString).app")
        FileManager.default.createFile(atPath: appPath.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: appPath) }

        let backup = SettingsBackup(
            schemaVersion: SettingsBackup.currentSchemaVersion,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            apps: [SettingsBackup.App(
                id: "app",
                path: appPath.path,
                itemName: "Test",
                inheritFromGlobalArguments: false,
                inheritFromGlobalEnvironment: true,
                arguments: ["-a"],
                environment: ["K": "V"],
                opensNewInstance: true,
                showInToolbar: false,
                showInContextMenu: true,
                opensContainingDir: true
            )],
            actions: [SettingsBackup.Action(id: "copy-path", enabled: false, idx: 0)],
            newFiles: [SettingsBackup.FileTemplate(
                id: "txt", ext: ".txt", name: "TXT", enabled: true, idx: 0,
                icon: "doc.text", openAppPath: nil, templatePath: nil
            )],
            commonDirs: [SettingsBackup.CommonFolder(
                id: "home", name: "Home", path: "/Users/test", icon: "folder"
            )],
            preferences: SettingsBackup.Preferences(
                foldAppsMenu: true,
                foldActionsMenu: false,
                foldNewFileMenu: true,
                foldCommonDirMenu: false,
                showCommonDirs: true,
                appIconStyle: 2,
                showMenuBarExtra: false,
                launchAtLogin: true
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SettingsBackup.self, from: data)

        #expect(decoded.schemaVersion == SettingsBackup.currentSchemaVersion)
        #expect(decoded.apps.first?.path == appPath.path)
        #expect(decoded.apps.first?.arguments == ["-a"])
        #expect(decoded.actions.first?.enabled == false)
        #expect(decoded.preferences.appIconStyle == 2)
        #expect(decoded.preferences.launchAtLogin == true)
    }

    @Test func appThatIsNotInstalledIsSkipped() {
        let entry = SettingsBackup.App(
            id: "gone",
            path: "/tmp/rclick-missing-\(UUID().uuidString).app",
            itemName: "Gone",
            inheritFromGlobalArguments: true,
            inheritFromGlobalEnvironment: true,
            arguments: [],
            environment: [:],
            opensNewInstance: false,
            showInToolbar: true,
            showInContextMenu: true,
            opensContainingDir: nil
        )

        #expect(entry.toModel() == nil)
    }

    @Test func missingTemplateFallsBackToTheBuiltInTemplate() {
        let entry = SettingsBackup.FileTemplate(
            id: "custom",
            ext: ".docx",
            name: "Custom",
            enabled: true,
            idx: 0,
            icon: "doc.richtext",
            openAppPath: "/tmp/rclick-missing-\(UUID().uuidString).app",
            templatePath: "/tmp/rclick-missing-\(UUID().uuidString).docx"
        )

        let file = entry.toModel()
        #expect(file.template == nil)
        #expect(file.openApp == nil)
    }

    @Test func resolveActionsKeepsBackupOrderAndAddsNewBuiltIns() {
        let actions = SettingsBackup.resolveActions([
            SettingsBackup.Action(id: "delete-direct", enabled: false, idx: 0),
            SettingsBackup.Action(id: "copy-path", enabled: true, idx: 1),
            SettingsBackup.Action(id: "unknown-action", enabled: true, idx: 2),
        ])

        #expect(actions.first?.id == "delete-direct")
        #expect(actions.first?.enabled == false)
        #expect(Set(actions.map(\.id)) == Set(RCAction.all.map(\.id)))
        #expect(actions.map(\.idx) == Array(0..<actions.count))
    }
}
