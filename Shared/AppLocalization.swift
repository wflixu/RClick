//
//  AppLocalization.swift
//  RClick
//
//  Created by Codex on 2026/7/3.
//

import Foundation
import SwiftUI

// `nonisolated` because lookup is thread-safe and the default main-actor isolation
// makes it unreachable from `LocalizedError.errorDescription`, which has to stay
// nonisolated.
nonisolated enum AppLocalization {
    static let tableName = "Localizable"

    static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: tableName)
    }
}

extension Text {
    init(appLocalized key: String) {
        self.init(AppLocalization.localized(key))
    }
}
