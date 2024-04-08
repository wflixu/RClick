//
//  AppMenuItem.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import Foundation
import AppKit

import OrderedCollections


struct AppMenuItem: MenuItem {
    init(appURL url: URL) {
        self.url = url
        itemName = url.deletingPathExtension().lastPathComponent
    }

    var url: URL
    var itemName: String
    var enabled = true
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

    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
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
    static let typora = AppMenuItem(bundleIdentifier: "abnerworks.Typora")
    static let tower = AppMenuItem(bundleIdentifier: "com.fournova.Tower3")
    static var defaultApps: [AppMenuItem] {
        [.terminal, .xcode, .vscode, .typora, .tower].compactMap { $0 }
    }
}
