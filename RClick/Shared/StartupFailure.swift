//
//  StartupFailure.swift
//  RClick
//
//  启动阶段无法继续时的统一出口。
//

import AppKit
import Foundation
import OSLog

/// 把"说不出口的崩溃"换成"看得到的说明 + 干净退出"。
///
/// 这类失败原先一律 `fatalError`：用户看到的是进程毫无征兆地消失，日志里只有一条
/// SIGTRAP 崩溃报告，而真正的原因（哪个文件、为什么打不开）只存在于被丢弃的异常里。
/// 典型的触发场景是构建产物没有有效签名 —— App Group 容器读不到，`ModelContainer`
/// 打开失败 —— 排查时只能靠崩溃报告里的签名指纹反推。
@MainActor
enum StartupFailure {
    @AppLog(category: "StartupFailure")
    private static var logger

    /// 记录原因、告诉用户、退出。永不返回。
    ///
    /// 返回 `Never` 是给调用方的类型保证：调用点不必再造一个占位返回值。
    static func presentAndExit(_ error: Error) -> Never {
        let detail = describe(error)

        // `.fault` + `privacy: .public`：错误详情必须真的落到 log store 里。
        // 这里踩过一次坑 —— 持久化失败原本记在 `.info`，那条日志根本到不了 log store，
        // 于是失败和成功在日志上长得一模一样。
        logger.fault("启动失败，即将退出: \(detail, privacy: .public)")

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = AppLocalization.localized("Unable to open the configuration database")
        alert.informativeText = detail
        alert.addButton(withTitle: AppLocalization.localized("Quit"))
        alert.runModal()

        exit(EXIT_FAILURE)
    }

    /// 拼给用户看的原因：一句人话 + 已知成因的下一步 + 原始错误。
    ///
    /// 原始错误始终附上：定向提示只是启发式，不能替代事实。
    private static func describe(_ error: Error) -> String {
        var lines = [
            AppLocalization.localized(
                "RClick could not access its shared App Group container, so it cannot read its settings."
            )
        ]

        if let storeError = error as? SharedStoreError, storeError.looksLikeAuthorizationDenial {
            lines.append(
                AppLocalization.localized(
                    "The most likely cause is that this build is not properly signed. Rebuild it with a valid signing identity — a build signed to run locally cannot reach the App Group container."
                )
            )
        }

        lines.append("")
        lines.append(String(describing: error))
        return lines.joined(separator: "\n")
    }
}
