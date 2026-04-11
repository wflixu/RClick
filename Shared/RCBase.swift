//
//  RCBase.swift
//  RClick
//
//  Created by 李旭 on 2024/9/26.
//
import AppKit
import Foundation
import OSLog

/// Logger for RCBase model operations
private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "RClick",
    category: "RCBase"
)

protocol RCBase: Hashable, Identifiable, Codable {
    var id: String { get }
}

struct OpenWithApp: RCBase {
    var id: String

    init(id: String = UUID().uuidString, appURL url: URL) {
        self.id = id
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

extension OpenWithApp {
    init?(bundleIdentifier identifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            return nil
        }
        self.init(appURL: url)
    }

    static let vscode = OpenWithApp(bundleIdentifier: "com.microsoft.VSCode")
    static let terminal = OpenWithApp(bundleIdentifier: "com.apple.Terminal")
    static var defaultApps: [OpenWithApp] {
        [
            .terminal,
            .vscode
        ].compactMap { $0 }
    }
}

struct PermissiveDir: RCBase {
    var id: String
    var url: URL
    var bookmark: Data

    init(id: String = UUID().uuidString, permUrl url: URL) {
        self.id = id
        self.url = url
        let result = url.startAccessingSecurityScopedResource()
        logger.info("start init PermissiveDir------------------------")
        if !result {
            logger.error("Fail to start access security scoped resource on \(url.path)")
        }
        do {
            bookmark = try url.bookmarkData(options: .withSecurityScope)
        } catch {
            logger.warning("\(error.localizedDescription)")
            fatalError()
        }
    }

//    enum CodingKeys: String, CodingKey {
//        case url, bookmark
//    }
//
//    init(from decoder: any Decoder) throws {
//        let values = try decoder.container(keyedBy: CodingKeys.self)
//        bookmark = try values.decode(Data.self, forKey: .bookmark)
//        var isStale = false
//        do {
//            url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
//            let result = url.startAccessingSecurityScopedResource()
//
//            if !result {
//                logger.error("Fail to start access security scoped resource on \(path)")
//            }
//        } catch {
//            // Show for the main app
//            url = try values.decode(URL.self, forKey: .url)
//        }
//        id = UUID().uuidString
//    }
}

extension PermissiveDir {
    static var home: PermissiveDir? {
        guard let pw = getpwuid(getuid()),
              let home = pw.pointee.pw_dir
        else {
            return nil
        }
        let path = FileManager.default.string(withFileSystemRepresentation: home, length: strlen(home))
        let url = URL(fileURLWithPath: path)
        return PermissiveDir(permUrl: url)
    }

    static var application: PermissiveDir? {
        PermissiveDir(permUrl: URL(fileURLWithPath: "/Applications"))
    }

    static var volumns: [PermissiveDir] {
        let volumns = (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [], options: .skipHiddenVolumes) ?? []).dropFirst()
        return volumns.compactMap { PermissiveDir(permUrl: $0) }
    }

    static var defaultFolders: [PermissiveDir] {
        [.home].compactMap { $0 } + volumns
    }
}

// 常用目录
struct CommonDir: RCBase {
    var id: String
    var name: String
    var url: URL
    var icon: String
    init(id: String, name: String, url: URL, icon: String) {
        self.id = id
        self.name = name
        self.url = url
        self.icon = icon
    }
}

struct RCAction: RCBase {
    static func == (lhs: RCAction, rhs: RCAction) -> Bool {
        lhs.id == rhs.id
    }

    var id: String

    var name: String
    var enabled = true
    var idx: Int
    var icon: String

    init(id: String, name: String, enabled: Bool = true, idx: Int, icon: String) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.idx = idx
        self.icon = icon
    }
}

extension RCAction {

