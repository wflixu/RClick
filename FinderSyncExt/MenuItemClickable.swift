//
//  MenuItemClickable.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RClick", category: "menu_click")

protocol MenuItemClickable {
    func menuClick(with urls: [URL])
}

extension AppMenuItem: MenuItemClickable {
    func menuClick(with urls: [URL]) {
        // This method is no longer used directly in the extension
        // App opening is now handled by sending messages to the main app
        logger.info("AppMenuItem click: \(name) for \(urls.count) files")
    }
}

extension ActionMenuItem: MenuItemClickable {
    static let actions: [([URL]) -> ActionMenuResult] = [
        // Copy Path
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
        // Copy Filename
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
        // Reveal in Finder
        { urls in
            let subResults = urls.map { url in
                let success = NSWorkspace.shared.selectFile(url.deletingLastPathComponent().path, inFileViewerRootedAtPath: "")
                return ActionMenuResult(success: success)
            }
            return ActionMenuResult(success: subResults.allSatisfy(\.success), subResults: subResults)
        },
        // Create New File
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
        let result = ActionMenuItem.actions[idx](urls)
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
