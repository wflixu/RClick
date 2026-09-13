//
//  RCRuntime.swift
//  RClick
//
//  进程内 Runtime 依赖容器：持有 AppState 与各 Service，AppDelegate 按需取。
//  注意：这是 Main App 进程内的架构层，不是独立进程 / Helper。
//

import Foundation

@MainActor
final class RCRuntime {
    static let shared = RCRuntime()

    /// 运行时状态（配置内存快照 + 折叠开关 + 权限管理器）
    let state: AppState
    /// 配置持久化
    let configService: ConfigService
    /// 菜单构建
    let menuService: MenuService
    /// 权限（委托 BookmarkManager）
    let permissionService: PermissionService
    /// 动作执行（文件操作）
    let actionService: ActionService
    /// IPC
    let messager: Messager

    private init() {
        self.state = AppState.shared
        self.configService = state.configService
        self.permissionService = PermissionService(bookmarkManager: state.bookmarkManager)
        self.menuService = MenuService(customMenuURL: MenuService.defaultCustomMenuURL)
        self.actionService = ActionService(state: state, permission: permissionService)
        self.messager = Messager.shared
    }
}
