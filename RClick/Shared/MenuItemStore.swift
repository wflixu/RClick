//
//  MenuItemStore.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import Foundation

import os.log

import OrderedCollections
import SwiftUI

private let logger = Logger(subsystem: subsystem, category: "menu_item_store")

@Observable
class MenuItemStore {
    var appItems: [AppMenuItem] = []
    var actionItems: [ActionMenuItem] = []

    var filetypeItems: [FiletypeMenuItem] = []

    // MARK: - Init

    init() {
        Task {
            await MainActor.run {
                try? load()
            }
        }
    }

    @MainActor func refresh() {
        try? load()
    }

    // MARK: - Append Item

    @MainActor func appendItems(_ items: [AppMenuItem]) {
        appItems.append(contentsOf: items.filter { !appItems.contains($0) })
        try? save()
    }

    @MainActor func appendItems(_ items: [ActionMenuItem]) {
        actionItems.append(contentsOf: items.filter { !actionItems.contains($0) })
        try? save()
    }

    @MainActor func insertItems(_ items: [AppMenuItem], at index: Int) {
        appItems.insert(contentsOf: items.filter { !appItems.contains($0) }, at: index)
        try? save()
    }

    @MainActor func insertItems(_ items: [ActionMenuItem], at index: Int) {
        actionItems.insert(contentsOf: items.filter { !actionItems.contains($0) }, at: index)
        try? save()
    }

    @MainActor func appendItem(_ item: AppMenuItem) {
        if !appItems.contains(item) {
            appItems.append(item)
            try? save()
        }
    }

    @MainActor func appendItem(_ item: ActionMenuItem) {
        if !actionItems.contains(item) {
            actionItems.append(item)
            try? save()
        }
    }

    // MARK: - Delete Items

    @MainActor func deleteAppItems(offsets: IndexSet) {
        withAnimation {
            appItems.remove(atOffsets: offsets)
        }
        try? save()
    }

    @MainActor func deleteActionItems(offsets: IndexSet) {
        withAnimation {
            actionItems.remove(atOffsets: offsets)
        }
        try? save()
    }

    @MainActor func toggleActionItem() {
        try? save()
    }

    @MainActor func resetActionItems() {
        actionItems = ActionMenuItem.all
        try? save()
    }

    @MainActor func resetFiletypeItems() {
        filetypeItems = FiletypeMenuItem.all
        try? save()
    }

    // MARK: - Move Items

    @MainActor func moveAppItems(from source: IndexSet, to destination: Int) {
        withAnimation {
            appItems.move(fromOffsets: source, toOffset: destination)
        }
        try? save()
    }

    @MainActor func moveActionItems(from source: IndexSet, to destination: Int) {
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
        actionItems.first { String(localized: String.LocalizationValue($0.key)) == name }
    }

    func getFileCreateItem(name: String) -> FiletypeMenuItem? {
        filetypeItems.first { $0.name == name }
    }

    // MARK: - Update Item

    @MainActor func updateAppItem(item: AppMenuItem, index: Int?) {
        if let index = index {
            appItems[index] = item
        } else {
            appItems.append(item)
        }
        try? save()
    }

    // MARK: - UserDefaults

    private func load() throws {
        let decoder = PropertyListDecoder()
        if let appItemData = UserDefaults.group.data(forKey: "APP_ITEMS"),
           let actionItemData = UserDefaults.group.data(forKey: "ACTION_ITEMS")
        {
            appItems = try decoder.decode([AppMenuItem].self, from: appItemData)
            actionItems = try decoder.decode([ActionMenuItem].self, from: actionItemData)
            
            

        } else {
            logger.info("using default menuitemsstore")
            appItems = AppMenuItem.defaultApps
            actionItems = ActionMenuItem.all
        }

        if let filetypeItemData = UserDefaults.group.data(forKey: "FILETYPE_ITEMS") {
            filetypeItems = try decoder.decode([FiletypeMenuItem].self, from: filetypeItemData)
        } else {
            filetypeItems = FiletypeMenuItem.all
        }
    }

    @MainActor
    private func save() throws {
        let encoder = PropertyListEncoder()
        let appItemsData = try encoder.encode(OrderedSet(appItems))
        let actionItemsData = try encoder.encode(OrderedSet(actionItems))
        let filetypeItemsData = try encoder.encode(OrderedSet(filetypeItems))
        UserDefaults.group.set(appItemsData, forKey: "APP_ITEMS")
        UserDefaults.group.set(actionItemsData, forKey: "ACTION_ITEMS")
        UserDefaults.group.set(filetypeItemsData, forKey: "FILETYPE_ITEMS")
        refresh()
    }
}
