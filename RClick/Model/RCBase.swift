//
//  RCBase.swift
//  RClick
//
//  Created by 李旭 on 2024/9/26.
//
import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RClick", category: "folder_item")

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

//            url.stopAccessingSecurityScopedResource()
        } catch {
            logger.warning("\(error.localizedDescription)")
            fatalError()
        }
    }
}

extension PermissiveDir {
    static var home: SyncFolderItem? {
        guard let pw = getpwuid(getuid()),
              let home = pw.pointee.pw_dir
        else {
            return nil
        }
        let path = FileManager.default.string(withFileSystemRepresentation: home, length: strlen(home))
        let url = URL(fileURLWithPath: path)
        return SyncFolderItem(url)
    }

    static var application: SyncFolderItem? {
        SyncFolderItem(URL(fileURLWithPath: "/Applications"))
    }

    static var volumns: [SyncFolderItem] {
        let volumns = (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [], options: .skipHiddenVolumes) ?? []).dropFirst()
        return volumns.compactMap { SyncFolderItem($0) }
    }

    static var defaultFolders: [SyncFolderItem] {
        [.home].compactMap { $0 } + volumns
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
    static var all: [RCAction] = [.copyPath, .deleteDirect]

    static let copyPath = RCAction(id: "copy-path", name: "Copy Path", idx: 0, icon: "doc.on.doc")
    static let deleteDirect = RCAction(id: "delete-direct", name: "Delete Direct", idx: 1, icon: "trash")
}

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

    init(ext: String, name: String, enabled: Bool = true, idx: Int, icon: String, id: String = UUID().uuidString) {
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

    static let json = NewFile(ext: ".json", name: "JSON", idx: 0, icon: "icon-file-json")
    static let txt = NewFile(ext: ".txt", name: "TXT", idx: 1, icon: "icon-file-txt")
    static let md = NewFile(ext: ".md", name: "Markdown", idx: 2, icon: "icon-file-md")
    static let docx = NewFile(ext: ".docx", name: "DOCX", idx: 3, icon: "icon-file-docx")
    static let pptx = NewFile(ext: ".pptx", name: "PPTX", idx: 4, icon: "icon-file-pptx")
    static let xlsx = NewFile(ext: ".xlsx", name: "XLSX", idx: 5, icon: "icon-file-xlsx")
}
