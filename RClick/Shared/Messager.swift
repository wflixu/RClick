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
    var target: String = ""
    var app: String = ""
}

import os.log

private let logger = Logger(subsystem: subsystem, category: "messager")

class Messager {
    let center: DistributedNotificationCenter = .default()
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

    @objc func recievedMessage(_ notification: NSNotification) {
        NSLog("Message Received from Application \(notification.name)")

        if notification.name.rawValue == Key.messageFromFinder {
            NSLog("Message Recieved from Application to set the sync icon")

            let mp = reconstructEntry(messagePayload: notification.object as! String)
            NSLog("Message Recieved from name:\(mp.target) path:\(mp.app)")
            switch mp.action {
                case "open":
                    openApp(app: mp.app, target: mp.target)
                case "Delete Direct":
                    deleteFoldorFile(mp.target)
                case "Copy Path":
                    copyPath(mp.target)
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
        logger.warning("startig copy path ... \(target)")
        let pasteboard = NSPasteboard.general
        // must do to fix bug
        pasteboard.clearContents()
        let res =  pasteboard.setString(target, forType: .string)
    }

    func deleteFoldorFile(_ target: String) {
        let fm = FileManager.default
        do {
            try fm.removeItem(atPath: target)
        } catch {
            logger.error("delete \(target) file run error \(error)")
        }
    }
}
