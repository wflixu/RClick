//
//  Dir.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import Foundation
import SwiftData


@Model
final class Dir : Identifiable {
    let path: String
    let id : UUID
//
    // 初始化方法，通常用于创建新的实例
    init(path: String) {
        id = UUID() // 每次创建新的实例时生成一个随机的UUID
        self.path = path
    }
//
//    // 初始化方法，通常用于从编码数据中解码实例
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        id = try container.decode(UUID.self, forKey: .id)
//        path = try container.decode(String.self, forKey: .path)
//    }
//
//    // 编码方法，将实例编码为数据格式
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(id, forKey: .id)
//        try container.encode(path, forKey: .path)
//    }
//
//    // 定义编码和解码时使用的键
//    private enum CodingKeys: String, CodingKey {
//        case id, path
//    }
}


struct MyDir : Codable, Identifiable {
    let path: String
    let id : UUID
//
    // 初始化方法，通常用于创建新的实例
    init(path: String) {
        id = UUID() // 每次创建新的实例时生成一个随机的UUID
        self.path = path
    }

    // 初始化方法，通常用于从编码数据中解码实例
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
    }

    // 编码方法，将实例编码为数据格式
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(path, forKey: .path)
    }

    // 定义编码和解码时使用的键
    private enum CodingKeys: String, CodingKey {
        case id, path
    }
}


extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}




