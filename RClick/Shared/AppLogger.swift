//
//  AppLogger.swift
//  RClick
//
//  Created by 李旭 on 2024/4/25.
//

import Foundation
import OSLog


@propertyWrapper
struct AppLog {

    private let logger: Logger

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "", category: String = "main") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    var wrappedValue: Logger {
        return logger
    }
}

enum AppLogExporter {
    static func exportCurrentProcess(to url: URL, since startDate: Date = Date().addingTimeInterval(-24 * 60 * 60)) throws {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let position = store.position(date: startDate)
        let subsystem = Bundle.main.bundleIdentifier ?? "RClick"
        let formatter = ISO8601DateFormatter()

        let lines = try store.getEntries(at: position).compactMap { entry -> String? in
            guard let logEntry = entry as? OSLogEntryLog,
                  logEntry.subsystem == subsystem else { return nil }
            return "\(formatter.string(from: logEntry.date)) [\(logEntry.level)] [\(logEntry.category)] \(logEntry.composedMessage)"
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let header = "RClick \(version) (\(build))\nExported: \(formatter.string(from: Date()))\n\n"
        try (header + lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
