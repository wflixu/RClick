//
//  FinderCommChannel.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import Foundation


import AppKit
import os.log

private let logger = Logger(subsystem: subsystem, category: "app_comm_channel")

class FinderCommChannel {
    var folderItemStore: FolderItemStore?
    var menuItemStore: MenuItemStore?
    func setup(_ folderStore:FolderItemStore, _ menuStore: MenuItemStore) {
        self.folderItemStore = folderStore
        self.menuItemStore = menuStore
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(choosePermissionFolder(_:)), name: .init(rawValue: "ChoosePermissionFolder"), object: mainAppBundleID)
        center.addObserver(self, selector: #selector(refreshMenuItems(_:)), name: .init(rawValue: "RefreshMenuItems"), object: mainAppBundleID)
        center.addObserver(self, selector: #selector(refreshFolderItems(_:)), name: .init(rawValue: "RefreshFolderItems"), object: mainAppBundleID)
    }

    func send(name: String, data: [AnyHashable: Any]? = nil) {
        logger.notice("finder channel Sending \(name) data: \(data ?? [:])")
        DistributedNotificationCenter.default()
            .postNotificationName(.init(rawValue: name),
                                  object: mainAppBundleID,
                                  userInfo: data,
                                  deliverImmediately: true)
    }

    @MainActor @objc func choosePermissionFolder(_ notification: Notification) {
        logger.warning("choosePermissionFolder: \(notification)")
        folderItemStore?.refresh();
    }
    
    @MainActor @objc func refreshMenuItems(_ notification: Notification) {
        logger.notice("Refresh menu items")
        menuItemStore?.refresh()
    }
    
    @MainActor @objc func refreshFolderItems(_ notification: Notification) {
        logger.notice("Refresh folder items")
        folderItemStore?.refresh()
    }

    private var mainAppBundleID: String {
        guard var bundleID = Bundle.main.bundleIdentifier,
              let index = bundleID.lastIndex(of: ".")
        else { return "" }
        bundleID.removeSubrange(index ..< bundleID.endIndex)
        return bundleID
    }
}
