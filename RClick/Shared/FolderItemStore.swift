//
//  FolderItemStore.swift
//  RClick
//
//  Created by 李旭 on 2024/4/5.
//

import Foundation

import FinderSync
import Observation
import OrderedCollections
import os.log
import SwiftUI

private let logger = Logger(subsystem: subsystem, category: "folder_item_store")

@Observable
final class FolderItemStore {
    private(set) var bookmarkItems: [BookmarkFolderItem] = []

    // MARK: - Init

    init() {
        Task {
            await MainActor.run {
                try? load()
            }
        }
    }

    @MainActor func refresh() {
        _ = try? load()
    }

    @MainActor func isEmpty() -> Bool {
        return bookmarkItems.isEmpty
    }

    @MainActor func appendItems(_ items: [BookmarkFolderItem]) {
        bookmarkItems.append(contentsOf: items.filter { !bookmarkItems.contains($0) })
        try? save()
    }

    @MainActor func insertItems(_ items: [BookmarkFolderItem], at index: Int) {
        bookmarkItems.insert(contentsOf: items.filter { !bookmarkItems.contains($0) }, at: index)
        try? save()
    }

    @MainActor func appendItem(_ item: BookmarkFolderItem) {
        if !bookmarkItems.contains(item) {
            bookmarkItems.append(item)
        } else {}
        try? save()
    }

    @MainActor func hasParentBookmark(of url: URL) -> Bool {
        let storedUrls = bookmarkItems.map({$0.url})
        for storedURL in  storedUrls {
            // 确保 storedURL 是一个目录，并且传入的 URL 以 storedURL 的路径为前缀
            if url.path.hasPrefix(storedURL.path) {
                return true
            }
        }
        return false
    }

    // MARK: - Delete Items

    @MainActor func deleteBookmarkItems(offsets: IndexSet) {
        withAnimation {
            bookmarkItems.remove(atOffsets: offsets)
        }
        try? save()
    }

    @MainActor func deleteBookmarkItem(index: Int) {
        bookmarkItems.remove(at: index)

        try? save()
    }

    func deleteAllBookmarkItems() {
        withAnimation {
            bookmarkItems.removeAll()
        }
        Task.detached {
            try await self.save()
        }
    }

    // MARK: - UserDefaults

    @MainActor
    private func load() throws {
        if let bookmarkItemData = UserDefaults.group.data(forKey: "BOOKMARK_ITEMS") {
            let decoder = PropertyListDecoder()
            bookmarkItems = try decoder.decode([BookmarkFolderItem].self, from: bookmarkItemData)
           
            let urls = Set(bookmarkItems.map { bkm in
                bkm.url
            })
            FIFinderSyncController.default().directoryURLs = urls
        } else {
            logger.error("fail load bookmarkData")
        }
    }

    @MainActor func getBookmarkItems() throws -> [URL] {
        if let bookmarkItemData = UserDefaults.group.data(forKey: "BOOKMARK_ITEMS") {
            let decoder = PropertyListDecoder()
            bookmarkItems = try decoder.decode([BookmarkFolderItem].self, from: bookmarkItemData)
        }
        return bookmarkItems.map { $0.url }
    }

    @MainActor
    private func save() throws {
        let encoder = PropertyListEncoder()
        let bookmarkItemData = try encoder.encode(OrderedSet(bookmarkItems))
        UserDefaults.group.set(bookmarkItemData, forKey: "BOOKMARK_ITEMS")
        UserDefaults.group.synchronize()
        refresh()
    }
}
