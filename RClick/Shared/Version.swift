import Foundation

/// 版本号比较。
///
/// 更新检查（判断有没有新版本）和单实例收敛（判断哪个副本该留下）用的是同一套
/// 规则，不能各写一份——否则会出现「更新器认为 2.3.10 比 2.3.9 新，实例守护却
/// 认为相反」这种自相矛盾的行为。
enum Version {
    /// 逐段比较，缺省的段按 "0" 处理（"2.3" == "2.3.0"）；非数字段按字符串比较
    /// （足以处理 "2.3.3-beta" 这类标签）。
    nonisolated static func compare(_ version1: String, _ version2: String) -> ComparisonResult {
        let components1 = version1.components(separatedBy: ".")
        let components2 = version2.components(separatedBy: ".")

        for i in 0 ..< max(components1.count, components2.count) {
            let part1 = i < components1.count ? components1[i] : "0"
            let part2 = i < components2.count ? components2[i] : "0"

            if let num1 = Int(part1), let num2 = Int(part2) {
                if num1 < num2 { return .orderedAscending }
                if num1 > num2 { return .orderedDescending }
            } else {
                let comparison = part1.compare(part2)
                if comparison != .orderedSame {
                    return comparison
                }
            }
        }

        return .orderedSame
    }
}
