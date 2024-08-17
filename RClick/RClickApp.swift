//
//  RClickApp.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//
import AppKit
import Foundation
import SwiftData
import SwiftUI

let channel = AppCommChannel()

@main
struct RClickApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    @Environment(\.openWindow) var openWindow

    @AppLog(category: "main")
    private var logger

    var body: some Scene {
        Settings {
            SettingsView()
        }

        .defaultAppStorage(.group)

        MenuBarExtra(
            "RClick", image: "MenuBar", isInserted: self.$showMenuBarExtra
        ) {
            MenuBarView()
        }
    }
}





// https://stackoverflow.com/a/76714125/19625526
private let kAppMenuInternalIdentifier = "app"
private let kSettingsLocalizedStringKey = "Settings\\U2026"

extension NSApplication {
    /// Open the application settings/preferences window.
    func openSettings() {
        // macOS 14 Sonoma
        if let internalItemAction = NSApp.mainMenu?.item(
            withInternalIdentifier: kAppMenuInternalIdentifier
        )?.submenu?.item(
            withLocalizedTitle: kSettingsLocalizedStringKey
        )?.internalItemAction {
            internalItemAction()
            return
        }

        guard let delegate = NSApp.delegate else { return }

        // macOS 13 Ventura
        var selector = Selector(("showSettingsWindow:"))
        if delegate.responds(to: selector) {
            delegate.perform(selector, with: nil, with: nil)
            return
        }

        // macOS 12 Monterrey
        selector = Selector(("showPreferencesWindow:"))
        if delegate.responds(to: selector) {
            delegate.perform(selector, with: nil, with: nil)
            return
        }
    }
}

// MARK: - NSMenuItem (Private)

extension NSMenuItem {
    /// An internal SwiftUI menu item identifier that should be a public property on `NSMenuItem`.
    var internalIdentifier: String? {
        guard let id = Mirror.firstChild(
            withLabel: "id", in: self
        )?.value else {
            return nil
        }

        return "\(id)"
    }

    /// A callback which is associated directly with this `NSMenuItem`.
    var internalItemAction: (() -> Void)? {
        guard
            let platformItemAction = Mirror.firstChild(
                withLabel: "platformItemAction", in: self
            )?.value,
            let typeErasedCallback = Mirror.firstChild(
                in: platformItemAction)?.value
        else {
            return nil
        }

        return Mirror.firstChild(
            in: typeErasedCallback
        )?.value as? () -> Void
    }
}

// MARK: - NSMenu (Private)

extension NSMenu {
    /// Get the first `NSMenuItem` whose internal identifier string matches the given value.
    func item(withInternalIdentifier identifier: String) -> NSMenuItem? {
        self.items.first(where: {
            $0.internalIdentifier?.elementsEqual(identifier) ?? false
        })
    }

    /// Get the first `NSMenuItem` whose title is equivalent to the localized string referenced
    /// by the given localized string key in the localization table identified by the given table name
    /// from the bundle located at the given bundle path.
    func item(
        withLocalizedTitle localizedTitleKey: String,
        inTable tableName: String = "MenuCommands",
        fromBundle bundlePath: String = "/System/Library/Frameworks/AppKit.framework"
    ) -> NSMenuItem? {
        guard let localizationResource = Bundle(path: bundlePath) else {
            return nil
        }

        return self.item(withTitle: NSLocalizedString(
            localizedTitleKey,
            tableName: tableName,
            bundle: localizationResource,
            comment: ""
        ))
    }
}

// MARK: - Mirror (Helper)

private extension Mirror {
    /// The unconditional first child of the reflection subject.
    var firstChild: Child? { self.children.first }

    /// The first child of the reflection subject whose label matches the given string.
    func firstChild(withLabel label: String) -> Child? {
        self.children.first(where: {
            $0.label?.elementsEqual(label) ?? false
        })
    }

    /// The unconditional first child of the given subject.
    static func firstChild(in subject: Any) -> Child? {
        Mirror(reflecting: subject).firstChild
    }

    /// The first child of the given subject whose label matches the given string.
    static func firstChild(
        withLabel label: String, in subject: Any
    ) -> Child? {
        Mirror(reflecting: subject).firstChild(withLabel: label)
    }
}
