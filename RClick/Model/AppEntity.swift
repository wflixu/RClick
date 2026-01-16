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
         isEnabled: Bool = true) {
        self.id = id
        self.urlString = url.path()
        self.itemName = itemName
        self.inheritFromGlobalArguments = inheritFromGlobalArguments
        self.inheritFromGlobalEnvironment = inheritFromGlobalEnvironment
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.updatedAt = Date()

        // 编码复杂数据
        self.argumentsData = try? JSONEncoder().encode(arguments)
        self.environmentData = try? JSONEncoder().encode(environment)
    }

    // 计算属性：从存储的数据解码
    var url: URL {
        get {
            URL(fileURLWithPath: urlString)
        }
        set {
            urlString = newValue.path()
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
            sortOrder: sortOrder
        )
    }
}
