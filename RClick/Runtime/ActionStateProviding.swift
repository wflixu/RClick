//
//  ActionStateProviding.swift
//  RClick
//
//  ActionService 读取配置状态所需的最小接口。
//  AppState 遵守该协议；测试时可注入 mock。
//

import Foundation

/// ActionService 读取状态所需接口
@MainActor
protocol ActionStateProviding: AnyObject {
    func getAppItem(rid: String) -> OpenWithApp?
    func getActionItem(rid: String) -> RCAction?
    func getFileType(rid: String) -> NewFile?
    var apps: [OpenWithApp] { get }
    var actions: [RCAction] { get }
    var newFiles: [NewFile] { get }
    var cdirs: [CommonDir] { get }
    var showCommonDirs: Bool { get }
}
