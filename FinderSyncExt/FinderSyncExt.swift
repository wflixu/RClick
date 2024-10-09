//
//  FinderSync.swift
//  FinderSyncExt
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import Cocoa
import FinderSync

import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RClick", category: "FinderOpen")

class FinderSyncExt: FIFinderSync {
    var myFolderURL = URL(fileURLWithPath: "/Users/")
    var isHostAppOpen = true
//    let appState = AppState()
//    let messager = Messager.shared
    
    var triggerManKind = FIMenuKind.contextualMenuForContainer
    
    override init() {
        logger.info("ext start")
        super.init()
        FIFinderSyncController.default().directoryURLs = [myFolderURL]
        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath as NSString)
//        Task {
//            self.appState = await AppState()
//
//            if let appState = self.appState {
//                let dirs = await appState.dirs
//                let urls = Set(dirs.map { bkm in
//                    bkm.url
//                })
//                FIFinderSyncController.default().directoryURLs = urls
//            }
//        }
        logger.info("---- finderOpen init")
//        let urls = Set(appState.dirs.map { bkm in
//            bkm.url
//        })
//        FIFinderSyncController.default().directoryURLs = urls
//        finderChannel.setup(folderStore, menuStore)
//
//        messager.on(name: "quit") { _ in
//            self.isHostAppOpen = false
//        }
//        messager.on(name: "running") { _ in
//            self.isHostAppOpen = true
//            logger.warning("startt running")
//        }
    }
    
    // MARK: - Primary Finder Sync protocol methods

    override func beginObservingDirectory(at url: URL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        NSLog("beginObservingDirectoryAtURL: %@", url.path as NSString)
        let dirs = FIFinderSyncController.default().directoryURLs!
        
        for dir in dirs {
            logger.notice("Sync directory set to \(dir.path)")
        }
    }
    
    override func endObservingDirectory(at url: URL) {
        // The user is no longer seeing the container's contents.
        NSLog("endObservingDirectoryAtURL: %@", url.path as NSString)
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
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        // Produce a menu for the extension.
        let menu = NSMenu(title: "RClick")
        menu.addItem(withTitle: "RClick Menu Item", action: #selector(sampleAction(_:)), keyEquivalent: "")
        return menu
    }
    
    @IBAction func sampleAction(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("sampleAction: menu item: %@, target = %@, items = ", item.title as NSString, target!.path as NSString)
        for obj in items! {
            NSLog("    %@", obj.path as NSString)
        }
    }
    
//    @MainActor override func menu(for menuKind: FIMenuKind) -> NSMenu {
//        // Produce a menu for the extension.
//        triggerManKind = menuKind
//        
//        let applicationMenu = NSMenu(title: "RClick")
//        guard isHostAppOpen else {
//            return applicationMenu
//        }
////        switch menuKind {
//////        // finder 中my选中文件或文件夹
////        case .contextualMenuForContainer:
////            createMenuForContainer(applicationMenu)
//
////        // finder 中 有选中文件或文件夹
////        case .contextualMenuForItems:
////            NSLog("contextualMenuForItems")
////
////            createMenuForItems(applicationMenu)
////
////        case .toolbarItemMenu:
////
////            createMenuForToolbar(applicationMenu)
//
////        default:
////            print("Some other character")
////        }
//       
//        return applicationMenu
//    }

    @objc func createMenuForContainer(_ applicationMenu: NSMenu) {
        for nsmenu in createAppItems() {
            applicationMenu.addItem(nsmenu)
        }
            
        if let fileMenuItem = createFileCreateMenuItem() {
            applicationMenu.addItem(fileMenuItem)
        }
    }
    
    @objc func createMenuForItems(_ applicationMenu: NSMenu) {
        for nsmenu in createAppItems() {
            applicationMenu.addItem(nsmenu)
        }
        
        for item in createActionMenuItems() {
            applicationMenu.addItem(item)
        }
    }
    
    @objc func createMenuForToolbar(_ applicationMenu: NSMenu) {
        for nsmenu in createAppItems() {
            applicationMenu.addItem(nsmenu)
        }
            
        if let fileMenuItem = createFileCreateMenuItem() {
            applicationMenu.addItem(fileMenuItem)
        }
    }
   
    @objc func createAppItems() -> [NSMenuItem] {
        let appMenuItems: [NSMenuItem] = []
//
//        for item in appState.apps {
//            let menuItem = NSMenuItem()
//            menuItem.target = self
//            menuItem.title = String(localized: "Open With \(item.name)")
//            menuItem.action = #selector(appOpen(_:))
//            menuItem.toolTip = "\(item.name)"
//            menuItem.tag = 0
//            menuItem.keyEquivalent = item.id
//            menuItem.image = NSWorkspace.shared.icon(forFile: item.url.path)
//            appMenuItems.append(menuItem)
//        }
        return appMenuItems
    }

    @objc func createActionMenuItems() -> [NSMenuItem] {
        let actionMenuitems: [NSMenuItem] = []
        
//        for item in menuStore.actionItems.filter(\.enabled) {
//            let menuItem = NSMenuItem()
//            menuItem.target = self
//            menuItem.title = String(localized: String.LocalizationValue(item.key))
//            menuItem.action = #selector(actioning(_:))
//            menuItem.toolTip = "\(item.name)"
//            menuItem.tag = 1
//            menuItem.image = NSImage(systemSymbolName: item.iconName, accessibilityDescription: item.iconName)!
//            logger.info("item key\(item.key)")
//            actionMenuitems.append(menuItem)
//        }
        return actionMenuitems
    }
    
    // 创建文件菜单容器
    @objc func createFileCreateMenuItem() -> NSMenuItem? {
//        let enabledFiletypeItems = menuStore.filetypeItems.filter(\.enabled)
//        if enabledFiletypeItems.isEmpty {
//            return nil
//        }
        let menuItem = NSMenuItem()
        menuItem.title = String(localized: "New File")
        menuItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "doc.badge.plus")!
        let submenu = NSMenu(title: "file create menu")
//        for item in enabledFiletypeItems {
//            let menuItem = NSMenuItem()
//            menuItem.target = self
//            menuItem.title = item.name
//            menuItem.action = #selector(createFile(_:))
//            menuItem.toolTip = "\(item.name)"
//            menuItem.tag = 2
//
//            if let img = NSImage(named: item.iconName) {
//                menuItem.image = img
//            } else {
//                logger.info("")
//            }
//
//            submenu.addItem(menuItem)
//        }
        menuItem.submenu = submenu
        return menuItem
    }
    
