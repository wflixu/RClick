//
//  ModelContainer.swift
//  RClick
//
//  Created by 李旭 on 2025/10/3.
//

import Foundation
import SwiftData

// 共享 ModelContainer 配置工具类
class SharedDataManager {
    static let appGroupIdentifier = Constants.suitName

    static var sharedModelContainer: ModelContainer = {
        do {
            // 获取 App Group 共享目录
            let storeURL: URL

            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
                fatalError("无法获取 App Group 共享目录。请检查 App Group 配置: \(appGroupIdentifier)")
            }
            storeURL = containerURL.appendingPathComponent("RClickDatabase.sqlite")

            // 创建 ModelConfiguration 使用共享路径
            let configuration = ModelConfiguration(
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )

            // 创建 ModelContainer
            let container = try ModelContainer(
                for: PermDir.self, // 你的模型类型
                configurations: configuration
            )

            return container
        } catch {
            fatalError("Failed to create shared model container: \(error)")
        }
    }()
}
