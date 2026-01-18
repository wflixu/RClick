//
//  PermissiveDirEntity.swift
//  RClick
//
//  Created by Claude on 2026/01/16.
//

import SwiftData
import Foundation
import OSLog

/// Logger for PermissiveDirEntity operations
private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "RClick",
    category: "PermissiveDirEntity"
)

/// PermissiveDir related errors
enum PermissiveDirError: Error {
    case failedToAccessSecurityScopedResource
}

/// 许可目录实体 - 用于存储需要安全作用域访问权限的目录
@Model
final class PermissiveDirEntity {
    @Attribute(.unique) var id: String
    var urlString: String  // 存储为String，SwiftData对URL支持有限
    var bookmark: Data
    var isEnabled: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         url: URL,
         bookmark: Data,
         isEnabled: Bool = true,
         sortOrder: Int = 0) {
        self.id = id
        self.urlString = url.path()
        self.bookmark = bookmark
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 计算属性：获取URL
    var url: URL {
        get {
            URL(fileURLWithPath: urlString)
        }
        set {
            urlString = newValue.path()
        }
    }

    /// 尝试解析并访问安全作用域资源
    /// - Returns: 是否成功访问资源
    func accessSecurityScopedResource() -> Bool {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                logger.warning("Bookmark is stale for \(self.urlString)")
                return false
            }

            let result = url.startAccessingSecurityScopedResource()
            if result {
                logger.info("Successfully accessed security scoped resource: \(self.urlString)")
            } else {
                logger.error("Failed to access security scoped resource: \(self.urlString)")
            }

            return result
        } catch {
            logger.error("Error resolving bookmark: \(error.localizedDescription)")
            return false
        }
    }

    /// 停止访问安全作用域资源
    func stopAccessingSecurityScopedResource() {
        let url = URL(fileURLWithPath: self.urlString)
        url.stopAccessingSecurityScopedResource()
        logger.debug("Stopped accessing security scoped resource: \(self.urlString)")
    }

    /// 从 PermissiveDir 结构体转换
    convenience init(from permissiveDir: PermissiveDir) {
        self.init(
            id: permissiveDir.id,
            url: permissiveDir.url,
            bookmark: permissiveDir.bookmark,
            sortOrder: 0
        )
    }

    /// 创建安全作用域bookmark
    static func create(from url: URL) throws -> PermissiveDirEntity {
        // 尝试访问安全作用域
        let result = url.startAccessingSecurityScopedResource()
        guard result else {
            logger.error("Failed to access security scoped resource during creation")
            throw PermissiveDirError.failedToAccessSecurityScopedResource
        }

        // 创建bookmark
        let bookmark = try url.bookmarkData(options: .withSecurityScope)

        // 释放资源
        url.stopAccessingSecurityScopedResource()

        return PermissiveDirEntity(
            url: url,
            bookmark: bookmark
        )
    }
}

// MARK: - 预定义目录
extension PermissiveDirEntity {
    /// 用户主目录
    static var home: PermissiveDirEntity? {
        guard let pw = getpwuid(getuid()),
              let home = pw.pointee.pw_dir
        else {
            return nil
        }
        let path = FileManager.default.string(withFileSystemRepresentation: home, length: strlen(home))
        let url = URL(fileURLWithPath: path)

        do {
            return try create(from: url)
        } catch {
            logger.error("Failed to create home directory PermissiveDirEntity: \(error)")
            return nil
        }
    }

    /// 应用程序目录
    static var applications: PermissiveDirEntity? {
        let url = URL(fileURLWithPath: "/Applications")

        do {
            return try create(from: url)
        } catch {
            logger.error("Failed to create applications PermissiveDirEntity: \(error)")
            return nil
        }
    }

    /// 所有卷
    static var volumes: [PermissiveDirEntity] {
        let volumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [],
            options: [.skipHiddenVolumes]
        ) ?? []

        return volumeURLs.compactMap { url in
            try? create(from: url)
        }
    }

    /// 默认目录集合
    static var defaultDirectories: [PermissiveDirEntity] {
        var dirs: [PermissiveDirEntity] = []

        if let home = home {
            dirs.append(home)
        }

        if let applications = applications {
            dirs.append(applications)
        }

        dirs.append(contentsOf: volumes)

        return dirs
    }
}

// MARK: - 批量操作扩展
extension PermissiveDirEntity {
    /// 批量创建 PermissiveDirEntity
    static func create(from urls: [URL]) throws -> [PermissiveDirEntity] {
        return try urls.map { url in
            try create(from: url)
        }
    }

    /// 批量访问安全作用域资源
    /// - Parameter entities: 要访问的实体数组
    /// - Returns: 成功访问的实体数量
    @discardableResult
    static func batchAccessSecurityScopedResources(for entities: [PermissiveDirEntity]) -> Int {
        var successCount = 0

        for entity in entities {
            if entity.accessSecurityScopedResource() {
                successCount += 1
            }
        }

        logger.info("Batch access: \(successCount)/\(entities.count) succeeded")
        return successCount
    }

    /// 批量停止访问安全作用域资源
    static func batchStopAccessingSecurityScopedResources(for entities: [PermissiveDirEntity]) {
        for entity in entities {
            entity.stopAccessingSecurityScopedResource()
        }
        logger.debug("Batch stop accessing security scoped resources for \(entities.count) entities")
    }
}