//    @MainActor @objc func createFile(_ menuItem: NSMenuItem) {
    ////        let item = menuStore.getFileCreateItem(name: menuItem.title)
//        let url = FIFinderSyncController.default().targetedURL()
//
//        if let target = url?.path(), let ext = item?.ext {
//            messager.sendMessage(name: Key.messageFromFinder, data: MessagePayload(action: "Create File", target: [target], ext: ext))
//        }
//    }
    
//    @MainActor @objc func actioning(_ menuItem: NSMenuItem) {
//        guard let item = menuStore.getActionItem(name: menuItem.title) else {
//            logger.info("not item ad ")
//            return
//        }
//
//        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else {
//            logger.info("not urls")
//            return
//        }
//
//        let urlstr = urls.map { $0.path }
//        messager.sendMessage(name: Key.messageFromFinder, data: MessagePayload(action: item.key, target: urlstr))
//    }
    
    @objc func appOpen(_ menuItem: NSMenuItem) {
        var target: String
        switch triggerManKind {
        case FIMenuKind.contextualMenuForItems:
            let urls = FIFinderSyncController.default().selectedItemURLs()
            guard let targetURL = urls?.first
            else { return }
            target = targetURL.path

        case FIMenuKind.toolbarItemMenu:
            let selectedURLs = FIFinderSyncController.default().selectedItemURLs()

            if let targetURL = selectedURLs?.first {
                target = targetURL.path
            } else {
                if let targetURL2 = FIFinderSyncController.default().targetedURL() {
                    target = targetURL2.path
                } else {
                    logger.warning("no target URL")
                    return
                }
            }

        default:
            guard let targetURL = FIFinderSyncController.default().targetedURL()
            else { return }
            target = targetURL.path
        }
        
        logger.info("apppen \(menuItem.keyEquivalent) --- target:\(target), app")

//        let item = menuStore.getAppItem(name: menuItem.title)
//        if let appUrl = item?.url {
//            messager.sendMessage(name: Key.messageFromFinder, data: MessagePayload(action: "open", target: [target], app: appUrl.path))
//        }
    }
}
