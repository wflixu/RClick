//
//  StringExtension.swift
//  RClick
//
//  Created by 李旭 on 2024/4/5.
//

import Foundation

import os.log

let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
var subsystem: String { bundleIdentifier }

private let logger = Logger(subsystem: subsystem, category: "user_defaults")

enum Key {
    static let showContextualMenuForItem = "SHOW_CONTEXTUAL_MENU_FOR_ITEM"
    static let showContextualMenuForContainer = "SHOW_CONTEXTUAL_MENU_FOR_CONTAINER"
    static let showContextualMenuForSidebar = "SHOW_CONTEXTUAL_MENU_FOR_SIDEBAR"
    static let showToolbarItemMenu = "SHOW_TOOLBAR_ITEM_MENU"
    static let showDockIcon = "SHOW_DOCK_ICON"

    static let globalApplicationArgumentsString = "GLOBAL_APPLICATION_ARGUMENTS_STRING"
    static let globalApplicationEnvironmentString = "GLOBAL_APPLICATION_ENVIRONMENT_STRING"

    static let copySeparator = "COPY_SEPARATOR"
    static let newFileName = "NEW_FILE_NAME"
    static let newFileExtension = "NEW_FILE_EXTENSION"

    static let showSubMenuForApplication = "SHOW_SUB_MENU_FOR_APPLICATION"
    static let showSubMenuForAction = "SHOW_SUB_MENU_FOR_ACTION"
    static let messageFromFinder = "RCLICK_FINDER_Main"
    static let messageFromMain = "RCLICK_MAIN_FINDER"
    
    static let apps = "RCLICK_APPs"
    static let actions = "RCLICK_ACTIONS"
    static let fileTypes = "RCLICK_FILE_TYPES"
    static let permDirs = "RCLICK_PERMISSIVE_DIRS"   
    static let commonDirs = "RCLICK_COMMON_DIRS"
    static let showMenuBarExtra = "showMenuBarExtra"
    static let showInDock = "SHOW_IN_DOCK"
    
}

enum NewFileExtension: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case none = "(none)"
    case swift
    case txt
}

extension String {
    func toDictionary(separator: Character = " ") -> [String: String] {
        split(separator: separator)
            .map { $0.split(separator: "=") }
            .filter { $0.count == 2 }
            .reduce(into: [String: String]()) { result, pair in
                let key = String(pair[0])
                let value = String(pair[1])
                result[key] = value
            }
    }
}

extension Dictionary {
    func toString(separator: String = " ") -> String {
        compactMap { "\($0)=\($1)" }.joined(separator: separator)
    }
}

func loadLocalizationKeys(from tableName: String, bundle: Bundle = .main) -> [String: String] {
    var keyToLocalizedString = [String: String]()
    var localizedStringToKey = [String: String]()

    if let path = bundle.path(forResource: tableName, ofType: "strings"),
       let strings = NSDictionary(contentsOfFile: path) as? [String: String]
    {
        for (key, value) in strings {
            keyToLocalizedString[key] = value
            localizedStringToKey[value] = key
        }
    }
    return localizedStringToKey
}

extension String {
    static func key(forLocalizedString localizedString: String, in tableName: String, bundle: Bundle = .main) -> String? {
        let localizedStringToKey = loadLocalizationKeys(from: tableName, bundle: bundle)
        return localizedStringToKey[localizedString]
    }
}

// if let key = String.key(forLocalizedString: "Hello", in: "Localizable") {
//    print("The key for 'Hello' is \(key)")
// }

extension UserDefaults {
    static var group: UserDefaults {
        UserDefaults(suiteName: "group.cn.wflixu.RClick")!
    }

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
            logger.warning("Missing key for \(key, privacy: .public), using default true value")
            return nil
        }
    }
}
