import AppKit

/// 同一个 bundle id 的多个副本可以同时运行：它们的路径不同（更新后 /Applications
/// 里是新副本，废纸篓、下载目录或挂载的 DMG 里还留着旧副本），LaunchServices
/// 不会把它们当成同一个实例。Finder 扩展的点击走全局 DistributedNotificationCenter，
/// 两个进程都会收到并各执行一次——打开、删除这类操作会被重复执行。
///
/// 沙盒应用**不能终止其他进程**：`NSRunningApplication.terminate()` /
/// `forceTerminate()` 在 App Sandbox 里返回 false（Apple 文档明确说明）。所以收敛
/// 只能由落败者自己完成：每个实例启动时检查一次，之后每 2 秒再查一次，发现自己
/// 不该留下就 `NSApp.terminate`。这一条对之后的所有版本都成立；已经发布的旧版本
/// 没有这段逻辑，只能靠更新流程在安装后重启来避免残留。
@MainActor
enum SingleInstanceGuard {
    struct InstanceInfo: Equatable {
        let version: String
        let launchDate: Date
        let pid: pid_t
    }

    private static var monitorTask: Task<Void, Never>?

    /// 两个实例之间谁留下。
    ///
    /// 版本高者留下；版本相同时后启动的留下——用户刚打开的副本才是他要用的那个
    /// （从 Xcode 跑 Debug 构建也会正确接管，而不是被已经在跑的正式版挤掉）。
    /// 启动时间相同（极罕见）时按 PID 决胜，保证同时启动的两个进程不会互相退出。
    static func shouldKeepSelf(current: InstanceInfo, other: InstanceInfo) -> Bool {
        let versionOrder = Version.compare(current.version, other.version)
        if versionOrder != .orderedSame {
            return versionOrder == .orderedDescending
        }
        if current.launchDate != other.launchDate {
            return current.launchDate > other.launchDate
        }
        return current.pid < other.pid
    }

    /// 启动早期调用。如果已经有更该留下的实例，当前进程直接退出并返回 `false`。
    ///
    /// 必须在注册 DistributedNotificationCenter 处理器之前调用，否则在收敛前
    /// 已经有两个进程同时响应 Finder 扩展的点击了。
    @discardableResult
    static func enforceTermination() -> Bool {
        // 单元测试的宿主进程用的是同一个 bundle id，但它不是用户打开的副本：
        // 让它把自己退掉会让测试跑不起来。
        guard !isRunningTests, let bundleID = Bundle.main.bundleIdentifier else { return true }

        let current = currentInstanceInfo()
        if let winner = peers(bundleID: bundleID, excluding: current.pid)
            .first(where: { !shouldKeepSelf(current: current, other: $0) })
        {
            print("Another RClick instance (pid=\(winner.pid) version=\(winner.version)) should keep running; quitting this one")
            NSApp.terminate(nil)
            return false
        }

        startMonitoring(bundleID: bundleID)
        return true
    }

    /// 另一份副本可能在当前进程启动之后才出现（用户从废纸篓、下载目录或第二份
    /// 安装位置打开它）。每 2 秒复查一次，发现自己该让位就退出。
    private static func startMonitoring(bundleID: String) {
        guard monitorTask == nil else { return }
        monitorTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                let current = currentInstanceInfo()
                let hasWinner = peers(bundleID: bundleID, excluding: current.pid)
                    .contains { !shouldKeepSelf(current: current, other: $0) }
                if hasWinner {
                    print("A newer RClick instance appeared; quitting this one")
                    NSApp.terminate(nil)
                    return
                }
            }
        }
    }

    private static func currentInstanceInfo() -> InstanceInfo {
        InstanceInfo(
            version: version(of: Bundle.main.bundleURL),
            launchDate: NSRunningApplication.current.launchDate ?? .distantPast,
            pid: ProcessInfo.processInfo.processIdentifier
        )
    }

    private static func peers(bundleID: String, excluding pid: pid_t) -> [InstanceInfo] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != pid && !$0.isTerminated }
            .map { application in
                InstanceInfo(
                    version: application.bundleURL.map { version(of: $0) } ?? "0",
                    launchDate: application.launchDate ?? .distantPast,
                    pid: application.processIdentifier
                )
            }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment.keys.contains { $0.hasPrefix("XCTest") }
    }

    private static func version(of bundleURL: URL) -> String {
        Bundle(url: bundleURL)?
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
