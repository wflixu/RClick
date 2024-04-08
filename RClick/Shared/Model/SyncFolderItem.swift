//
//  SyncFolderItem.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import Foundation


struct SyncFolderItem: FolderItem {
    var path: String

    init(_ url: URL) {
        path = url.path
    }
}

extension SyncFolderItem {
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
        [.home, .application].compactMap { $0 } + volumns
    }
}
