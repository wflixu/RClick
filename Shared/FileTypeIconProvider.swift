//
//  FileTypeIconProvider.swift
//  RClick
//
//  Created by Claude on 2026/06/27.
//

import AppKit
import UniformTypeIdentifiers
import OSLog

/// 文件类型图标提供者 - 优先使用系统 App 图标，失败则回退到 SF Symbol
/// 带内存缓存，避免每次生成菜单都查询 NSWorkspace
final class FileTypeIconProvider: @unchecked Sendable {
    static let shared = FileTypeIconProvider()

    /// 菜单项图标尺寸
    private let iconSize: CGFloat = 18

    /// 内存缓存: [扩展名: NSImage]
    private var cache: [String: NSImage] = [:]

    private init() {}

    // MARK: - Public API

    /// 根据文件扩展名获取图标
    /// - Parameters:
    ///   - ext: 文件扩展名，如 "docx", "txt"
    ///   - fallbackSymbol: SF Symbol 名称，作为二级回退
    /// - Returns: 图标 NSImage
    func icon(for ext: String, fallbackSymbol: String = "doc") -> NSImage? {
        // 1. 内存缓存命中
        if let cached = cache[ext] {
            return cached
        }

        // 2. 系统 App 图标（优先）
        if let icon = workspaceIcon(for: ext) {
            cache[ext] = icon
            return icon
        }

        // 3. 用户 PNG 图标（从主 App Bundle 加载）
        if let png = pngIcon(for: fallbackSymbol) {
            cache[ext] = png
            return png
        }

        // 4. SF Symbol 回退：先解析旧 PNG 图标名，再尝试直接匹配
        let resolvedSymbol = iconFallbackMap[fallbackSymbol] ?? fallbackSymbol
        if let icon = sfSymbolIcon(named: resolvedSymbol) {
            cache[ext] = icon
            return icon
        }

        // 5. 最后兜底
        if let icon = sfSymbolIcon(named: "doc") {
            cache[ext] = icon
            return icon
        }

        return nil
    }

    /// 清除缓存（菜单配置更新时调用）
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private

    private let logger = Logger(subsystem: "RClick.Shared", category: "FileTypeIconProvider")

    /// 旧版 PNG 图标名 → SF Symbol 映射（兼容升级用户数据库中的旧数据）
    private let iconFallbackMap: [String: String] = [
        "icon-file-json": "curlybraces",
        "icon-file-txt": "doc.text",
        "icon-file-md": "doc.richtext",
        "icon-file-docx": "doc.richtext.fill",
        "icon-file-pptx": "rectangle.on.rectangle.fill",
        "icon-file-xlsx": "tablecells",
        "document": "doc",
    ]

    /// 通过 NSWorkspace 获取文件类型对应的默认应用图标
    /// DispatchQueue.main.sync: Extension 不在 @MainActor，需桥接
    private func workspaceIcon(for ext: String) -> NSImage? {
        let icon: NSImage = DispatchQueue.main.sync {
            NSWorkspace.shared.icon(forFileType: ext)
        }
        let genericIcon: NSImage = DispatchQueue.main.sync {
            NSWorkspace.shared.icon(forFileType: "")
        }

        if icon === genericIcon {
            logger.debug("workspaceIcon '\(ext)': no specific app (generic icon)")
            return nil
        }

        logger.debug("workspaceIcon '\(ext)': got app icon")
        return icon.resized(to: NSSize(width: iconSize, height: iconSize))
    }

    /// 从主 App Bundle 加载 PNG 图标（用户自定义图标）
    private func pngIcon(for name: String) -> NSImage? {
        guard let appBundle = Bundle(identifier: "cn.wflixu.RClick"),
              let image = appBundle.image(forResource: name) else {
            return nil
        }
        return image.resized(to: NSSize(width: iconSize, height: iconSize))
    }

    /// SF Symbol 图标（含暗色模式适配）
    private func sfSymbolIcon(named name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(hierarchicalColor: .labelColor)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
}

// MARK: - NSImage Resize Helper

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let img = NSImage(size: newSize)
        img.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize),
             from: .zero,
             operation: .copy,
             fraction: 1)
        img.unlockFocus()
        return img
    }
}
