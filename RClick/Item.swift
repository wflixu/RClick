//
//  Item.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
