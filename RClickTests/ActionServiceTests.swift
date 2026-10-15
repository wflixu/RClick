//
//  ActionServiceTests.swift
//  RClickTests
//
//  ActionService 单测：用 mock 的 PermissionProviding / ActionStateProviding /
//  DeleteConfirmationProviding 验证授权取消、确认取消与授权→确认顺序。
//

import Foundation
import SwiftData
import Testing
@testable import RClick

@MainActor
final class ActionServiceTests {

    /// Shared ordered log so permission and confirmation mocks can record sequence.
    @MainActor
    private final class CallLog {
        var steps: [String] = []
    }

    @MainActor
    private final class MockPermission: PermissionProviding {
        var hasAccessResult = false
        /// 模拟授权面板已把目录写进 BookmarkManager 的那部分目录
        var authorizedDirs: Set<String> = []
        var promptResult: URL?
        var saveCalls: [URL] = []
        var promptCalls: [URL] = []
        var callLog: CallLog?

        func hasAccess(to url: URL) -> Bool {
            hasAccessResult || authorizedDirs.contains(url.resolvingSymlinksInPath().path)
        }
        func promptForPermission(for url: URL) async -> URL? {
            promptCalls.append(url)
            callLog?.steps.append("permission")
            if let granted = promptResult {          // 对齐 saveBookmark 的副作用
                authorizedDirs.insert(granted.resolvingSymlinksInPath().path)
            }
            return promptResult
        }
        func saveBookmark(for url: URL) { saveCalls.append(url) }
    }

    @MainActor
    private final class MockConfirmation: DeleteConfirmationProviding {
        var result = true
        var confirmCalls: [[String]] = []
        var callLog: CallLog?

        func confirmPermanentDelete(paths: [String]) -> Bool {
            confirmCalls.append(paths)
            callLog?.steps.append("confirmation")
            return result
        }
    }

    @MainActor
    private final class MockState: ActionStateProviding {
        var apps: [OpenWithApp] = []
        var actions: [RCAction] = []
        var newFiles: [NewFile] = []
        var cdirs: [CommonDir] = []
        var showCommonDirs = false
        /// Existing paths leave confirmation off so deleteFoldorFile skips the confirm gate.
        var confirmBeforeDelete = false

        func getAppItem(rid: String) -> OpenWithApp? { nil }
        func getActionItem(rid: String) -> RCAction? { nil }
        func getFileType(rid: String) -> NewFile? { nil }
    }

    private func makeTempFile() throws -> (dir: URL, file: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("dummy.txt")
        try Data("x".utf8).write(to: file)
        return (dir, file)
    }

