//
//  BookmarkFolderItem.swift
//  RClick
//
//  Created by 李旭 on 2024/4/5.
//

import Foundation


import AppKit
import Foundation
import os.log




protocol FolderItem: Hashable, Identifiable, Codable {
    var path: String { get }
}

extension FolderItem {
    var id: String { path }
}


private let logger = Logger(subsystem: subsystem, category: "folder_item")

struct BookmarkFolderItem: FolderItem {
    var url: URL
    var bookmark: Data

    var path: String { url.path }

    init(_ url: URL) {
        self.url = url
        let result = url.startAccessingSecurityScopedResource()
        if !result {
            logger.error("Fail to start access security scoped resource on \(url.path)")
        }
        do {
            bookmark = try url.bookmarkData(options: .withSecurityScope)
            url.stopAccessingSecurityScopedResource()
        } catch {
            print(error.localizedDescription)
            fatalError()
        }
    }

    enum CodingKeys: String, CodingKey {
        case url, bookmark
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        bookmark = try values.decode(Data.self, forKey: .bookmark)
        var isStale = false
        do {
            url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            let result = url.startAccessingSecurityScopedResource()
            let path = url.path
            if !result {
                logger.error("Fail to start access security scoped resource on \(path)")
            }
        } catch {
            // Show for the main app
            url = try values.decode(URL.self, forKey: .url)
        }
        print(url.path)
    }
}

