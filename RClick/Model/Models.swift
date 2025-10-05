//
//  Models.swift
//  RClick
//
//  Created by 李旭 on 2025/10/3.
//

import SwiftData
import Foundation

@Model
class PermDir {
    @Attribute(.unique) var id: String
    var url: URL
    var bookmark: Data
    
    init(id: String, url: URL, bookmark: Data) {
        self.id = id
        self.url = url
        self.bookmark = bookmark
    }
}