    @Test func deleteIsSkippedWhenAuthorizationIsCancelled() async throws {
        let (dir, file) = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: dir) }

        let permission = MockPermission()
        permission.hasAccessResult = false
        permission.promptResult = nil
        let confirmation = MockConfirmation()
        let service = ActionService(state: MockState(), permission: permission, confirmation: confirmation)

        await service.deleteFoldorFile([file.path], "ctx-items")

        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(confirmation.confirmCalls.isEmpty)
    }

    @Test func deleteProceedsWhenAuthorizationGranted() async throws {
        let (dir, file) = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: dir) }

        let permission = MockPermission()
        permission.hasAccessResult = false
        permission.promptResult = file.deletingLastPathComponent()
        let confirmation = MockConfirmation()
        let service = ActionService(state: MockState(), permission: permission, confirmation: confirmation)

        await service.deleteFoldorFile([file.path], "ctx-items")

        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(confirmation.confirmCalls.isEmpty)
    }

    @Test func deleteIsSkippedWhenUserCancelsConfirmation() async throws {
        let (dir, file) = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: dir) }

        let permission = MockPermission()
        permission.hasAccessResult = true
        let confirmation = MockConfirmation()
        confirmation.result = false
        let state = MockState()
        state.confirmBeforeDelete = true
        let service = ActionService(state: state, permission: permission, confirmation: confirmation)

        await service.deleteFoldorFile([file.path], "ctx-items")

        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(confirmation.confirmCalls.count == 1)
        #expect(confirmation.confirmCalls[0] == [file.path])
    }

    @Test func deleteProceedsWhenUserConfirms() async throws {
        let (dir, file) = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: dir) }

        let permission = MockPermission()
        permission.hasAccessResult = true
        let confirmation = MockConfirmation()
        confirmation.result = true
        let state = MockState()
        state.confirmBeforeDelete = true
        let service = ActionService(state: state, permission: permission, confirmation: confirmation)

        await service.deleteFoldorFile([file.path], "ctx-items")

        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(confirmation.confirmCalls.count == 1)
    }

    @Test func authorizationIsRequestedBeforeConfirmation() async throws {
        let (dir, file) = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: dir) }

        let log = CallLog()
        let permission = MockPermission()
        permission.hasAccessResult = false
        permission.promptResult = file.deletingLastPathComponent()
        permission.callLog = log
        let confirmation = MockConfirmation()
        confirmation.result = true
        confirmation.callLog = log
        let state = MockState()
        state.confirmBeforeDelete = true
        let service = ActionService(state: state, permission: permission, confirmation: confirmation)

        await service.deleteFoldorFile([file.path], "ctx-items")

        #expect(log.steps == ["permission", "confirmation"])
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(confirmation.confirmCalls.count == 1)
        #expect(confirmation.confirmCalls[0] == [file.path])
    }


    @Test func deleteIsSkippedWhenPromptGrantsUnrelatedDirectory() async throws {
        let (dir, file) = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: dir) }

        let unrelated = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-unrelated-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: unrelated) }

        let permission = MockPermission()
        permission.hasAccessResult = false
        permission.promptResult = unrelated   // 面板返回了无关目录 → 目标目录仍未授权
        let confirmation = MockConfirmation()
        let state = MockState()
        state.confirmBeforeDelete = true
        let service = ActionService(state: state, permission: permission, confirmation: confirmation)

        await service.deleteFoldorFile([file.path], "ctx-items")

        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(confirmation.confirmCalls.isEmpty)
    }

    @Test func confirmationOnlySeesAuthorizedPaths() async throws {
        let (dirA, fileA) = try makeTempFile()
        let (dirB, fileB) = try makeTempFile()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }

        let permission = MockPermission()
        permission.authorizedDirs = [dirA.resolvingSymlinksInPath().path]
        permission.promptResult = nil          // B 的授权被取消 → B 在确认之前出局
        let confirmation = MockConfirmation()  // result 默认 true
        let state = MockState()
        state.confirmBeforeDelete = true
        let service = ActionService(state: state, permission: permission, confirmation: confirmation)

        await service.deleteFoldorFile([fileA.path, fileB.path], "ctx-items")

        #expect(!FileManager.default.fileExists(atPath: fileA.path))
        #expect(FileManager.default.fileExists(atPath: fileB.path))
        #expect(permission.promptCalls.count == 1)          // 非死字段：只为 B 弹了一次
        #expect(confirmation.confirmCalls == [[fileA.path]]) // 确认框只拿到已授权子集
    }

    @Test func appEntityPersistsOpensNewInstance() throws {
        let container = try ModelContainer(
            for: AppEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        var app = OpenWithApp(appURL: URL(fileURLWithPath: "/Applications/Safari.app"))
        app.opensNewInstance = true
        context.insert(AppEntity(from: app, sortOrder: 0))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<AppEntity>())
        #expect(fetched.first?.opensNewInstance == true)
    }

    @Test func fileTemplateSurvivesSaveAndReload() throws {
        let container = try ModelContainer(
            for: AppEntity.self, ActionEntity.self, NewFileTypeEntity.self, CommonDirEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let service = ConfigService(modelContext: container.mainContext)
        var file = NewFile(ext: ".txt", name: "Template", idx: 0, id: "stable-template-id")
        file.template = URL(fileURLWithPath: "/tmp/template with spaces.txt")
        file.openApp = URL(fileURLWithPath: "/Applications/TextEdit.app")
        try service.save(AppConfigData(newFiles: [file]))

        for _ in 0..<2 {
            let loaded = try #require(service.load().newFiles.first)
            #expect(loaded.id == file.id)
            #expect(loaded.template == file.template)
            #expect(loaded.openApp == file.openApp)
            try service.save(AppConfigData(newFiles: [loaded]))
        }
    }

}
