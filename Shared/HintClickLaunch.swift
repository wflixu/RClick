import Foundation

/// 「离线提示点击启动」标记，经 App Group 容器在扩展与主程序之间传递。
///
/// 扩展在拉起主程序前触碰标记文件；主程序据此识别这次启动/reopen 来自提示点击，
/// 保持静默（不打开设置窗口）。标记文件直接位于双方获授权的 App Group 容器内，
/// 不依赖 UserDefaults 的跨进程刷新；只读写文件修改时间，无需解析内容。
enum HintClickLaunch {
    /// 覆盖「退出收尾约 1 秒、启动后菜单刷新前 1-2 秒」空窗的判定窗口
    static let window: TimeInterval = 5

    private static var fileURL: URL? {
        // 与主程序数据库共用同一个 App Group 标识。
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedAppGroup.identifier)?
            .appendingPathComponent("hintClickLaunchAt")
    }

    /// 扩展侧：拉起主程序前调用
    static func mark() {
        guard let url = fileURL else { return }
        FileManager.default.createFile(atPath: url.path, contents: nil)
    }

    /// 主程序侧：是否处于提示点击后的静默窗口
    static func isRecent(now: Date = Date()) -> Bool {
        guard let url = fileURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modifiedAt = attributes[.modificationDate] as? Date
        else { return false }
        return now.timeIntervalSince(modifiedAt) < window
    }
}


/// Shared by both targets so launch markers and the host settings use one ID.
nonisolated enum SharedAppGroup {
    static let identifier = "group.cn.wflixu.RClick"
}
