//
//  Messager.swift
//  RClick
//
//  Created by 李旭 on 2024/4/9.
//

import AppKit
import Foundation
import ScriptingBridge

enum ActionType: String {
    case open
    case create
    case copy
    case delete
}

struct MessagePayload: Codable {
    var action: String = ""
    var target: [String] = []
    var rid: String = ""
    // ctx-items ctx-container ctx-sidebar toolbar
    var trigger: String = "" // 改为可选类型，避免解码失败

    public var description: String {
        return "MessagePayload(action: \(action), target: \(target), rid:\(rid), trigger: \(trigger))"
    }
}

class Messager {
    static let shared = Messager()

    @AppLog(category: "messager")
    private var logger

    let center: DistributedNotificationCenter = .default()
    var bus: [String: (_ payload: MessagePayload) -> Void] = [:]

    func sendMessage(name: String, data: MessagePayload) {
        let message: String = createMessageData(messsagePayload: data)
        logger.warning("start sendMessage ... to \(name)")
        center.postNotificationName(NSNotification.Name(name), object: message, userInfo: nil, deliverImmediately: true)
    }

    func createMessageData(messsagePayload: MessagePayload) -> String {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(messsagePayload)
        let messsagePayloadString = String(data: data, encoding: .utf8)!

        return messsagePayloadString
    }

    func reconstructEntry(messagePayload: String) -> MessagePayload {
        let jsonData = messagePayload.data(using: .utf8)!
        do {
            let messsagePayloadCacheEntry = try JSONDecoder().decode(MessagePayload.self, from: jsonData)
            return messsagePayloadCacheEntry
        } catch {
            logger.warning("Failed to decode MessagePayload: \(error)， jsondata:\(jsonData)")
            return MessagePayload() // Return a default instance to handle errors gracefully
        }
    }


    func on(name: String, handler: @escaping (MessagePayload) -> Void) {
        center.addObserver(self, selector: #selector(recievedMessage(_:)), name: NSNotification.Name(name), object: nil)
        bus.updateValue(handler, forKey: name)
    }

    @objc func recievedMessage(_ notification: NSNotification) {
        let payload = reconstructEntry(messagePayload: notification.object as! String)
        if let handler = bus[notification.name.rawValue] {
            handler(payload)
        } else {
            logger.warning("there no handler\(notification.name.rawValue)")
        }
    }
}
