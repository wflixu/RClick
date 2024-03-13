//
//  FinderSync.swift
//  FinderSyncExt
//
//  Created by 李旭 on 2024/3/13.
//

import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    var myFolderURL = URL(fileURLWithPath: "/")
    
    override init() {
        super.init()
        initLogSetting()
        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath as NSString)
        
        // Set up the directory we are syncing.
        FIFinderSyncController.default().directoryURLs = [self.myFolderURL]
        
        // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.colorPanelName)!, label: "Status One" , forBadgeIdentifier: "One")
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.cautionName)!, label: "Status Two", forBadgeIdentifier: "Two")
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
        return "FinderSy: Click the toolbar item for a menu."
    }
    
    override var toolbarItemImage: NSImage {
        return NSImage(named: NSImage.cautionName)!
    }
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        // Produce a menu for the extension.
        let menu = NSMenu(title: "RClick")
        
        if (menuKind == FIMenuKind.contextualMenuForContainer) {
            menu.addItem(withTitle: "MenuForContainer", action: #selector(sampleAction(_:)), keyEquivalent: "")
            
            // 创建一级菜单项
           let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
                   
            // 创建二级菜单
           let subMenu = NSMenu()
           
           // 添加二级菜单项
           subMenu.addItem(NSMenuItem(title: "New", action: nil, keyEquivalent: ""))
           subMenu.addItem(NSMenuItem(title: "Open", action: nil, keyEquivalent: ""))
           subMenu.addItem(NSMenuItem.separator())
           subMenu.addItem(NSMenuItem(title: "Quit", action: nil, keyEquivalent: "q"))
           
           // 将二级菜单附加到一级菜单项
            fileMenuItem.submenu = subMenu
              // 添加一级菜单项到主菜单
            menu.addItem(fileMenuItem)
        }
        
        if (menuKind == FIMenuKind.contextualMenuForItems) {
            menu.addItem(withTitle: "MenuForItems", action: #selector(sampleAction(_:)), keyEquivalent: "")
        }
        
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
    
    func initLogSetting(){
        let tmpPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as NSURL
        let fileName = "/out.log"// 注意不是NSData!
        let logFilePath = tmpPath.path!.appending(fileName)
        freopen(logFilePath.cString(using: .utf8), "a+", stdout)
        freopen(logFilePath.cString(using: .utf8), "a+", stderr);
        //writeLog(str: logFilePath)
    }
    
}
