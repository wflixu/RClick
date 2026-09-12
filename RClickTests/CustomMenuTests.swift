import AppKit
import Testing
@testable import RClick

@MainActor
struct CustomMenuTests {
    private var catalog: MenuConfigPayload {
        MenuConfigPayload(
            actions: [ActionMenuItem(id: "copy-path", name: "Copy Path", icon: "doc", tag: 1)],
            apps: [
                AppMenuItem(id: "vscode-id", name: "VS Code", icon: "app", tag: 2,
                            appURL: "/Applications/Visual Studio Code.app"),
                AppMenuItem(id: "warp-id", name: "Warp", icon: "app", tag: 3,
                            appURL: "/Applications/Warp.app")
            ],
            newFiles: [
                NewFileMenuItem(id: "txt-id", name: "TXT", ext: ".txt", icon: "doc"),
                NewFileMenuItem(id: "md-id", name: "Markdown", ext: ".md", icon: "doc")
            ]
        )
    }

    private func fixture() throws -> [MenuNode] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("examples/custom_menu.json")
        return try #require(try CustomMenu.load(from: url, config: catalog))
    }

    private func load(_ json: String, config: MenuConfigPayload? = nil) throws -> [MenuNode]? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rclick-menu-\(UUID()).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try CustomMenu.load(from: url, config: config ?? catalog)
    }

    @Test func exampleResolvesHumanReadableReferencesToStableIDs() throws {
        let nodes = try fixture()
        #expect(nodes.count == 4)
        #expect(nodes[0].id == "vscode-id")
        #expect(nodes[0].appPath == nil)
        #expect(nodes[1].id == "warp-id")
        let children = try #require(nodes[3].children)
        #expect(children[0].id == "copy-path")
        let files = try #require(children[2].children)
        #expect(files.map(\.id) == ["txt-id", "md-id"])
        #expect(files.allSatisfy { $0.fileExtension == nil })
    }

    @Test func rendersThreeLevelsAndPreservesLeafDispatch() throws {
        let nodes = try fixture()
        let menu = NSMenu(title: "RClick")
        let target = NSObject()
        let action = #selector(NSObject.isEqual(_:))
        let leafIcon = NSImage(size: NSSize(width: 16, height: 16))
        let groupIcon = NSImage(size: NSSize(width: 16, height: 16))
        var leaves: [NSMenuItem] = []
        var references: [String] = []
        var symbols: [String] = []
        CustomMenu.render(nodes, into: menu, makeItem: { type, id in
            references.append("\(type.rawValue):\(id)")
            let item = NSMenuItem(title: id, action: action, keyEquivalent: "")
            item.target = target
            item.tag = leaves.count + 10
            item.image = leafIcon
            leaves.append(item)
            return item
        }, loadIcon: { symbol in
            symbols.append(symbol)
            return groupIcon
        })
        #expect(menu.items.map(\.title) == ["用 VS Code 打开", "warp-id", "", "更多"])
        #expect(menu.items[2].isSeparatorItem)
        #expect(menu.items[0] === leaves[0])
        #expect(menu.items[0].image === leafIcon)
        #expect(menu.items[3].image === groupIcon)
        let more = try #require(menu.items[3].submenu)
        #expect(more.items.count == 3)
        #expect(more.items[0] === leaves[2])
        #expect(more.items[1].isSeparatorItem)
        #expect(more.items[2].title == "新建文件")
        let files = try #require(more.items[2].submenu)
        #expect(files.items.count == 2)
        #expect(files.items[0] === leaves[3])
        #expect(files.items[1] === leaves[4])
        #expect(references == ["app:vscode-id", "app:warp-id", "action:copy-path", "new-file:txt-id", "new-file:md-id"])
        #expect(symbols == ["doc.badge.plus", "ellipsis.circle"])
        for (index, leaf) in leaves.enumerated() {
            #expect(leaf.action == action)
            #expect(leaf.target === target)
            #expect(leaf.tag == index + 10)
        }
    }

    @Test func leafPresentationOverridesPreserveDispatch() throws {
        let nodes = try #require(try load(#"[{"type":"item","itemType":"action","id":"copy-path","title":"复制路径","icon":"link"}]"#))
        let menu = NSMenu()
        let target = NSObject()
        let leaf = NSMenuItem(title: "Original", action: #selector(NSObject.isEqual(_:)), keyEquivalent: "")
        leaf.target = target
        leaf.tag = 42
        let icon = NSImage(size: NSSize(width: 16, height: 16))
        CustomMenu.render(nodes, into: menu, makeItem: { _, _ in leaf }, loadIcon: { symbol in
            #expect(symbol == "link")
            return icon
        })
        #expect(menu.items.first === leaf)
        #expect(leaf.title == "复制路径")
        #expect(leaf.image === icon)
        #expect(leaf.target === target)
        #expect(leaf.tag == 42)
        #expect(leaf.action == #selector(NSObject.isEqual(_:)))
    }

    @Test func missingFileAndEmptyArrayRemainDistinct() throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("absent-\(UUID()).json")
        #expect(try CustomMenu.load(from: missing, config: catalog) == nil)
        let empty = try #require(try load("[]"))
        #expect(empty.isEmpty)
        let menu = NSMenu()
        CustomMenu.render(empty, into: menu, makeItem: { _, _ in
            Issue.record("An empty layout must not construct leaves")
            return nil
        }, loadIcon: { _ in nil })
        #expect(menu.items.isEmpty)
    }

    @Test(arguments: [
        "not JSON",
        #"[{"type":"unknown"}]"#,
        #"[{"type":"submenu","title":" " ,"children":[]}]"#,
        #"[{"type":"submenu","title":"Missing children"}]"#,
        #"[{"type":"separator","title":"Unexpected"}]"#,
        #"[{"type":"item","itemType":"app"}]"#,
        #"[{"type":"item","itemType":"app","id":"vscode-id","appPath":"/Applications/Visual Studio Code.app"}]"#,
        #"[{"type":"item","itemType":"action","fileExtension":".txt"}]"#,
        #"[{"type":"item","itemType":"action","id":"unknown"}]"#,
        #"[{"type":"item","itemType":"action","id":"copy-path","title":" "}]"#
    ])
    func invalidLayoutsThrow(json: String) {
        #expect(throws: (any Error).self) { try load(json) }
    }

    @Test func ambiguousReferenceThrows() {
        let config = MenuConfigPayload(newFiles: [
            NewFileMenuItem(id: "one", name: "One", ext: ".txt", icon: "doc"),
            NewFileMenuItem(id: "two", name: "Two", ext: ".txt", icon: "doc")
        ])
        #expect(throws: (any Error).self) {
            try load(#"[{"type":"item","itemType":"new-file","fileExtension":".txt"}]"#, config: config)
        }
    }

    @Test func oldPayloadDecodesAndCustomTreeRoundTrips() throws {
        let oldJSON = #"{"version":1,"actions":[],"apps":[],"newFiles":[],"commonDirs":[],"actionsCollapsed":false,"appsCollapsed":false,"newFilesCollapsed":true,"commonDirsCollapsed":true}"#
        let old = try JSONDecoder().decode(MenuConfigPayload.self, from: Data(oldJSON.utf8))
        #expect(old.customMenu == nil)
        var config = catalog
        config.customMenu = try fixture()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(MenuConfigPayload.self, from: data)
        #expect(try encoder.encode(decoded) == data)
        #expect(decoded.customMenu?[0].id == "vscode-id")
    }
}