    static let copyPath = RCAction(id: "copy-path", name: "Copy Path", idx: 0, icon: "doc.on.doc")
    static let deleteDirect = RCAction(id: "delete-direct", name: "Delete Direct", idx: 1, icon: "trash")
    static let hideFileDir = RCAction(id: "hide", name: "Hide", idx: 2, icon: "eye.slash")
    static let unhideFileDir = RCAction(id: "unhide", name: "Unhide", idx: 3, icon: "eye")
    static let airdrop = RCAction(id: "airdrop", name: "AirDrop", idx: 4, icon: "paperplane")

    static var all: [RCAction] = [.copyPath, .deleteDirect, .airdrop, .hideFileDir, .unhideFileDir]
}

// New File Type
struct NewFile: RCBase {
    static func == (lhs: NewFile, rhs: NewFile) -> Bool {
        lhs.id == rhs.id
    }

    var ext: String
    var name: String
    var enabled = true
    var idx: Int
    var icon: String
    var id: String
    var openApp: URL?
    var template: URL?

    init(ext: String, name: String, enabled: Bool = true, idx: Int, icon: String = "document", id: String = UUID().uuidString) {
        self.ext = ext
        self.name = name
        self.enabled = enabled
        self.idx = idx
        self.icon = icon
        self.id = id
    }
}

extension NewFile {
    static var all: [NewFile] = [.txt, .md, .json, .docx, .pptx, .xlsx]

    // 图标名称对应 Assets.xcassets 中的 PNG 图标，已共享到 FinderSyncExt 目标
    static let json = NewFile(ext: ".json", name: "JSON", idx: 0, icon: "icon-file-json")
    static let txt = NewFile(ext: ".txt", name: "TXT", idx: 1, icon: "icon-file-txt")
    static let md = NewFile(ext: ".md", name: "Markdown", idx: 2, icon: "icon-file-md")
    static let docx = NewFile(ext: ".docx", name: "DOCX", idx: 3, icon: "icon-file-docx")
    static let pptx = NewFile(ext: ".pptx", name: "PPTX", idx: 4, icon: "icon-file-pptx")
    static let xlsx = NewFile(ext: ".xlsx", name: "XLSX", idx: 5, icon: "icon-file-xlsx")
}

// MARK: - Menu Item Models for Extension Communication

/// Menu item for opening files with external applications
struct AppMenuItem: Codable {
    let id: String
    let name: String
    let icon: String
    let tag: Int
    let appURL: String?  // 应用路径，用于获取应用图标

    init(id: String, name: String, icon: String, tag: Int, appURL: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.tag = tag
        self.appURL = appURL
    }
}

/// Menu item for custom actions (copy path, delete, etc.)
struct ActionMenuItem: Codable {
    let id: String
    let name: String
    let icon: String
    let tag: Int

    init(id: String, name: String, icon: String, tag: Int) {
        self.id = id
        self.name = name
        self.icon = icon
        self.tag = tag
    }
}

/// Menu item for creating new files
struct NewFileMenuItem: Codable {
    let id: String
    let name: String
    let ext: String
    let icon: String

    init(id: String, name: String, ext: String, icon: String) {
        self.id = id
        self.name = name
        self.ext = ext
        self.icon = icon
    }
}

/// Menu item for common directories
struct CommonDirMenuItem: Codable {
    let id: String
    let name: String
    let icon: String

    init(id: String, name: String, icon: String) {
        self.id = id
        self.name = name
        self.icon = icon
    }
}

// MARK: - Conversion Extensions

extension RCAction {
    /// Convert RCAction to ActionMenuItem for the extension
    func toActionMenuItem() -> ActionMenuItem {
        return ActionMenuItem(
            id: id,
            name: name,
            icon: icon,
            tag: idx
        )
    }
}

extension OpenWithApp {
    /// Convert OpenWithApp to AppMenuItem for the extension
    func toAppMenuItem() -> AppMenuItem {
        return AppMenuItem(
            id: id,
            name: name,
            icon: "app",
            tag: 0,
            appURL: url.path
        )
    }
}
