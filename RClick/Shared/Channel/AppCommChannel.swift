//
//  AppCommChannel.swift
//  RClick
//
//  Created by 李旭 on 2024/4/5.
//

import Foundation

import os.log
import SwiftUI

private let logger = Logger(subsystem: subsystem, category: "app_comm_channel")

//
//private struct MyEnvironmentKey: EnvironmentKey {
//    static let defaultValue: String = "Default value"
//}
//
//
//extension EnvironmentValues {
//    var myCustomValue: String {
//        get { self[MyEnvironmentKey.self] }
//        set { self[MyEnvironmentKey.self] = newValue }
//    }
//}
//
//
//extension View {
//    func myCustomValue(_ myCustomValue: String) -> some View {
//        environment(\.myCustomValue, myCustomValue)
//    }
//}

actor AppCommChannel {
    weak var folderItemStore: FolderItemStore?
    func setup(store: FolderItemStore) {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(refreshFolderItems(_:)), name: .init(rawValue: "RefreshFolderItems"), object: bundleIdentifier)
        folderItemStore = store
    }

    nonisolated func send(name: String, data: [AnyHashable: Any]? = nil) {
        logger.notice("appchannel Sending \(name) data: \(data ?? [:])")
        DistributedNotificationCenter.default()
            .postNotificationName(.init(rawValue: name),
                                  object: bundleIdentifier,
                                  userInfo: data,
                                  deliverImmediately: true)
    }

    @MainActor @objc func refreshFolderItems(_ notification: Notification) {
        logger.notice("Refresh folder items")
        Task {
            await folderItemStore?.refresh()
        }
    }
}

