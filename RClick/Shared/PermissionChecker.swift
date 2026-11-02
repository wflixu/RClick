//
//  PermissionChecker.swift
//  RClick
//
//  辅助功能权限检查模块
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

/// 提供辅助功能权限的检测
public class PermissionChecker {

    /// 打开辅助功能权限设置
    @MainActor
    public static func openAccessibilitySettings() {
        // 主动发起一次权限请求：系统弹出授权对话框，并把 RClick 加进
        // "隐私与安全性 → 辅助功能"列表。该列表只显示请求过的应用，而
        // 状态检查用的是 prompt:false，从不发起请求，新装的 RClick 不会
        // 出现在列表里。已授权时这一步静默通过，不会重复弹窗。
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(promptOptions)

        // 同时打开系统设置的辅助功能面板，方便直接开关
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"),
           NSWorkspace.shared.open(url) {
            return
        }
        // 兜底：至少把系统设置主窗口打开
        if let settingsUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systemsettings") {
            NSWorkspace.shared.open(settingsUrl)
        }
    }

    /// 检查辅助功能权限
    /// - Returns: 如果有辅助功能权限则返回 true
    public static func hasAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

// MARK: - 系统设置的叫法随大版本差异

/// macOS 大版本之间系统设置里的面板/条目名称有变动，权限页的引导文案
/// 按当前系统取对应叫法，避免用户拿着旧名字在新系统里找不到入口。
/// 考证依据：本机 27.0.1 的系统设置资源（SecurityPrivacyExtension、
/// LoginItems 的 Localizable.loctable）+ Apple 官方 15/26/27 版《Mac 使用手册》：
/// 隐私面板 27 起叫「隐私与安全」，辅助功能条目 27 起叫「设备控制和数据访问」，
/// Finder 扩展条目 15/26 叫「访达」、27 起叫「扩展」。
public enum SystemSettingsNaming {
    private static var majorVersion: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }

    /// 「隐私与安全性」面板名：27 起更名为「隐私与安全」
    public static var privacySecuritySection: String {
        majorVersion >= 27
            ? AppLocalization.localized("Privacy & Security (macOS 27)")
            : AppLocalization.localized("Privacy & Security")
    }

    /// 「隐私与安全性」里的辅助功能条目名：27 起叫「设备控制和数据访问」，
    /// 26 及以前叫「辅助功能」
    public static var accessibilitySection: String {
        majorVersion >= 27
            ? AppLocalization.localized("Device Control & Data Access")
            : AppLocalization.localized("Accessibility")
    }

    /// 「登录项与扩展」里的 Finder 扩展条目名：27 起叫「扩展」，
    /// 15/26 官方文档均显示为「访达」（英文 Finder）
    public static var finderExtensionRow: String {
        majorVersion >= 27
            ? AppLocalization.localized("Extensions")
            : AppLocalization.localized("Finder")
    }
}
