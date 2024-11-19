//
//  FinderSync.swift
//  FinderSyncExt
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import Cocoa
import FinderSync

// MARK: DELETE

 import OSLog
 private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RClick", category: "FinderOpen")

@MainActor
class FinderSyncExt: FIFinderSync {
//    @AppLog(category: "AppState")
//    private var logger
     
    var myFolderURL = URL(fileURLWithPath: "/Users/")
    var isHostAppOpen = false
    lazy var appState: AppState = { AppState(inExt: true) }()
    
    private var tagRidDict: [Int: String] = [:]
    
    let messager = Messager.shared
    
    var triggerManKind = FIMenuKind.contextualMenuForContainer
    
    override init() {
        super.init()
        
        FIFinderSyncController.default().directoryURLs = [myFolderURL]
        logger.info("FinderSync() launched from \(Bundle.main.bundlePath as NSString)")
        
        logger.info("end ..... directoryURLS ...")
        
        logger.info("---- finderOpen init")

        messager.on(name: "quit") { _ in
//            self.
            logger.info("main app quited 。。。")
            self.isHostAppOpen = false
        }
        messager.on(name: "running") { payload in
            self.isHostAppOpen = true
//            self.
            logger.info("main app  running\(payload.description)")
            if payload.target.count > 0 {
                FIFinderSyncController.default().directoryURLs = Set(payload.target.map { URL(fileURLWithPath: $0) })
            }
            Task {
                 self.appState.refresh()
            }
        }
    }
    
    // MARK: - Primary Finder Sync protocol methods

    override func beginObservingDirectory(at url: URL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        logger.info("beginObservingDirectoryAtURL: \(url.path as NSString)")
        let dirs = FIFinderSyncController.default().directoryURLs!
        
        for dir in dirs {
            logger.notice("Sync directory set to \(dir.path)")
        }
    }
    
    override func endObservingDirectory(at url: URL) {
        // The user is no longer seeing the container's contents.
        logger.info("endObservingDirectoryAtURL: \(url.path as NSString)")
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        NSLog("requestBadgeIdentifierForURL: %@", url.path as NSString)
    }
    
    // MARK: - Menu and toolbar item support
    
    override var toolbarItemName: String {
        return "RClick"
    }
    
    override var toolbarItemToolTip: String {
        return "RClick: Click the toolbar item for a menu."
    }
    
    override var toolbarItemImage: NSImage {
        return NSImage(named: "toolbar")!
    }
    
    @MainActor override func menu(for menuKind: FIMenuKind) -> NSMenu {
        // Produce a menu for the extension.
        logger.info("mak menddd .....")
        triggerManKind = menuKind
        logger.info("start build menu ....")
        let applicationMenu = NSMenu(title: "RClick")
        guard isHostAppOpen else {
            return applicationMenu
        }
        
        switch menuKind {
        //  finder 中没有选中文件或文件夹

        case .toolbarItemMenu, .contextualMenuForItems, .contextualMenuForContainer:
            logger.info("mak menddd .....")
            createMenuForToolbar(applicationMenu)

        default:
            logger.warning("not have menuKind ")
        }

        return applicationMenu
    }

    @objc func createMenuForToolbar(_ applicationMenu: NSMenu) {
        for nsmenu in createAppItems() {
            applicationMenu.addItem(nsmenu)
        }
            
        if let fileMenuItem = createFileCreateMenuItem() {
            applicationMenu.addItem(fileMenuItem)
        }
        
        for item in createActionMenuItems() {
            applicationMenu.addItem(item)
        }
    }
   
    @objc func createAppItems() -> [NSMenuItem] {
        var appMenuItems: [NSMenuItem] = []
//
        for item in appState.apps {
            let menuItem = NSMenuItem()
            menuItem.target = self
            menuItem.title = String(localized: "Open With \(item.name)")
            menuItem.action = #selector(appOpen(_:))
            menuItem.toolTip = "\(item.name)"
            menuItem.tag = getUniqueTag(for: item.id)
            menuItem.image = NSWorkspace.shared.icon(forFile: item.url.path)
            appMenuItems.append(menuItem)
        }
        return appMenuItems
    }
    
    private func getUniqueTag(for rid: String) -> Int {
        var newTag = Int.random(in: 1...Int.max)
        
        // 确保生成的 tag 不在已有的 keys 中
        while tagRidDict.keys.contains(newTag) {
            newTag = Int.random(in: 1...Int.max)
        }
        tagRidDict[newTag] = rid
        return newTag
    }

