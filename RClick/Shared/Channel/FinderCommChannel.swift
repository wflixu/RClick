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
    func setup() {
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
        folderStore.refresh();
//        let panel = NSOpenPanel()
//        panel.allowsMultipleSelection = true
//        panel.allowedContentTypes = [.folder]
//        panel.canChooseDirectories = true
//        if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
//            let path = FileManager.default.string(withFileSystemRepresentation: home, length: strlen(home))
//            panel.directoryURL = URL(fileURLWithPath: path)
//        } else {
//            panel.directoryURL = URL(fileURLWithPath: "/Users")
//        }
//        let tempstr = panel.directoryURL?.path() ?? "no path"
//        logger.warning("choosePermissionFolder:\(tempstr)")
//        if panel.runModal() == .OK {
//            folderStore.appendItems(panel.urls.map { BookmarkFolderItem($0) })
//            send(name: "AppRefreshFolderItems", data: nil)
//        }
    }
    
    @MainActor @objc func refreshMenuItems(_ notification: Notification) {
        logger.notice("Refresh menu items")
        menuStore.refresh()
    }
    
    @MainActor @objc func refreshFolderItems(_ notification: Notification) {
        logger.notice("Refresh folder items")
        folderStore.refresh()
    }

    private var mainAppBundleID: String {
        guard var bundleID = Bundle.main.bundleIdentifier,
              let index = bundleID.lastIndex(of: ".")
        else { return "" }
        bundleID.removeSubrange(index ..< bundleID.endIndex)
        return bundleID
    }
}
