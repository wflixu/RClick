//
//  PermissionChecker.swift
//  RClick
//
//  完全磁盘访问权限多点验证模块
//

import Foundation
import AppKit
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

    /// 测试路径列表（多个检测点）
    private static let testPaths = [
        "/Library/Application Support",  // 系统级受保护目录
        "/Library/Logs",                  // 系统日志目录
        "/Applications",                  // 应用程序目录
        NSString(string: "~/Library/Application Support").expandingTildeInPath  // 用户级受保护目录
    ]

    /// 检测是否拥有完全磁盘访问权限（多点验证）
    /// - Returns: 如果有完全磁盘访问权限则返回 true
    public static func hasFullDiskAccess() -> Bool {
        // 遍历所有测试路径，任何一个无法访问则返回 false
        for path in testPaths {
            let testURL = URL(fileURLWithPath: path)

            // 尝试访问目录
            guard canAccessDirectory(at: testURL) else {
                logger.warning("无法访问：\(path)")
                return false
            }
        }

        logger.info("完全磁盘访问权限检测通过")
        return true
    }

    /// 检测是否可以访问指定目录
    /// - Parameter url: 目录 URL
    /// - Returns: 是否可以访问
    private static func canAccessDirectory(at url: URL) -> Bool {
        do {
            // 尝试读取目录内容
            let _ = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return true
        } catch {
            logger.debug("目录访问失败：\(url.path) - \(error.localizedDescription)")
            return false
        }
    }

    /// 实际文件操作测试（更严格的权限检测）
    /// - Returns: 如果文件操作成功则返回 true
    public static func performFileOperationTest() -> Bool {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("rclick_permission_test_\(UUID().uuidString)")

        do {
            // 测试写入
            try "test".write(to: testFile, atomically: true, encoding: .utf8)

            // 测试读取
            let _ = try String(contentsOf: testFile, encoding: .utf8)

            // 测试删除
            try FileManager.default.removeItem(at: testFile)

            logger.info("文件操作测试通过")
            return true
        } catch {
            logger.warning("文件操作测试失败：\(error.localizedDescription)")
            return false
        }
    }

    /// 打开完全磁盘访问权限设置
    public static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 打开辅助功能权限设置
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
