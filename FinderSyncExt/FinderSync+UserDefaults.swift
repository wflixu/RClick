//
//  FinderSync+UserDefaults.swift
//  FinderSyncExt
//
//  Created by 李旭 on 2024/4/7.
//

import Foundation

import os.log

private let logger = Logger(subsystem: subsystem, category: "user_defaults")

extension UserDefaults {
    var showContextualMenuForItem: Bool {
        defaults(for: Key.showContextualMenuForItem) ?? true
    }

    var showContextualMenuForContainer: Bool {
        defaults(for: Key.showContextualMenuForContainer) ?? true
    }

    var showContextualMenuForSidebar: Bool {
        defaults(for: Key.showContextualMenuForSidebar) ?? true
    }

    var showToolbarItemMenu: Bool {
        defaults(for: Key.showToolbarItemMenu) ?? true
    }

    var copySeparator: String {
        let spparator = defaults(for: Key.copySeparator) ?? ""
        return spparator.isEmpty ? " " : spparator
    }

    var copyOption: CopyOption {
        let optionRaw = defaults(for: Key.copyOption) ?? 0
        return CopyOption(rawValue: optionRaw) ?? .origin
    }

    var newFileName: String {
        defaults(for: Key.newFileName) ?? "Untitled"
    }

    var newFileExtension: NewFileExtension {
        let fileExtensionRaw = defaults(for: Key.newFileExtension) ?? ""
        return NewFileExtension(rawValue: fileExtensionRaw) ?? .none
    }

    var showSubMenuForApplication: Bool {
        defaults(for: Key.showSubMenuForApplication) ?? false
    }

    var showSubMenuForAction: Bool {
        defaults(for: Key.showSubMenuForAction) ?? false
    }

    private func defaults<T>(for key: String) -> T? {
        if let value = object(forKey: key) as? T {
            return value
        } else {
            logger.info("Missing key for \(key, privacy: .public), using default true value")
            return nil
        }
    }
}

