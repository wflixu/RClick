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

    static var customMenuURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.suitName)?
            .appendingPathComponent("custom_menu.json")
    }

    /// Seed only once, using configured IDs so the example works on this installation.
    static func prepareCustomMenu(at url: URL, config: MenuConfigPayload) throws {
        if FileManager.default.fileExists(atPath: url.path) { return }
        var nodes = config.apps.map { MenuNode(type: .item, itemType: .app, id: $0.id) }
        nodes += config.actions.map { MenuNode(type: .item, itemType: .action, id: $0.id) }
        var groups: [MenuNode] = []
        if !config.newFiles.isEmpty {
            groups.append(MenuNode(type: .submenu, title: AppLocalization.localized("New File"),
                                   icon: "doc.badge.plus", children: config.newFiles.map {
                MenuNode(type: .item, itemType: .newFile, id: $0.id)
            }))
        }
        if !config.commonDirs.isEmpty {
            groups.append(MenuNode(type: .submenu, title: AppLocalization.localized("Common Dirs"),
                                   icon: "folder", children: config.commonDirs.map {
                MenuNode(type: .item, itemType: .commonDir, id: $0.id)
            }))
        }
        if !nodes.isEmpty { nodes.append(MenuNode(type: .separator)) }
        nodes.append(MenuNode(type: .submenu, title: AppLocalization.localized("More"),
                              icon: "ellipsis.circle", children: groups))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(nodes)
        do {
            // Exclusive creation also protects edits if another writer wins the race.
            try data.write(to: url, options: .withoutOverwriting)
        } catch CocoaError.fileWriteFileExists {
            return
        }
    }

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

        if let url = Self.customMenuURL {
            do {
                config.customMenu = try CustomMenu.load(
                    from: url, config: config
                )
            } catch {
                Logger(subsystem: "RClick", category: "MenuService").error("Invalid custom_menu.json; using default menu: \(String(describing: error), privacy: .public)")
            }
        }

        return config
    }
}
