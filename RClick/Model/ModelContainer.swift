//
//  ModelContainer.swift
//  RClick
//
//  Created by 李旭 on 2025/10/3.
//

import Foundation
import SwiftData
import OSLog

/// 共享库打不开的原因。
///
/// 拆成两个 case 而不是笼统一个"失败"，因为两者的排查路径完全不同：
/// 前者查 App Group 配置，后者多半是构建签名问题。
enum SharedStoreError: LocalizedError {
    /// 拿不到 App Group 容器目录：App Group 没配好，或 entitlement 没生效。
    case appGroupUnavailable(identifier: String)
    /// 目录拿到了，但库文件打不开。
    case storeUnreadable(url: URL, underlying: Error)

    /// 诊断用，不是给用户看的文案 —— 用户看到的那份由 `StartupFailure.describe()`
    /// 组装并走本地化。这里保持英文，避免一条没进 catalog 的中文串从某处
    /// `localizedDescription` 漏到界面上。
    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable(let identifier):
            return "Cannot resolve the App Group container: \(identifier)"
        case .storeUnreadable(let url, let underlying):
            return "Cannot open the store at \(url.path): \(underlying)"
        }
    }

    /// 错误链里是否出现 SQLite 的授权被拒（SQLITE_AUTH = 23）。
    ///
    /// 这是"库文件在、当前进程却不许读"的特征。已知的唯一成因是构建产物没有有效签名：
    /// `com.apple.security.application-groups` 没有被 provisioning profile 背书，
    /// 沙盒因此不把容器目录写进本进程的 profile，打开库时即被拒。
    ///
    /// 之所以靠字符串而不是 `NSError.userInfo`：SwiftData 把 Cocoa 错误裹在
    /// `SwiftDataError` 里，`NSSQLiteErrorDomain` 只出现在它的描述中，沿错误链取不到。
    var looksLikeAuthorizationDenial: Bool {
        guard case .storeUnreadable(_, let underlying) = self else { return false }
        return "\(underlying)".contains("NSSQLiteErrorDomain=23")
    }
}

// 共享 ModelContainer 配置工具类
@MainActor
class SharedDataManager {
    static let appGroupIdentifier = Constants.suitName

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "RClick",
        category: "ModelContainer"
    )

    /// `bootstrap()` 打开的那个容器。
    private static var openedContainer: ModelContainer?

    /// 已打开的共享容器。
    ///
    /// 正常路径由启动代码先跑 `bootstrap()`。若仍有更早的访问者（SwiftUI 求值顺序不是
    /// 我们能保证的），这里补一次并走同一个失败出口 —— 总之不再有 trap。
    static var sharedModelContainer: ModelContainer {
        if let openedContainer { return openedContainer }

        do {
            let container = try makeSharedModelContainer()
            openedContainer = container
            return container
        } catch {
            StartupFailure.presentAndExit(error)
        }
    }

    /// 打开共享容器，失败则抛出。
    ///
    /// 启动路径应当在任何东西碰 `sharedModelContainer` 之前调用它。原先是静态 lazy
    /// 初始化 + `fatalError`，于是"读不到库"表现为毫无提示的 SIGTRAP —— 崩溃报告里
    /// 只有 `_assertionFailure`，真正的原因（哪个文件、为什么打不开）随进程一起没了。
    /// 改成显式抛出后，调用方能把原因说清楚再退。
    static func bootstrap() throws {
        guard openedContainer == nil else { return }
        openedContainer = try makeSharedModelContainer()
    }

    /// 定位容器目录并打开 ModelContainer。不做任何 trap，失败一律抛给调用方。
    static func makeSharedModelContainer() throws -> ModelContainer {
        // 获取 App Group 共享目录
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw SharedStoreError.appGroupUnavailable(identifier: appGroupIdentifier)
        }
        let storeURL = containerURL.appendingPathComponent("RClickDatabase.sqlite")

        // 创建 ModelConfiguration 使用共享路径
        let configuration = ModelConfiguration(
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        // 创建 ModelContainer，注册所有模型
        do {
            return try ModelContainer(
                for: AppEntity.self,
                     ActionEntity.self,
                     NewFileTypeEntity.self,
                     CommonDirEntity.self,
                     BookmarkEntity.self,
                     DataVersion.self,
                configurations: configuration
            )
        } catch {
            logger.error("打开共享 ModelContainer 失败: \(error)")
            throw SharedStoreError.storeUnreadable(url: storeURL, underlying: error)
        }
    }

    /// 初始化默认数据
    static func initializeDefaultData(context: ModelContext) async {
        // 检查是否已有数据
        let actionDescriptor = FetchDescriptor<ActionEntity>()
        let actionCount = try? context.fetchCount(actionDescriptor)

        if actionCount == 0 {
            // 插入默认动作
            for action in ActionEntity.createDefaultActions() {
                context.insert(action)
            }
            Self.logger.info("已初始化默认动作")
        }

        let fileTypeDescriptor = FetchDescriptor<NewFileTypeEntity>()
        let fileTypeCount = try? context.fetchCount(fileTypeDescriptor)

        if fileTypeCount == 0 {
            // 插入默认文件类型
            for fileType in NewFileTypeEntity.createDefaultFileTypes() {
                context.insert(fileType)
            }
            Self.logger.info("已初始化默认文件类型")
        }

        let appDescriptor = FetchDescriptor<AppEntity>()
        let appCount = try? context.fetchCount(appDescriptor)

        if appCount == 0 {
            for app in OpenWithApp.defaultApps {
                context.insert(AppEntity(from: app))
            }
            Self.logger.info("已初始化默认应用")
        }

        let commonDirDescriptor = FetchDescriptor<CommonDirEntity>()
        let commonDirCount = try? context.fetchCount(commonDirDescriptor)

        if commonDirCount == 0 {
            // 插入默认常用目录
            for dir in CommonDirEntity.createDefaultCommonDirs() {
                context.insert(dir)
            }
            Self.logger.info("已初始化默认常用目录")
        }

        try? context.save()
    }
}
