//
//  Messager.swift
//  RClick
//
//  Created by 李旭 on 2024/4/9.
//

import AppKit
import Foundation

enum ActionType: String {
    case open
    case create
    case copy
    case delete
}

struct MessagePayload: Codable {
    var action: String = ""
    var target: [String] = []
    var app: String = ""

    public var description: String {
        return "MessagePayload(action: \(action), target: \(target), app:\(app) )"
    }
}

import os.log

private let logger = Logger(subsystem: subsystem, category: "messager")

class Messager {
    static let shared = Messager()

    let center: DistributedNotificationCenter = .default()
    var bus: [String: (_ payload: MessagePayload) -> Void] = [:]

    func sendMessage(name: String, data: MessagePayload) {
        let message: String = createMessageData(messsagePayload: data)
        center.postNotificationName(NSNotification.Name(name), object: message, userInfo: nil, deliverImmediately: true)
    }

    func createMessageData(messsagePayload: MessagePayload) -> String {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(messsagePayload)
        let messsagePayloadString = String(data: data, encoding: .utf8)!

        return String(messsagePayloadString)
    }

    func reconstructEntry(messagePayload: String) -> MessagePayload {
        let jsonData = messagePayload.data(using: .utf8)!
        let messsagePayloadCacheEntry = try! JSONDecoder().decode(MessagePayload.self, from: jsonData)

        return messsagePayloadCacheEntry
    }

    func start(name: String) {
        center.addObserver(self, selector: #selector(recievedMessage(_:)), name: NSNotification.Name(name), object: nil)
    }

    func on(name: String, handler: @escaping (MessagePayload) -> Void) {
        center.addObserver(self, selector: #selector(recievedMessage(_:)), name: NSNotification.Name(name), object: nil)
        bus.updateValue(handler, forKey: name)
    }

    @objc func recievedMessage(_ notification: NSNotification) {
        logger.warning("Message Received from Application \(notification.name.rawValue)")
        if let handler = bus[notification.name.rawValue] {
            handler(reconstructEntry(messagePayload: notification.object as! String))
        } else {
            logger.warning("there no handler")
        }
        if notification.name.rawValue == Key.messageFromFinder {
            NSLog("Message Recieved from Application to set the sync icon")

            let mp = reconstructEntry(messagePayload: notification.object as! String)
            NSLog("Message Recieved from name:\(mp.target) path:\(mp.app)")
            switch mp.action {
                case "open":
                    openApp(app: mp.app, target: mp.target.first!)
                case "Delete Direct":
                    deleteFoldorFile(mp.target)
                case "Copy Path":
                    copyPath(mp.target.first!)
                default:
                    print("no switch")
            }
        }
    }

    func openApp(app: String, target: String) {
        let file = URL(fileURLWithPath: target, isDirectory: true)
        let appUrl = URL(fileURLWithPath: app)
        let config = NSWorkspace.OpenConfiguration()
        config.promptsUserIfNeeded = true
        NSWorkspace.shared.open([file], withApplicationAt: appUrl, configuration: config)
    }

    func copyPath(_ target: String) {
        let pasteboard = NSPasteboard.general
        // must do to fix bug
        pasteboard.clearContents()
        pasteboard.setString(target, forType: .string)
    }

    func deleteFoldorFile(_ target: [String]) {
        let fm = FileManager.default
        do {
            for item in target {
                try fm.removeItem(atPath: item)
            }
        } catch {
            logger.error("delete \(target) file run error \(error)")
        }
    }
}
