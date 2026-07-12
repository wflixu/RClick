//
//  AppLocalization.swift
//  RClick
//
//  Created by Codex on 2026/7/3.
//

import Foundation
import SwiftUI

enum AppLocalization {
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
