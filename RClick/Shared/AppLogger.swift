//
//  AppLogger.swift
//  RClick
//
//  Created by 李旭 on 2024/4/25.
//

import OSLog


@propertyWrapper
struct AppLog {
    private let logger: Logger

    init(subsystem: String = subsystem, category: String = "main") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    var wrappedValue: Logger {
        return logger
    }
}

