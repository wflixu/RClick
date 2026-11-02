import Foundation

/// A liveness cache; receiving a heartbeat must not invalidate a live peer.
nonisolated struct PeerActivity {
    private var lastActivity = Date.distantPast
    static let timeout: TimeInterval = 30

    func isActive(now: Date = Date()) -> Bool {
        now.timeIntervalSince(lastActivity) < Self.timeout
    }

    /// Returns true only when this message reconnects an offline peer.
    mutating func receive(now: Date = Date()) -> Bool {
        let reconnected = !isActive(now: now)
        lastActivity = now
        return reconnected
    }

    mutating func disconnect() {
        lastActivity = .distantPast
    }
}
