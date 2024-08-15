//
//  AppMenuItem.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import AppKit
import Foundation

import OrderedCollections

struct AppMenuItem: MenuItem {
    init(appURL url: URL) {
        self.url = url
        itemName = url.deletingPathExtension().lastPathComponent
    }

    var url: URL
    var itemName: String
    var inheritFromGlobalArguments = true
    var inheritFromGlobalEnvironment = true
    var arguments: [String] = []
    var environment: [String: String] = [:]

    var appName: String {
        FileManager.default.displayName(atPath: url.path)
    }

    var name: String {
        itemName.isEmpty ? appName : itemName
    }
}

extension AppMenuItem {
    init?(bundleIdentifier identifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            return nil
        }
        self.init(appURL: url)
    }

    static let xcode = AppMenuItem(bundleIdentifier: "com.apple.dt.Xcode")
    static let vscode = AppMenuItem(bundleIdentifier: "com.microsoft.VSCode")
    static let terminal = AppMenuItem(bundleIdentifier: "com.apple.Terminal")
    static var defaultApps: [AppMenuItem] {
        [
            .terminal,
//            .vscode
        ].compactMap { $0 }
    }
}
