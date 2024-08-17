//
//  MenuItem.swift
//  RClick
//
//  Created by 李旭 on 2024/4/7.
//

import Foundation



protocol MenuItem: Hashable, Identifiable, Codable {
    var name: String { get }
}

extension MenuItem {
    var id: String { name }
}

