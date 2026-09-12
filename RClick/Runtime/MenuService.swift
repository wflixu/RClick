//
//  MenuService.swift
//  RClick
//
//  菜单配置构建服务：从 AppState 生成发往 Finder Extension 的 MenuConfigPayload。
//  版本号在这里维护，用于防重复和防乱序。
//

import Foundation
import OSLog

@MainActor
final class MenuService {
    /// 菜单版本号（防重复 / 防乱序）
    private var menuVersion = 0
    /// 最近一次构建的配置快照（编码后，供诊断/兜底）
    private var lastMenuSnapshot: Data?

    var lastSnapshot: Data? { lastMenuSnapshot }

    /// 从 AppState 实时构建菜单配置
    func buildConfig(from state: AppState) -> MenuConfigPayload {
        let actionMenuItems = state.actions.filter(\.enabled).map { $0.toActionMenuItem() }
        let appMenuItems = state.apps.map { $0.toAppMenuItem() }
        let newFileMenuItems = state.newFiles.filter(\.enabled).map { NewFileMenuItem(id: $0.id, name: $0.name, ext: $0.ext, icon: $0.icon) }
        let commonDirMenuItems = state.showCommonDirs ? state.cdirs.map { CommonDirMenuItem(id: $0.id, name: $0.displayName, icon: $0.icon, url: $0.url.path) } : []

        menuVersion += 1

        var config = MenuConfigPayload(
            version: menuVersion,
            actions: actionMenuItems,
            apps: appMenuItems,
            newFiles: newFileMenuItems,
            commonDirs: commonDirMenuItems,
            actionsCollapsed: state.foldActionsMenu,
            appsCollapsed: state.foldAppsMenu,
            newFilesCollapsed: state.foldNewFileMenu,
            commonDirsCollapsed: state.foldCommonDirMenu
        )

        if let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.suitName) {
            do {
                config.customMenu = try CustomMenu.load(
                    from: directory.appendingPathComponent("custom_menu.json"), config: config
                )
            } catch {
                Logger(subsystem: "RClick", category: "MenuService").error("Invalid custom_menu.json; using default menu: \(String(describing: error), privacy: .public)")
            }
        }

        lastMenuSnapshot = try? JSONEncoder().encode(config)
        return config
    }
}
