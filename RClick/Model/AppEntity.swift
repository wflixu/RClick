//
//  AppEntity.swift
//  RClick
//
//  Created by Claude on 2026/01/16.
//

import SwiftData
import Foundation

/// 应用实体 - 用于存储外部应用程序配置
@Model
final class AppEntity {
    @Attribute(.unique) var id: String
    var urlString: String  // 存储为String，SwiftData对URL支持有限
    var itemName: String
    var inheritFromGlobalArguments: Bool
    var inheritFromGlobalEnvironment: Bool
    var argumentsData: Data?  // 编码后的数组
    var environmentData: Data? // 编码后的字典
    var sortOrder: Int
    var isEnabled: Bool
    /// 注意：必须带默认值，否则 SwiftData 迁移旧库（已有数据）时无法为旧行赋值而失败
    var opensNewInstance: Bool = false
    /// 是否在 Finder 自定义工具栏菜单中显示（带默认值，原因同上）
    var showInToolbar: Bool = true
    /// 是否在右键菜单中显示（带默认值，原因同上）
    var showInContextMenu: Bool = true
    /// 选中文件交给该应用时是否改为打开所在目录（终端类行为）
    /// `nil` 表示未手动设置，运行时按预设终端分类（AppPresets.terminalBundleIDs）兜底
    var opensContainingDir: Bool? = nil
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         url: URL,
         itemName: String = "",
         inheritFromGlobalArguments: Bool = true,
         inheritFromGlobalEnvironment: Bool = true,
         arguments: [String] = [],
         environment: [String: String] = [:],
         sortOrder: Int = 0,
         isEnabled: Bool = true,
         opensNewInstance: Bool = false,
         showInToolbar: Bool = true,
         showInContextMenu: Bool = true,
         opensContainingDir: Bool? = nil) {
        self.id = id
        self.urlString = url.path(percentEncoded: false)
        self.itemName = itemName
        self.inheritFromGlobalArguments = inheritFromGlobalArguments
        self.inheritFromGlobalEnvironment = inheritFromGlobalEnvironment
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.opensNewInstance = opensNewInstance
        self.showInToolbar = showInToolbar
        self.showInContextMenu = showInContextMenu
        self.opensContainingDir = opensContainingDir
        self.createdAt = Date()
        self.updatedAt = Date()

        // 编码复杂数据
        self.argumentsData = try? JSONEncoder().encode(arguments)
        self.environmentData = try? JSONEncoder().encode(environment)
    }

    // 计算属性：从存储的数据解码
    var url: URL {
        get {
            // 处理旧数据中可能存在的百分号编码路径
            let decoded = urlString.removingPercentEncoding ?? urlString
            return URL(fileURLWithPath: decoded)
        }
        set {
            urlString = newValue.path(percentEncoded: false)
        }
    }

    var arguments: [String] {
        guard let data = argumentsData,
              let args = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return args
    }

    var environment: [String: String] {
        guard let data = environmentData,
              let env = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return env
    }

    /// 从 OpenWithApp 转换
    convenience init(from openWithApp: OpenWithApp, sortOrder: Int = 0) {
        self.init(
            id: openWithApp.id,
            url: openWithApp.url,
            itemName: openWithApp.name,
            inheritFromGlobalArguments: openWithApp.inheritFromGlobalArguments,
            inheritFromGlobalEnvironment: openWithApp.inheritFromGlobalEnvironment,
            arguments: openWithApp.arguments,
            environment: openWithApp.environment,
            sortOrder: sortOrder,
            opensNewInstance: openWithApp.opensNewInstance,
            showInToolbar: openWithApp.showInToolbar,
            showInContextMenu: openWithApp.showInContextMenu,
            opensContainingDir: openWithApp.opensContainingDir
        )
    }
}
