import Foundation
import Testing
@testable import RClick

struct PeerActivityTests {
    @Test func heartbeatsStayOnlineAcrossMonitorIntervalsAndReconnectAfterTimeout() {
        var peer = PeerActivity()
        let start = Date(timeIntervalSince1970: 1000)
        #expect(!peer.isActive(now: start))
        let firstConnection = peer.receive(now: start)
        #expect(firstConnection)
        for seconds in stride(from: 10, through: 90, by: 10) {
            let now = start.addingTimeInterval(Double(seconds))
            #expect(peer.isActive(now: now))
            let reconnected = peer.receive(now: now)
            #expect(!reconnected)
        }
        #expect(!peer.isActive(now: start.addingTimeInterval(120)))
        let reconnected = peer.receive(now: start.addingTimeInterval(121))
        #expect(reconnected)
        peer.disconnect()
        #expect(!peer.isActive(now: start.addingTimeInterval(122)))
    }
}
