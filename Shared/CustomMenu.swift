import AppKit

/// Layout only: leaves reference existing configured items, never executable commands.
struct MenuNode: Codable {
    enum Kind: String, Codable { case item, submenu, separator }

    var type: Kind
    var title: String?
    var icon: String?
    var itemType: MenuItemType?
    var id: String?
    var appPath: String?
    var fileExtension: String?
    var children: [MenuNode]?

    /// Resolve human-friendly selectors to the same IDs used by existing click handlers.
    func resolved(using config: MenuConfigPayload) throws -> MenuNode {
        var node = self
        let selectors = [id, appPath, fileExtension].compactMap { $0 }
        switch type {
        case .separator:
            guard title == nil, icon == nil, itemType == nil, selectors.isEmpty, children == nil else {
                throw CustomMenuError.invalid("separator cannot contain other fields")
            }
        case .submenu:
            guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let children, itemType == nil, selectors.isEmpty else {
                throw CustomMenuError.invalid("submenu requires a title and children, without an item reference")
            }
            node.children = try children.map { try $0.resolved(using: config) }
        case .item:
            guard let itemType, children == nil, selectors.count == 1,
                  !selectors[0].isEmpty else {
                throw CustomMenuError.invalid("item requires itemType and exactly one of id, appPath, fileExtension")
            }
            let matches: [String]
            switch itemType {
            case .action:
                guard appPath == nil, fileExtension == nil else { throw CustomMenuError.invalid("action requires id") }
                matches = config.actions.filter { $0.id == id }.map(\.id)
            case .app:
                guard fileExtension == nil else { throw CustomMenuError.invalid("app requires id or appPath") }
                matches = config.apps.filter { id != nil ? $0.id == id : $0.appURL == appPath }.map(\.id)
            case .newFile:
                guard appPath == nil else { throw CustomMenuError.invalid("new-file requires id or fileExtension") }
                matches = config.newFiles.filter { id != nil ? $0.id == id : $0.ext == fileExtension }.map(\.id)
            case .commonDir:
                guard appPath == nil, fileExtension == nil else { throw CustomMenuError.invalid("common-dir requires id") }
                matches = config.commonDirs.filter { $0.id == id }.map(\.id)
            }
            guard matches.count == 1 else {
                throw CustomMenuError.invalid("\(itemType.rawValue) reference '\(selectors[0])' matched \(matches.count) enabled items")
            }
            if let title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw CustomMenuError.invalid("item title cannot be blank")
            }
            node.id = matches[0]
            node.appPath = nil
            node.fileExtension = nil
        }
        return node
    }
}

enum CustomMenuError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        switch self { case .invalid(let message): return message }
    }
}

enum CustomMenu {
    /// Missing files mean legacy layout. Invalid files throw so callers can log and fall back.
    static func load(from url: URL, config: MenuConfigPayload) throws -> [MenuNode]? {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
        let nodes = try JSONDecoder().decode([MenuNode].self, from: data)
        return try nodes.map { try $0.resolved(using: config) }
    }

    /// Both nested and top-level leaves use the extension's existing item factories.
    static func render(_ nodes: [MenuNode], into menu: NSMenu,
                       makeItem: (MenuItemType, String) -> NSMenuItem?,
                       loadIcon: (String) -> NSImage?) {
        for node in nodes {
            let item: NSMenuItem
            switch node.type {
            case .separator:
                item = .separator()
            case .submenu:
                item = NSMenuItem(title: node.title ?? "", action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: item.title)
                render(node.children ?? [], into: submenu, makeItem: makeItem, loadIcon: loadIcon)
                item.submenu = submenu
            case .item:
                guard let type = node.itemType, let id = node.id, let leaf = makeItem(type, id) else { continue }
                item = leaf
                if let title = node.title { item.title = title }
            }
            if let icon = node.icon { item.image = loadIcon(icon) }
            menu.addItem(item)
        }
    }
}
