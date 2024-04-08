//
//  FolderItem.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import Foundation

protocol FolderItem: Hashable, Identifiable, Codable {
    var path: String { get }
}

extension FolderItem {
    var id: String { path }
}

