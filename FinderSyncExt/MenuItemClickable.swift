//
//  MenuItemClickable.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: subsystem, category: "menu_click")

protocol MenuItemClickable {
    func menuClick(with urls: [URL])
}

extension AppMenuItem: MenuItemClickable {
    func menuClick(with urls: [URL]) {
        Task {
            do {
                let config = NSWorkspace.OpenConfiguration()
                config.promptsUserIfNeeded = true
                config.arguments = arguments
                config.environment = environment
                logger.warning("app:\(url) is opening \(urls)")
                urls.forEach { url in
                    let result = url.startAccessingSecurityScopedResource()
                    if !result {
                        logger.error("Fail to start access security scoped resource on \(url.path)")
                    }
                }
                let application = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
//                (urls, withApplicationAt: url, configuration: config)
                if let path = application.bundleURL?.path,
                   let identifier = application.bundleIdentifier,
                   let date = application.launchDate
                {
                    logger.notice("Success: open \(identifier, privacy: .public) app at \(path, privacy: .public) in \(date, privacy: .public)")
                }
            } catch {
                guard let error = error as? CocoaError,
                      let underlyingError = error.userInfo["NSUnderlyingError"] as? NSError else { return }
                logger.error("Error---: \(error.localizedDescription)")
                Task { @MainActor in
                    if underlyingError.code == -10820 {
                        let alert = NSAlert(error: error)
                        alert.addButton(withTitle: String(localized: "OK", comment: "OK button"))
                        alert.addButton(withTitle: String(localized: "Remove", comment: "Remove app button"))
                        let response = alert.runModal()
                        logger.notice("NSAlert response result \(response.rawValue)")
                        switch response {
                        case .alertFirstButtonReturn:
                            logger.notice("Dismiss error with OK")
                        case .alertSecondButtonReturn:
                            logger.notice("Dismiss error with Remove app")
                            if let index = menuStore.appItems.firstIndex(of: self) {
                                menuStore.deleteAppItems(offsets: IndexSet(integer: index))
                            }
                        default:
                            break
                        }
                    } else {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = true
                        panel.allowedContentTypes = [.folder]
                        panel.canChooseDirectories = true
                        panel.directoryURL = URL(fileURLWithPath: urls[0].path)
                        let response = await panel.begin()
                        logger.notice("NSOpenPanel response result \(response.rawValue)")
                        if response == .OK {
                            folderStore.appendItems(panel.urls.map { BookmarkFolderItem($0) })
                        }
                    }
                }
            }
        }
    }
}

extension ActionMenuItem: MenuItemClickable {
    static let actions: [([URL]) -> ActionMenuResult] = [
        { urls in
            let board = NSPasteboard.general
            board.clearContents()
            let string = urls
                .map(\.path)
                .map {
                    let option = UserDefaults.group.copyOption
                    switch option {
                    case .origin:
                        return $0
                    case .escape:
                        return $0.replacingOccurrences(of: " ", with: #"\ "#)
                    case .quoto:
                        return "\"\($0)\""
                    }
                }
                .joined(separator: UserDefaults.group.copySeparator)
            let success = board.setString(string, forType: .string)

            return ActionMenuResult(success: success, message: "Pasteboard setString to \(string)")
        },
        { urls in
            let board = NSPasteboard.general
            board.clearContents()
            let string = urls
                .map(\.lastPathComponent)
                .map {
                    let option = UserDefaults.group.copyOption
                    switch option {
                    case .origin:
                        return $0
                    case .escape:
                        return $0.replacingOccurrences(of: " ", with: #"\ "#)
                    case .quoto:
                        return "\"\($0)\""
                    }
                }
                .joined(separator: UserDefaults.group.copySeparator)
            let success = board.setString(string, forType: .string)
            return ActionMenuResult(success: success, message: "Pasteboard setString to \(string)")
        },
        { urls in
            let subResults = urls.map { url in
                let success = NSWorkspace.shared.selectFile(url.deletingLastPathComponent().path, inFileViewerRootedAtPath: "")
                return ActionMenuResult(success: success)
            }
            return ActionMenuResult(success: subResults.allSatisfy(\.success), subResults: subResults)
        },
        { urls in
            let subResults = urls.map { url in
                let name = UserDefaults.group.newFileName
                let fileExtension = UserDefaults.group.newFileExtension.rawValue
                let manager = FileManager.default
                let target: URL
                if manager.directoryExists(atPath: url.path) {
                    target = url
                        .appendingPathComponent(name)
                        .appendingPathExtension(fileExtension)
                } else {
                    target = url
                        .deletingLastPathComponent()
                        .appendingPathComponent(name)
                        .appendingPathExtension(fileExtension)
                }
                logger.notice("Trying to create empty file at \(target.path, privacy: .public)")
                let success = FileManager.default.createFile(atPath: target.path, contents: Data(), attributes: nil)
                return ActionMenuResult(success: success)
            }
            return ActionMenuResult(success: subResults.allSatisfy(\.success), subResults: subResults)
        },
    ]

    func menuClick(with urls: [URL]) {
        let result = ActionMenuItem.actions[actionIndex](urls)
        if result.success {
            logger.notice("\(result.description, privacy: .public)")
        } else {
            logger.error("\(result.description, privacy: .public)")
        }
    }
}

struct ActionMenuResult: CustomStringConvertible {
    var success = false
    var message: String?
    var subResults: [ActionMenuResult]?

    var description: String {
        var result = "ActionMenuResult:\n"
        result.append("success: \(success ? "✅" : "❌") \n")
        if let message {
            result.append("message: \(message)\n")
        }
        if let subResults {
            result.append("subResults:\n")
            subResults.forEach { result.append($0.description) }
            result.append("\n")
        }
        return result
    }
}

extension FileManager {
    fileprivate func directoryExists(atPath path: String) -> Bool {
        fileExists(atPath: path, isDirectory: true)
    }

    private func fileExists(atPath path: String, isDirectory: Bool) -> Bool {
        var isDirectoryBool = ObjCBool(isDirectory)
        let exists = fileExists(atPath: path, isDirectory: &isDirectoryBool)
        return exists && (isDirectoryBool.boolValue == isDirectory)
    }
}
