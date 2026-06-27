//
//  RCBase.swift
//  RClick
//
//  Created by 李旭 on 2024/9/26.
//
import AppKit
import Foundation

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

    static var vscode: OpenWithApp? {
        // 尝试多个 VS Code 变体的 bundle identifier
        let identifiers = [
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
        ]
        if let id = identifiers.first(where: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }),
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            return OpenWithApp(appURL: url)
        }
        // 回退：搜索常见路径
        let commonPaths = [
            "/Applications/Visual Studio Code.app",
            "/Applications/Visual Studio Code - Insiders.app",
            NSHomeDirectory() + "/Applications/Visual Studio Code.app",
        ]
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return OpenWithApp(appURL: URL(fileURLWithPath: path))
            }
        }
        return nil
    }
    static let terminal = OpenWithApp(bundleIdentifier: "com.apple.Terminal")
    static var defaultApps: [OpenWithApp] {
        [
            .terminal,
            vscode,
        ].compactMap { $0 }
    }
}

// MARK: - Common Directory Icon Resolution

/// 根据目录路径返回对应的 SF Symbol 图标名称
/// 优先使用直接的路径拼接比较（不受 iCloud 重定向影响），FileManager API 作为补充
func iconForDirectory(url: URL) -> String {
    let resolvedPath = url.resolvingSymlinksInPath().path
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser

    // 第一优先级：用户主目录下的标准子目录（直接路径拼接，不受 iCloud 影响）
    let userDirs: [(String, String)] = [
        ("Desktop", "desktopcomputer"),
        ("Documents", "doc"),
        ("Downloads", "arrow.down.circle"),
        ("Pictures", "photo"),
        ("Music", "music.note"),
        ("Movies", "film"),
        ("Library", "books.vertical"),
        ("Public", "person.2"),
        ("Sites", "globe"),
        ("Applications", "square.grid.2x2"),
    ]

    for (subPath, icon) in userDirs {
        if home.appendingPathComponent(subPath).resolvingSymlinksInPath().path == resolvedPath {
            return icon
        }
    }

    // 用户主目录
    if resolvedPath == home.resolvingSymlinksInPath().path {
        return "house.fill"
    }

    // 第二优先级：FileManager 标准目录（可能被 iCloud 重定向）
    let standardDirs: [(FileManager.SearchPathDirectory, String)] = [
        (.desktopDirectory, "desktopcomputer"),
        (.documentDirectory, "doc"),
        (.downloadsDirectory, "arrow.down.circle"),
        (.musicDirectory, "music.note"),
        (.moviesDirectory, "film"),
        (.picturesDirectory, "photo"),
        (.libraryDirectory, "books.vertical"),
    ]

    for (dir, icon) in standardDirs {
        if let standardURL = fm.urls(for: dir, in: .userDomainMask).first,
           standardURL.resolvingSymlinksInPath().path == resolvedPath {
            return icon
        }
    }

    // 系统级目录
    let systemPaths: [(String, String)] = [
        ("/Applications", "square.grid.2x2"),
        ("/System", "gearshape.2"),
        ("/Library", "building.columns"),
        ("/Users", "person.3"),
        ("/usr", "terminal"),
        ("/tmp", "clock"),
        ("/opt", "externaldrive"),
        ("/Volumes", "externaldrive"),
    ]

    for (sysPath, icon) in systemPaths {
        if URL(fileURLWithPath: sysPath).resolvingSymlinksInPath().path == resolvedPath {
            return icon
        }
    }

    // 默认图标
    return "folder"
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
    static var all: [NewFile] = [.txt, .md, .json, .docx, .pptx, .xlsx, .pages, .key, .numbers]

    // icon 字段为 SF Symbol 名称，作为 NSWorkspace 获取失败时的 fallback
    static let json = NewFile(ext: ".json", name: "JSON", idx: 0, icon: "curlybraces")
    static let txt = NewFile(ext: ".txt", name: "TXT", idx: 1, icon: "doc.text")
    static let md = NewFile(ext: ".md", name: "Markdown", idx: 2, icon: "doc.richtext")
    static let docx = NewFile(ext: ".docx", name: "DOCX", idx: 3, icon: "doc.richtext.fill")
    static let pptx = NewFile(ext: ".pptx", name: "PPTX", idx: 4, icon: "rectangle.on.rectangle.fill")
    static let xlsx = NewFile(ext: ".xlsx", name: "XLSX", idx: 5, icon: "tablecells")
    static let pages = NewFile(ext: ".pages", name: "Pages", idx: 6, icon: "doc.richtext")
    static let key = NewFile(ext: ".key", name: "Keynote", idx: 7, icon: "rectangle.on.rectangle")
    static let numbers = NewFile(ext: ".numbers", name: "Numbers", idx: 8, icon: "tablecells")
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
    let url: String?  // 文件夹路径，用于获取文件夹图标

    init(id: String, name: String, icon: String, url: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.url = url
    }
}

// MARK: - Conversion Extensions

extension RCAction {
    /// 本地化显示名称
    var displayName: String {
        switch id {
        case "copy-path": return String(localized: "Copy Path")
        case "delete-direct": return String(localized: "Delete Direct")
        case "hide": return String(localized: "Hide")
        case "unhide": return String(localized: "Unhide")
        case "airdrop": return String(localized: "AirDrop")
        default: return name
        }
    }

    /// Convert RCAction to ActionMenuItem for the extension
    func toActionMenuItem() -> ActionMenuItem {
        return ActionMenuItem(
            id: id,
            name: displayName,
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
