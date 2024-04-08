//
//  FinderSync.swift
//  FinderSyncExt
//
//  Created by 李旭 on 2024/4/4.
//

import Cocoa
import Darwin
import FinderSync
import os.log

let menuStore = MenuItemStore()
let folderStore = FolderItemStore()
let channel = FinderCommChannel()

private let logger = Logger(subsystem: subsystem, category: "menu")

class FinderSync: FIFinderSync {
    var myFolderURL = URL(fileURLWithPath: "/Users/")

    override init() {
        super.init()
        channel.setup()
        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath as NSString)
        
        // Set up the directory we are syncing.
        FIFinderSyncController.default().directoryURLs = [myFolderURL]
        
     
        
        // Monitor volumes
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { notification in
            if let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
                Task {
                    await MainActor.run {
                        logger.notice("volumeURLUserInfoKey ---")
                        folderStore.appendItem(SyncFolderItem(volumeURL))
                    }
                }
            }
        }
    }
    
    // MARK: - Primary Finder Sync protocol methods
    
    override func beginObservingDirectory(at url: URL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        NSLog("beginObservingDirectoryAtURL: %@", url.path as NSString)
    }
    
    override func endObservingDirectory(at url: URL) {
        // The user is no longer seeing the container's contents.
        NSLog("endObservingDirectoryAtURL: %@", url.path as NSString)
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        NSLog("requestBadgeIdentifierForURL: %@", url.path as NSString)
        
        // For demonstration purposes, this picks one of our two badges, or no badge at all, based on the filename.
        let whichBadge = abs(url.path.hash) % 3
        let badgeIdentifier = ["", "One", "Two"][whichBadge]
        FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
    }
    
    // MARK: - Menu and toolbar item support
    
    override var toolbarItemName: String {
        return "RClick"
    }
    
    override var toolbarItemToolTip: String {
        return "RClick: Click the toolbar item for a menu."
    }
    
    override var toolbarItemImage: NSImage {
        return NSImage(systemSymbolName: "computermouse", accessibilityDescription: "RClick Menu")!
    }
    
    @MainActor override func menu(for menuKind: FIMenuKind) -> NSMenu {
        // Produce a menu for the extension.
        let applicationMenu = NSMenu(title: "RClick")
        switch menuKind {
        case .contextualMenuForContainer:
            logger.warning("contextualMenuForContainer")
                
            for item in menuStore.appItems.filter(\.enabled) {
                logger.warning("appitems:name: \(item.name)")
                let menuItem = NSMenuItem()
                menuItem.target = self
                menuItem.title = String(format: String(localized: "Open in %@", comment: "Open in the given application"), item.name)
                menuItem.action = #selector(dirAction(_:))
                menuItem.toolTip = "\(item.name)"
                menuItem.tag = 0
                menuItem.image = item.icon
                applicationMenu.addItem(menuItem)
            }
                
        case .contextualMenuForItems:
            NSLog("contextualMenuForItems")
            
        default:
            print("Some other character")
        }
       
//        applicationMenu.addItem(withTitle: "Example Menu Item", action: #selector(sampleAction(_:)), keyEquivalent: "")
        return applicationMenu
    }
    
    @MainActor @objc func sampleAction(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
       
        logger.info("sampleAction: menu item")
        NSLog("sampleAction: menu item: %@, target = %@, items = ", item.title as NSString, target!.path as NSString)
        
        for obj in items! {
            NSLog("    %@", obj.path as NSString)
        }
    }

    @MainActor @objc func filesAction(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("sampleAction: menu item: %@, target = %@, items = ", item.title as NSString, target!.path as NSString)
        for obj in items! {
            NSLog("    %@", obj.path as NSString)
        }
    }

    @MainActor @objc func dirAction(_ menuItem: NSMenuItem) {
        guard let targetURL = FIFinderSyncController.default().targetedURL(),
              let itemURLs = FIFinderSyncController.default().selectedItemURLs() else { return }
        logger.notice("Click menu \"\(menuItem.title, privacy: .public)\", index = \(menuItem.tag, privacy: .public), target = \(targetURL, privacy: .public), items = \(itemURLs, privacy: .public)]")

        let urls = itemURLs.isEmpty ? [targetURL] : itemURLs
        switch menuItem.tag {
        case 0:
            let item = menuStore.getAppItem(name: menuItem.title)
            item?.menuClick(with: urls)
        case 1:
            let item = menuStore.getActionItem(name: menuItem.title)
            item?.menuClick(with: urls)
        default:
            break
        }
    }
}
