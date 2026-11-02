//
//  AppLocalization.swift
//  RClick
//
//  Created by Codex on 2026/7/3.
//

import Foundation
import SwiftUI
import os

// `nonisolated` because lookup is thread-safe and the default main-actor isolation
// makes it unreachable from `LocalizedError.errorDescription`, which has to stay
// nonisolated.
nonisolated enum AppLocalization {
    static let tableName = "Localizable"

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RClick", category: "l10n")

    /// Resolve only against the current process's catalog. A sentinel distinguishes
    /// missing keys from valid translations whose value is identical to the key.
    static func localized(_ key: String) -> String {
        let missing = "__rclick_missing_localization__"
        let value = Bundle.main.localizedString(forKey: key, value: missing, table: tableName)
        guard value == missing else { return value }
        logger.warning("Missing localization: key \(key, privacy: .public) not found in \(Bundle.main.bundlePath, privacy: .public)")
        return key
    }

}

extension Text {
    init(appLocalized key: String) {
        self.init(AppLocalization.localized(key))
    }
}
