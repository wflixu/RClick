//
//  AppPresets.swift
//  RClick
//
//  常用应用预设：预设清单（设置页快速添加用）+ 「简单图标」的 bundleID → SF Symbol 映射。
//  预设清单参考 OpenInTerminal 的支持列表（终端 / 编辑器 / Git 客户端）。
//

import AppKit
import Foundation

/// 图标显示样式（与 OpenInTerminal 的 No/Simple/Original 三档对应）
enum RCAppIconStyle: Int {
    case none = 0
    case simple = 1
    case original = 2
}

/// 一个预设应用：名称键、bundleID（检测安装 + 简单图标映射）、简单图标用的 SF Symbol
struct AppPreset {
    let nameKey: String
    let bundleID: String
    let symbol: String
    /// 终端类应用：选中文件交给它们时，应转换为打开文件所在目录
    /// （与 OpenInTerminal 行为一致；编辑器 / Git 客户端打开文件本身才是预期）
    var isTerminal: Bool = false
}

enum AppPresets {

    /// 预设应用清单（分组无关，按用途排列）
    static let all: [AppPreset] = [
        // 终端
        AppPreset(nameKey: "Terminal", bundleID: "com.apple.Terminal", symbol: "terminal", isTerminal: true),
        AppPreset(nameKey: "iTerm2", bundleID: "com.googlecode.iterm2", symbol: "terminal", isTerminal: true),
        AppPreset(nameKey: "Warp", bundleID: "dev.warp.Warp-Stable", symbol: "terminal", isTerminal: true),
        AppPreset(nameKey: "Ghostty", bundleID: "com.mitchellh.ghostty", symbol: "terminal", isTerminal: true),
        AppPreset(nameKey: "kitty", bundleID: "net.kovidgoyal.kitty", symbol: "terminal", isTerminal: true),
        AppPreset(nameKey: "Alacritty", bundleID: "org.alacritty", symbol: "terminal", isTerminal: true),
        AppPreset(nameKey: "WezTerm", bundleID: "com.github.wez.wezterm", symbol: "terminal", isTerminal: true),
        AppPreset(nameKey: "Tabby", bundleID: "org.tabby", symbol: "terminal", isTerminal: true),
        AppPreset(nameKey: "Hyper", bundleID: "co.zeit.hyper", symbol: "terminal", isTerminal: true),
        // 编辑器
        AppPreset(nameKey: "Visual Studio Code", bundleID: "com.microsoft.VSCode", symbol: "chevron.left.forwardslash.chevron.right"),
        AppPreset(nameKey: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92", symbol: "chevron.left.forwardslash.chevron.right"),
        AppPreset(nameKey: "Xcode", bundleID: "com.apple.dt.Xcode", symbol: "hammer"),
        AppPreset(nameKey: "Sublime Text", bundleID: "com.sublimetext.4", symbol: "text.alignleft"),
        AppPreset(nameKey: "BBEdit", bundleID: "com.barebones.bbedit", symbol: "doc.text"),
        AppPreset(nameKey: "CotEditor", bundleID: "com.coteditor.CotEditor", symbol: "doc.text"),
        AppPreset(nameKey: "Typora", bundleID: "abnerworks.Typora", symbol: "doc.richtext"),
        AppPreset(nameKey: "Nova", bundleID: "com.panic.Nova", symbol: "chevron.left.forwardslash.chevron.right"),
        AppPreset(nameKey: "IntelliJ IDEA", bundleID: "com.jetbrains.intellij", symbol: "pencil.tip"),
        AppPreset(nameKey: "PyCharm", bundleID: "com.jetbrains.pycharm", symbol: "pencil.tip"),
        AppPreset(nameKey: "WebStorm", bundleID: "com.jetbrains.WebStorm", symbol: "pencil.tip"),
        AppPreset(nameKey: "GoLand", bundleID: "com.jetbrains.goland", symbol: "pencil.tip"),
        AppPreset(nameKey: "Android Studio", bundleID: "com.google.android.studio", symbol: "pencil.tip"),
        // Git 客户端
        AppPreset(nameKey: "GitHub Desktop", bundleID: "com.github.GitHubClient", symbol: "arrow.triangle.branch"),
        AppPreset(nameKey: "Fork", bundleID: "com.DanPristupov.Fork", symbol: "arrow.triangle.branch"),
        AppPreset(nameKey: "Tower", bundleID: "com.fournova.Tower3", symbol: "arrow.triangle.branch"),
        AppPreset(nameKey: "SourceTree", bundleID: "com.torusknot.SourceTreeNotMAS", symbol: "arrow.triangle.branch"),
    ]

    /// 预设应用是否已安装；已安装时返回其 .app 路径
    static func installedURL(for preset: AppPreset) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: preset.bundleID)
    }

    /// 终端类预设的 bundleID 集合：打开应用时判断是否做「文件 → 所在目录」转换
    static let terminalBundleIDs: Set<String> = Set(all.filter { $0.isTerminal }.map { $0.bundleID })

    /// bundleID → SF Symbol 名（未收录的应用返回 nil，简单图标模式下回落到原始图标）
    private static let symbolByBundleID: [String: String] = {
        Dictionary(all.map { ($0.bundleID, $0.symbol) }, uniquingKeysWith: { first, _ in first })
    }()

    /// bundleID → 预设显示名（用于把安装的应用对应回预设名）
    private static var nameByBundleID: [String: String] {
        Dictionary(all.map { ($0.bundleID, $0.nameKey) }, uniquingKeysWith: { first, _ in first })
    }

    /// 「简单图标」的 symbol 名缓存：只缓存 bundleID→symbol 查表结果（要打开 Info.plist，
    /// 菜单构建在主线程上，不能每次都读盘）。
    private static let symbolNameCache = LockedSymbolNameCache()

    /// 查表（带缓存）：bundleID 读取要打开 Info.plist，预热与菜单构建共用同一份缓存
    private static func symbolName(forAppPath appPath: String) -> String? {
        if let cached = symbolNameCache.get(appPath) { return cached }
        let bundleID = Bundle(url: URL(fileURLWithPath: appPath))?.bundleIdentifier
        let name = bundleID.flatMap { symbolByBundleID[$0] }
        symbolNameCache.set(appPath, name)
        return name
    }

    static func simpleIcon(forAppPath appPath: String?) -> NSImage? {
        guard let appPath, !appPath.isEmpty else { return nil }
        return simpleIcon(symbolName: symbolName(forAppPath: appPath))
    }

    private static func simpleIcon(symbolName: String?) -> NSImage? {
        guard let symbolName else { return nil }
        return MenuSymbolIcon.image(named: symbolName, pointSize: 16)
    }

    /// Metadata I/O can run in the background; image rendering stays on main.
    static func prewarm(forAppPaths paths: [String]) {
        for path in paths { _ = symbolName(forAppPath: path) }
    }

    /// 「用指定应用打开」的目标解析（主程序 ActionService 与扩展快链路共用）：
    /// 「选中文件时打开所在目录」——每应用显式开关优先，未手动设置时按预设终端分类兜底；
    /// 编辑器 / Git 客户端等保持原样（打开文件本身才是预期）。
    /// 返回 (原始路径（供日志）, 解析后的目标 URL)。
    static func resolveOpenTargets(
        appPath: String?, explicit: Bool?, targetPaths: [String]
    ) -> [(path: String, url: URL)] {
        let bundleID = appPath.flatMap { Bundle(url: URL(fileURLWithPath: $0))?.bundleIdentifier }
        let opensContainingDir = explicit ?? bundleID.map { terminalBundleIDs.contains($0) } ?? false
        return targetPaths.map { raw in
            let decoded = raw.removingPercentEncoding ?? raw
            var url = URL(fileURLWithPath: decoded)
            if opensContainingDir {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
                    url = url.deletingLastPathComponent()
                }
            }
            return (decoded, url)
        }
    }

    /// 应用路径对应的预设显示名（设置页标记「来自预设」时可用，当前仅预留）
    static func presetName(forAppPath appPath: String) -> String? {
        guard let bundleID = Bundle(url: URL(fileURLWithPath: appPath))?.bundleIdentifier else { return nil }
        return nameByBundleID[bundleID]
    }
}

/// NSLock 保护的 String? 缓存（nil 也要缓存：未收录应用不必反复读 Info.plist）
private final class LockedSymbolNameCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String?] = [:]

    func get(_ key: String) -> String?? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func set(_ key: String, _ value: String?) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = .some(value)
    }
}
