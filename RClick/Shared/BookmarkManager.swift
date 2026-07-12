//
//  BookmarkManager.swift
//  RClick
//
//  Created by Claude on 2026/07/12.
//

import Foundation
import SwiftData
import OSLog
import AppKit
import Combine

/// Security-Scoped Bookmark 管理器
///
/// 职责：
/// - 启动时恢复持久化的 bookmark 并 startAccessing
/// - 运行时检查文件路径是否在已授权目录下
/// - 未授权时弹出 NSOpenPanel 引导用户授权
/// - 提供设置页所需的目录管理接口
@MainActor
final class BookmarkManager: ObservableObject {
    /// 当前已授权并激活访问的目录
    @Published var authorizedDirectories: [URL] = []

    private var isPrompting = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "RClick",
        category: "BookmarkManager"
    )

    // MARK: - 恢复

    /// 从 SwiftData 恢复所有 bookmark 并 startAccessing
    func restoreBookmarks(context: ModelContext) {
        let descriptor = FetchDescriptor<BookmarkEntity>()
        guard let entities = try? context.fetch(descriptor) else { return }

        for entity in entities {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: entity.bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    // 刷新 bookmark
                    guard url.startAccessingSecurityScopedResource() else {
                        logger.warning("无法恢复 bookmark（startAccessing 失败）：\(entity.pathString)")
                        continue
                    }
                    let newData = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    entity.bookmarkData = newData
                    url.stopAccessingSecurityScopedResource()
                }

                guard url.startAccessingSecurityScopedResource() else {
                    logger.warning("无法恢复 bookmark（startAccessing 失败）：\(entity.pathString)")
                    continue
                }

                let normalized = url.resolvingSymlinksInPath()
                if !authorizedDirectories.contains(normalized) {
                    authorizedDirectories.append(normalized)
                }
                logger.debug("已恢复 bookmark：\(entity.pathString)")
            } catch {
                logger.error("恢复 bookmark 失败：\(entity.pathString) — \(error.localizedDescription)")
            }
        }
        try? context.save()
        logger.info("Bookmark 恢复完成：\(self.authorizedDirectories.count) 个目录")
    }

    // MARK: - 访问检查

    /// 检查某个文件/目录是否在已授权的目录下
    func hasAccess(to url: URL) -> Bool {
        let target = url.resolvingSymlinksInPath().path
        for dir in authorizedDirectories {
            let dirPath = dir.resolvingSymlinksInPath().path
            // 自身或子路径匹配
            if target == dirPath || target.hasPrefix(dirPath + "/") {
                return true
            }
        }
        return false
    }

    // MARK: - 授权弹窗

    /// 弹出 NSOpenPanel 请求用户授权访问某个目录
    /// - Returns: 用户授权的 URL，用户取消时返回 nil
    func promptForPermission(for url: URL) async -> URL? {
        guard !isPrompting else { return nil }
        isPrompting = true
        defer { isPrompting = false }

        let panel = NSOpenPanel()
        panel.message = AppLocalization.localized("Grant RClick access to this folder to perform file operations.")
        panel.prompt = AppLocalization.localized("Grant Access")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.directoryURL = url

        // 菜单栏应用需要激活才能弹出面板
        NSApp.activate(ignoringOtherApps: true)

        let response = panel.runModal()

        guard response == .OK, let chosenURL = panel.url else {
            return nil
        }

        // 保存 bookmark
        saveBookmark(for: chosenURL)
        return chosenURL
    }

    // MARK: - 持久化

    /// 保存目录的 security-scoped bookmark
    func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            guard url.startAccessingSecurityScopedResource() else {
                logger.error("startAccessing 失败：\(url.path)")
                return
            }

            let normalized = url.resolvingSymlinksInPath()
            if !authorizedDirectories.contains(normalized) {
                authorizedDirectories.append(normalized)
            }

            let entity = BookmarkEntity(bookmarkData: bookmarkData, pathString: url.path)
            let context = ModelContext(SharedDataManager.sharedModelContainer)
            context.insert(entity)
            try context.save()

            logger.debug("已保存 bookmark：\(url.path)")
        } catch {
            logger.error("保存 bookmark 失败：\(url.path) — \(error.localizedDescription)")
        }
    }

    /// 移除某个目录的 bookmark
    func removeDirectory(_ url: URL) {
        let normalized = url.resolvingSymlinksInPath()
        authorizedDirectories.removeAll { $0.resolvingSymlinksInPath() == normalized }

        // 停止访问
        normalized.stopAccessingSecurityScopedResource()

        // 从 SwiftData 删除
        let context = ModelContext(SharedDataManager.sharedModelContainer)
        let path = normalized.path
        let descriptor = FetchDescriptor<BookmarkEntity>(
            predicate: #Predicate { $0.pathString == path }
        )
        if let entities = try? context.fetch(descriptor) {
            for entity in entities {
                context.delete(entity)
            }
            try? context.save()
        }
        logger.debug("已移除 bookmark：\(path)")
    }

    // MARK: - 设置页工具

    /// 从设置页添加目录（弹出 NSOpenPanel）
    func addDirectory() async -> URL? {
        guard !isPrompting else { return nil }
        isPrompting = true
        defer { isPrompting = false }

        let panel = NSOpenPanel()
        panel.message = AppLocalization.localized("Choose a folder for RClick to access.")
        panel.prompt = AppLocalization.localized("Grant Access")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false

        NSApp.activate(ignoringOtherApps: true)

        let response = panel.runModal()

        guard response == .OK, let chosenURL = panel.url else {
            return nil
        }

        saveBookmark(for: chosenURL)
        return chosenURL
    }
}
