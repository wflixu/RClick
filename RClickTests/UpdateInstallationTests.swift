import Foundation
import Testing

@testable import RClick

/// 更新检查和单实例收敛共用 `Version.compare`。两边规则一旦分叉，会出现
/// 「更新器认为有新版本、实例守护认为旧副本更新」这种自相矛盾的行为，所以把
/// 比较规则本身钉住。
struct VersionTests {
    @Test func comparesNumericSegments() {
        #expect(Version.compare("2.3.3", "2.3.2") == .orderedDescending)
        #expect(Version.compare("2.3.10", "2.3.9") == .orderedDescending)
        #expect(Version.compare("2.4", "2.3.9") == .orderedDescending)
        #expect(Version.compare("2.3.3", "2.4") == .orderedAscending)
    }

    @Test func treatsMissingSegmentsAsZero() {
        #expect(Version.compare("2.3", "2.3.0") == .orderedSame)
        #expect(Version.compare("2.3", "2.3.1") == .orderedAscending)
    }

    @Test func equalVersionsCompareSame() {
        #expect(Version.compare("2.3.3", "2.3.3") == .orderedSame)
    }
}

/// 更新后旧副本可能还活着（废纸篓、下载目录、挂载的 DMG）。两个进程都会响应
/// Finder 扩展的点击，必须收敛成一个。这里钉住"谁留下"的判定。
@MainActor
struct SingleInstanceGuardTests {
    private let earlier = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    private func info(_ version: String, _ launchDate: Date, _ pid: pid_t) -> SingleInstanceGuard.InstanceInfo {
        .init(version: version, launchDate: launchDate, pid: pid)
    }

    @Test func newestVersionWins() {
        #expect(SingleInstanceGuard.shouldKeepSelf(
            current: info("2.3.3", earlier, 200),
            other: info("2.3.0", later, 100)
        ))
    }

    @Test func olderVersionQuits() {
        #expect(!SingleInstanceGuard.shouldKeepSelf(
            current: info("2.3.0", later, 100),
            other: info("2.3.3", earlier, 200)
        ))
    }

    @Test func sameVersionKeepsTheLaterLaunch() {
        // 用户刚打开的副本才该留下：从 Xcode 跑 Debug 构建不该被正式版挤掉
        #expect(SingleInstanceGuard.shouldKeepSelf(
            current: info("2.3.3", later, 200),
            other: info("2.3.3", earlier, 100)
        ))
        #expect(!SingleInstanceGuard.shouldKeepSelf(
            current: info("2.3.3", earlier, 100),
            other: info("2.3.3", later, 200)
        ))
    }

    @Test func sameVersionAndLaunchTimeKeepsLowerPID() {
        // 同时启动时用 PID 决胜，保证两个进程不会互相终止
        #expect(SingleInstanceGuard.shouldKeepSelf(
            current: info("2.3.3", earlier, 100),
            other: info("2.3.3", earlier, 200)
        ))
        #expect(!SingleInstanceGuard.shouldKeepSelf(
            current: info("2.3.3", earlier, 200),
            other: info("2.3.3", earlier, 100)
        ))
    }
}
