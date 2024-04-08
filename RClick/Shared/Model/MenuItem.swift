//
//  MenuItem.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import Foundation

import AppKit

protocol MenuItem: Hashable, Identifiable, Codable {
    var name: String { get }
    var enabled: Bool { get set }
    var icon: NSImage { get }
}

extension MenuItem {
    var id: String { name }
}

