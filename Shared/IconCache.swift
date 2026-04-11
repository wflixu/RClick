//
//  IconCache.swift
//  RClick
//
//  统一的图标缓存管理器
//

import AppKit
import Foundation

/// 统一的图标缓存管理器
/// 为 Main App 和 Extension 提供共享的图标缓存服务
@MainActor
public class IconCache {
    public static let shared = IconCache()

    private var memoryCache: [String: NSImage] = [:]
    private let iconSize = CGSize(width: 32, height: 32)

    private init() {}

    /// 获取文件图标
    /// - Parameter url: 文件 URL
    /// - Returns: 缩放后的图标图片
    public func icon(for url: URL) -> NSImage {
        let cacheKey = url.path
        if let cached = memoryCache[cacheKey] {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = iconSize
        memoryCache[cacheKey] = icon
        return icon
    }

    /// 预加载图标
    /// - Parameter urls: 需要预加载的 URL 列表
    public func preloadIcons(for urls: [URL]) {
        for url in urls {
            _ = icon(for: url)
        }
    }

    /// 清除缓存
    public func clearCache() {
        memoryCache.removeAll()
    }

    /// 缓存中的图标数量
    public var cacheSize: Int {
        memoryCache.count
    }
}
