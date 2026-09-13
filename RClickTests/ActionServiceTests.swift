//
//  ActionServiceTests.swift
//  RClickTests
//
//  ActionService 单测：用 mock 的 PermissionProviding / ActionStateProviding
//  验证"未授权 + 用户取消"时文件操作被跳过。
//

import Foundation
import SwiftData
import Testing
@testable import RClick

@MainActor
final class ActionServiceTests {

    @MainActor
    private final class MockPermission: PermissionProviding {
        var hasAccessResult = false
        var promptResult: URL?
        var saveCalls: [URL] = []

        func hasAccess(to url: URL) -> Bool { hasAccessResult }
        func promptForPermission(for url: URL) async -> URL? { promptResult }
        func saveBookmark(for url: URL) { saveCalls.append(url) }
    }

    @MainActor
    private final class MockState: ActionStateProviding {
        var apps: [OpenWithApp] = []
        var actions: [RCAction] = []
        var newFiles: [NewFile] = []
        var cdirs: [CommonDir] = []
        var showCommonDirs = false

        func getAppItem(rid: String) -> OpenWithApp? { nil }
        func getActionItem(rid: String) -> RCAction? { nil }
        func getFileType(rid: String) -> NewFile? { nil }
    }

    @Test func deleteIsSkippedWhenAuthorizationIsCancelled() async throws {
        // 准备临时文件
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("dummy.txt")
        try Data("x".utf8).write(to: file)

        let permission = MockPermission()
        permission.hasAccessResult = false   // 未授权
        permission.promptResult = nil        // 用户取消授权
        let service = ActionService(state: MockState(), permission: permission)

        await service.deleteFoldorFile([file.path], "ctx-items")

        // 未授权且用户取消 → 文件应保留
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func deleteProceedsWhenAuthorizationGranted() async throws {
        // 准备临时文件
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("dummy.txt")
        try Data("x".utf8).write(to: file)

        let permission = MockPermission()
        permission.hasAccessResult = false   // 未授权，但...
        permission.promptResult = file.deletingLastPathComponent()  // ...用户授权了目录
        let service = ActionService(state: MockState(), permission: permission)

        await service.deleteFoldorFile([file.path], "ctx-items")

        // 授权后应执行删除 → 文件被移除
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func appEntityPersistsOpensNewInstance() throws {
        // in-memory 容器，避免触碰真实 App Group 库
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