    @objc func createActionMenuItems() -> [NSMenuItem] {
        var actionMenuitems: [NSMenuItem] = []
        
        for item in appState.actions.filter(\.enabled) {
            let menuItem = NSMenuItem()
            menuItem.target = self
            menuItem.title = String(localized: String.LocalizationValue(item.name))
            menuItem.action = #selector(actioning(_:))
            menuItem.toolTip = "\(item.name)"
            menuItem.tag = getUniqueTag(for: item.id)
            menuItem.image = NSImage(systemSymbolName: item.icon, accessibilityDescription: item.name)!
           
            actionMenuitems.append(menuItem)
        }
        return actionMenuitems
    }
    
    // 创建文件菜单容器
    @objc func createFileCreateMenuItem() -> NSMenuItem? {
        let enabledFiletypeItems = appState.newFiles.filter(\.enabled)
        if enabledFiletypeItems.isEmpty {
            return nil
        }
        let menuItem = NSMenuItem()
        menuItem.title = String(localized: "New File")
        menuItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "doc.badge.plus")!
        let submenu = NSMenu(title: "file create menu")
        for item in enabledFiletypeItems {
            let menuItem = NSMenuItem()
            menuItem.target = self
            menuItem.title = item.name
            menuItem.action = #selector(createFile(_:))
            menuItem.toolTip = "\(item.name)"
            menuItem.tag = getUniqueTag(for: item.id)

            if let app = item.openApp {
                menuItem.image = NSWorkspace.shared.icon(forFile: app.path)
            } else {
                if !item.icon.starts(with: "icon-") {
                    menuItem.image = NSImage(systemSymbolName: item.icon, accessibilityDescription: item.icon)!
                } else {
                    if let img = NSImage(named: item.icon) {
                        menuItem.image = img
                    }
                }
                 
            }
            

            submenu.addItem(menuItem)
        }
        menuItem.submenu = submenu
        return menuItem
    }
    
    @MainActor @objc func createFile(_ menuItem: NSMenuItem) {
        guard let rid = tagRidDict[menuItem.tag] else {
            logger.warning("not get rid for \(menuItem.tag)")
            return
        }
        let url = FIFinderSyncController.default().targetedURL()

        if let target = url?.path() {
            messager.sendMessage(name: Key.messageFromFinder, data: MessagePayload(action: "Create File", target: [target], rid: rid))
        }
    }
    
    @MainActor @objc func actioning(_ menuItem: NSMenuItem) {
        guard let rid = tagRidDict[menuItem.tag] else {
            logger.warning("not get rid")
            return
        }
        let target = getTargets(triggerManKind)
        if target.isEmpty {
            logger.warning("not dir when actioning")
            return
        }
        messager.sendMessage(name: Key.messageFromFinder, data: MessagePayload(action: "actioning", target: target, rid: rid))
    }
    
    func getTargets(_ kind: FIMenuKind) -> [String] {
        var target: [String] = []
        
        switch triggerManKind {
        case FIMenuKind.contextualMenuForItems:
            if let urls = FIFinderSyncController.default().selectedItemURLs() {
                for url in urls {
                    target.append(url.path())
                }
            } else {
                logger.warning("not have selected dirs")
            }
                
        case FIMenuKind.toolbarItemMenu:
            if let urls = FIFinderSyncController.default().selectedItemURLs() {
                for url in urls {
                    target.append(url.path())
                }
            }
            if target.isEmpty {
                if let targetURL = FIFinderSyncController.default().targetedURL() {
                    target.append(targetURL.path())
                }
            }
                
        default:
            if let targetURL = FIFinderSyncController.default().targetedURL() {
                target.append(targetURL.path())
            }
        }
        
        return target
    }
    
    @objc func appOpen(_ menuItem: NSMenuItem) {
        guard let rid = tagRidDict[menuItem.tag] else {
            logger.warning("not get rid")
            return
        }
        
        let target: [String] = getTargets(triggerManKind)
        if !target.isEmpty {
            messager.sendMessage(name: Key.messageFromFinder, data: MessagePayload(action: "open", target: target, rid: rid))
        } else {
            logger.warning("not get target")
        }
    }
}
