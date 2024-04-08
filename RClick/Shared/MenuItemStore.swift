//
//  MenuItemStore.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import Foundation



import OrderedCollections
import SwiftUI

@Observable
class MenuItemStore {
    var appItems: [AppMenuItem] = []
    var actionItems: [ActionMenuItem] = []

    // MARK: - Init

    nonisolated init() {
        Task {
            await MainActor.run {
                try? load()
            }
        }
    }

    func refresh() {
        try? load()
    }

    // MARK: - Append Item

    func appendItems(_ items: [AppMenuItem]) {
        appItems.append(contentsOf: items.filter { !appItems.contains($0) })
        try? save()
    }

    func appendItems(_ items: [ActionMenuItem]) {
        actionItems.append(contentsOf: items.filter { !actionItems.contains($0) })
        try? save()
    }

    func insertItems(_ items: [AppMenuItem], at index: Int) {
        appItems.insert(contentsOf: items.filter { !appItems.contains($0) }, at: index)
        try? save()
    }

    func insertItems(_ items: [ActionMenuItem], at index: Int) {
        actionItems.insert(contentsOf: items.filter { !actionItems.contains($0) }, at: index)
        try? save()
    }

    func appendItem(_ item: AppMenuItem) {
        if !appItems.contains(item) {
            appItems.append(item)
            try? save()
        }
    }

    func appendItem(_ item: ActionMenuItem) {
        if !actionItems.contains(item) {
            actionItems.append(item)
            try? save()
        }
    }

    // MARK: - Delete Items

    func deleteAppItems(offsets: IndexSet) {
        withAnimation {
            appItems.remove(atOffsets: offsets)
        }
        try? save()
    }

    func deleteActionItems(offsets: IndexSet) {
        withAnimation {
            actionItems.remove(atOffsets: offsets)
        }
        try? save()
    }

    func resetActionItems() {
        actionItems = ActionMenuItem.all
        try? save()
    }

    // MARK: - Move Items

    func moveAppItems(from source: IndexSet, to destination: Int) {
        withAnimation {
            appItems.move(fromOffsets: source, toOffset: destination)
        }
        try? save()
    }

    func moveActionItems(from source: IndexSet, to destination: Int) {
        withAnimation {
            actionItems.move(fromOffsets: source, toOffset: destination)
        }
        try? save()
    }

    // MARK: - Get Item

    func getAppItem(name: String) -> AppMenuItem? {
        appItems.first { name.contains($0.name) }
    }

    func getActionItem(name: String) -> ActionMenuItem? {
        actionItems.first { $0.name == name }
    }

    // MARK: - Update Item

    func updateAppItem(item: AppMenuItem, index: Int?) {
        if let index = index {
            appItems[index] = item
        } else {
            appItems.append(item)
        }
        try? save()
    }

    // MARK: - UserDefaults

    private func load() throws {
        if let appItemData = UserDefaults.group.data(forKey: "APP_ITEMS"),
           let actionItemData = UserDefaults.group.data(forKey: "ACTION_ITEMS") {
            let decoder = PropertyListDecoder()
            appItems = try decoder.decode([AppMenuItem].self, from: appItemData)
            actionItems = try decoder.decode([ActionMenuItem].self, from: actionItemData)
        } else {
            appItems = AppMenuItem.defaultApps
            actionItems = ActionMenuItem.all
        }
    }

    private func save() throws {
        let encoder = PropertyListEncoder()
        let appItemsData = try encoder.encode(OrderedSet(appItems))
        let actionItemsData = try encoder.encode(OrderedSet(actionItems))
        UserDefaults.group.set(appItemsData, forKey: "APP_ITEMS")
        UserDefaults.group.set(actionItemsData, forKey: "ACTION_ITEMS")
        channel.send(name: "RefreshMenuItems")
    }
}

extension UserDefaults {
    static var group: UserDefaults {
        #if DEBUG
        UserDefaults(suiteName: "group.cn.wflixu.RClickDebug")!
        #else
        UserDefaults(suiteName: "group.cn.wflixu.RClick")!
        #endif
    }
}
