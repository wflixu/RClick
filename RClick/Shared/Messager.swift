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
    var ext: String = ""

    public var description: String {
        return "MessagePayload(action: \(action), target: \(target), app:\(app) )"
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
        if let handler = bus[notification.name.rawValue] {
            handler(reconstructEntry(messagePayload: notification.object as! String))
        } else {
            logger.warning("there no handler")
        }
        if notification.name.rawValue == Key.messageFromFinder {
            let mp = reconstructEntry(messagePayload: notification.object as! String)
            switch mp.action {
            case "open":
                openApp(app: mp.app, target: mp.target.first!)
            case "Delete Direct":
                deleteFoldorFile(mp.target)
            case "Copy Path":
                copyPath(mp.target.first!)
            case "Create File":
                createFile(dir: mp.target.first!, ext: mp.ext)
            default:
                print("no switch")
            }
        }
    }

    func createFile(dir: String, ext: String) {
        logger.info("create file dir:\(dir) -- ext \(ext)")
        // 完整的文件路径
        let filePath = getUniqueFilePath(dir: dir.removingPercentEncoding ?? dir, ext: ext)

        let emptyDocxData = Data()
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            try emptyDocxData.write(to: fileURL)
            print("Empty DOCX file created successfully at \(filePath)")
        } catch let error as NSError {
            switch error.domain {
            case NSCocoaErrorDomain:
                switch error.code {
                case NSFileNoSuchFileError:
                    print("Error: No such file exists at \(filePath)")
                case NSFileWriteOutOfSpaceError:
                    print("Error: Not enough disk space to write the file")
                case NSFileWriteNoPermissionError:
                    print("Error: No permission to write the file at \(filePath)")
                default:
                    print("Error: \(error.localizedDescription) (\(error.code))")
                }
            default:
                print("Unhandled error: \(error.localizedDescription) (\(error.code))")
            }
        }
    }

    // 创建一个当前文件夹下的不存在的新建文件名
    func getUniqueFilePath(dir: String, ext: String) -> String {
        // 创建文件管理器
        let fileManager = FileManager.default

        // 基础文件名
        let baseFileName = "新建文件"

        // 初始文件路径
        var filePath = "\(dir)\(baseFileName)\(ext)"

        // 文件计数器
        var counter = 1

        // 查询文件是否存在，直到找到一个不存在的路径
        while fileManager.fileExists(atPath: filePath) {
            // 更新文件名和路径，使用计数器递增
            let newFileName = "\(baseFileName)\(counter)"
            filePath = "\(dir)/\(newFileName)\(ext)"
            counter += 1
        }

        return filePath
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
