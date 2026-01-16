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

// MARK: - Icon Cache Manager

@MainActor
class IconCacheManager: ObservableObject {
    static let shared = IconCacheManager()

    // Memory cache: URL -> NSImage
    private var memoryCache: [String: NSImage] = [:]

    // Icon size for caching (standard 32x32 for menu items)
    private let iconSize = CGSize(width: 32, height: 32)

    @AppLog(category: "IconCache")
    private var logger

    private init() {}

    /// Get icon with caching
    /// - Parameter url: The file URL to get icon for
    /// - Returns: Cached or newly loaded icon
    func icon(for url: URL) -> NSImage {
        let cacheKey = url.path

        // Check memory cache first
        if let cached = memoryCache[cacheKey] {
            logger.debug("Icon cache hit for: \(url.path)")
            return cached
        }

        // Load icon
        logger.debug("Icon cache miss, loading: \(url.path)")
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = iconSize

        // Store in memory cache
        memoryCache[cacheKey] = icon

        return icon
    }

    /// Clear memory cache (call on memory warning)
    func clearMemoryCache() {
        logger.info("Clearing icon cache, \(self.memoryCache.count) items removed")
        self.memoryCache.removeAll()
    }

    /// Preload icons for array of URLs
    /// - Parameter urls: Array of URLs to preload icons for
    func preloadIcons(for urls: [URL]) {
        logger.info("Preloading \(urls.count) icons...")
        for url in urls {
            _ = icon(for: url)
        }
        logger.info("Icon preloading complete, cache size: \(self.memoryCache.count)")
    }

    /// Get current cache size
    var cacheSize: Int {
        memoryCache.count
    }
}
