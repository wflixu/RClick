//
//  DataVersion.swift
//  RClick
//
//  Created by Claude on 2026/01/16.
//

import SwiftData
import Foundation

/// 数据版本控制模型 - 用于跨进程数据同步
@Model
final class DataVersion {
    @Attribute(.unique) var key: String
    var version: Int
    var updatedAt: Date

    init(key: String, version: Int) {
        self.key = key
        self.version = version
        self.updatedAt = Date()
    }
}
