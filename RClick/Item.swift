//
//  Item.swift
//  RClick
//
//  Created by luke on 2026/4/6.
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
