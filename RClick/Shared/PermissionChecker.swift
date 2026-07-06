//
//  PermissionChecker.swift
//  RClick
//
//  完全磁盘访问权限多点验证模块
//

import Foundation
import AppKit
@preconcurrency import ApplicationServices
import OSLog
import SwiftUI

// MARK: - Logger

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "RClick",
    category: "PermissionChecker"
)

// MARK: - 权限检查器

/// 提供完全磁盘访问权限的多点验证
public class PermissionChecker {

    /// 需要 FDA 才能访问的检测路径
    /// 每个路径下的文件/子目录只有开启了 FDA 才能被读取
    ///
    /// Deliberately NOT ~/Library/Mail, Messages or Safari: those are other
    /// apps' data containers, and on macOS 15+ merely attempting to read them
    /// fires the TCC "App Data" consent ("RClick" would like to access data
    /// from other apps) every time the app launches. The TCC store below is
    /// gated by Full Disk Access itself (kTCCServiceSystemPolicyAllFiles),
    /// which macOS denies *silently* — an accurate FDA probe with no prompt.
    private static let protectedTestPaths: [(path: String, description: String)] = [
        (NSString(string: "~/Library/Application Support/com.apple.TCC").expandingTildeInPath,
         "User TCC store"),
    ]

    /// 检测是否拥有完全磁盘访问权限
    /// 策略：尝试读取受保护目录下的内容，只要有一个成功即认为 FDA 已开启
    /// - Returns: 如果有完全磁盘访问权限则返回 true
    public static func hasFullDiskAccess() -> Bool {
        for (path, desc) in protectedTestPaths {
            let testURL = URL(fileURLWithPath: path)
            if canAccessDirectory(at: testURL) {
                logger.debug("完全磁盘访问权限检测通过（\(desc)）")
                return true
            }
            logger.warning("FDA 检测：无法访问 \(path)（\(desc)）")
        }
        logger.warning("完全磁盘访问权限未开启")
        return false
    }

    /// 检测是否可以访问指定目录（不跳过隐藏文件，容忍空目录）
    private static func canAccessDirectory(at url: URL) -> Bool {
        // 先确认路径存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.warning("FDA 检测路径不存在：\(url.path)")
            return false
        }

        // No POSIX access() fast path here: the probe directory is owned by
        // the current user, so access(R_OK) succeeds on POSIX permissions
        // alone and would report FDA as granted when it is not. TCC is only
        // enforced on the actual read attempt below.
        do {
            // 不用 .skipsHiddenFiles，避免空目录误判
            let _ = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: []
            )
            return true
        } catch {
            return false
        }
    }

    /// 打开完全磁盘访问权限设置
    @MainActor
    public static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 打开辅助功能权限设置
    @MainActor
    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 检查辅助功能权限
    /// - Returns: 如果有辅助功能权限则返回 true
    public static func hasAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
