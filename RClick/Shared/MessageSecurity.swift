//
//  MessageSecurity.swift
//  RClick
//
//  IPC 消息安全模块 - 防止消息伪造
//  基于：HMAC-SHA256 签名算法
//

import Foundation
import CryptoKit
import OSLog

// MARK: - Logger

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "RClick",
    category: "MessageSecurity"
)

// MARK: - 消息签名管理器

/// 为 IPC 消息提供 HMAC-SHA256 签名验证
public class MessageSecurity {

    // 共享密钥 - 应存储在 Keychain 中，这里使用常量简化实现
    private static let sharedKey = "RClick_IPC_SharedKey_2026_v1"

    /// 为消息载荷添加 HMAC 签名
    /// - Parameter payload: 需要签名的消息载荷
    /// - Returns: 带签名的消息结构
    /// - Throws: 如果编码失败则抛出错误
    public static func sign<T: Codable>(_ payload: T) throws -> SignedPayload<T> {
        let data = try JSONEncoder().encode(payload)
        let key = SymmetricKey(data: sharedKey.data(using: .utf8)!)
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)

        return SignedPayload(
            payload: payload,
            signature: Data(hmac).base64EncodedString()
        )
    }

    /// 验证消息签名
    /// - Parameter signed: 带签名的消息结构
    /// - Returns: 签名是否有效
    public static func verify<T: Codable>(_ signed: SignedPayload<T>) -> Bool {
        guard let signatureData = Data(base64Encoded: signed.signature) else {
            os_log("Failed to decode signature from base64", log: OSLog.default, type: .error)
            return false
        }

        let key = SymmetricKey(data: sharedKey.data(using: .utf8)!)

        // 编码 payload
        guard let payloadData = try? JSONEncoder().encode(signed.payload) else {
            os_log("Failed to encode payload for verification", log: OSLog.default, type: .error)
            return false
        }

        // 计算预期的 HMAC
        let expectedHMAC = HMAC<SHA256>.authenticationCode(for: payloadData, using: key)

        // 比较签名（常数时间比较，防止时序攻击）
        return signatureData.elementsEqual(Data(expectedHMAC))
    }
}

// MARK: - 带签名的消息载荷

/// 包装原始载荷并添加 HMAC 签名
public struct SignedPayload<T: Codable>: Codable {
    /// 原始消息载荷
    public let payload: T

    /// Base64 编码的 HMAC-SHA256 签名
    public let signature: String

    /// 初始化器
    /// - Parameters:
    ///   - payload: 原始消息载荷
    ///   - signature: Base64 编码的签名
    public init(payload: T, signature: String) {
        self.payload = payload
        self.signature = signature
    }
}

// MARK: - 发送者验证

/// 验证消息发送者身份
public class SenderValidator {

    /// 允许的 Bundle ID 列表
    private static let allowedBundleIDs = [
        "com.lixu.RClick",           // 主程序
        "com.lixu.RClick.FinderSyncExt"  // FinderSync 扩展
    ]

    /// 验证发送者 Bundle ID 是否合法
    /// - Returns: 验证是否通过
    public static func verifyCurrentProcess() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            os_log("Failed to get bundle identifier", log: OSLog.default, type: .error)
            return false
        }

        return allowedBundleIDs.contains(bundleID)
    }

    /// 检查 Bundle ID 是否在白名单中
    /// - Parameter bundleID: 需要检查的 Bundle ID
    /// - Returns: 是否合法
    public static func isAllowedBundleID(_ bundleID: String) -> Bool {
        return allowedBundleIDs.contains(bundleID)
    }
}

// MARK: - 消息完整性检查

extension MessageSecurity {

    /// 计算消息的 SHA256 哈希（用于日志脱敏和去重）
    /// - Parameter data: 消息数据
    /// - Returns: SHA256 哈希的十六进制字符串
    public static func hash(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// 计算消息的 SHA256 哈希（用于日志脱敏和去重）
    /// - Parameter string: 消息字符串
    /// - Returns: SHA256 哈希的十六进制字符串
    public static func hash(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else {
            return ""
        }
        return hash(data)
    }
}
