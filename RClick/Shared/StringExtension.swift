//
//  StringExtension.swift
//  RClick
//
//  Created by 李旭 on 2024/4/5.
//

import Foundation



let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
var subsystem: String { bundleIdentifier }

enum Key {
    static let showContextualMenuForItem = "SHOW_CONTEXTUAL_MENU_FOR_ITEM"
    static let showContextualMenuForContainer = "SHOW_CONTEXTUAL_MENU_FOR_CONTAINER"
    static let showContextualMenuForSidebar = "SHOW_CONTEXTUAL_MENU_FOR_SIDEBAR"
    static let showToolbarItemMenu = "SHOW_TOOLBAR_ITEM_MENU"

    static let globalApplicationArgumentsString = "GLOBAL_APPLICATION_ARGUMENTS_STRING"
    static let globalApplicationEnvironmentString = "GLOBAL_APPLICATION_ENVIRONMENT_STRING"

    static let copySeparator = "COPY_SEPARATOR"
    static let copyOption = "COPY_OPTION"
    static let newFileName = "NEW_FILE_NAME"
    static let newFileExtension = "NEW_FILE_EXTENSION"

    static let showSubMenuForApplication = "SHOW_SUB_MENU_FOR_APPLICATION"
    static let showSubMenuForAction = "SHOW_SUB_MENU_FOR_ACTION"
    static let messageFromFinder = "RCLICK_FINDER_Main"
    static let messageFromMain = "RCLICK_MAIN_FINDER"
}

enum CopyOption: Int, CustomStringConvertible, CaseIterable, Identifiable {
    var id: Int { rawValue }

    case origin, escape, quoto

    var description: String {
        switch self {
        case .origin: return String(localized: "Use origin path")
        case .escape: return String(localized: "Escape \" \" with \"\\ \" ")
        case .quoto: return String(localized: "Wrap entire path with \"\"")
        }
    }
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
