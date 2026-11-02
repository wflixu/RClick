import Foundation
import Testing
import SwiftData
@testable import RClick

@MainActor
struct MenuCompatibilityTests {
    @Test func oldAppPayloadKeepsBothMenusVisible() throws {
        let json = #"{"id":"terminal","name":"Terminal","icon":"terminal","tag":0,"appURL":"/Applications/Terminal.app"}"#
        let app = try JSONDecoder().decode(AppMenuItem.self, from: Data(json.utf8))
        #expect(app.showInToolbar)
        #expect(app.showInContextMenu)
        #expect(!app.opensNewInstance)
        #expect(app.opensContainingDir == nil)
    }

    @Test(arguments: [nil, true, false] as [Bool?])
    func appOptionsSurvivePersistenceAndIPC(explicit: Bool?) throws {
        let container = try SwiftData.ModelContainer(
            for: AppEntity.self,
            configurations: SwiftData.ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        var app = OpenWithApp(appURL: URL(fileURLWithPath: "/Applications/Terminal.app"))
        app.opensContainingDir = explicit
        app.showInToolbar = false
        app.showInContextMenu = true
        app.opensNewInstance = true
        context.insert(AppEntity(from: app))
        try context.save()
        let entity = try #require(context.fetch(SwiftData.FetchDescriptor<AppEntity>()).first)
        #expect(entity.opensContainingDir == explicit)
        #expect(!entity.showInToolbar)
        #expect(entity.showInContextMenu)
        let data = try JSONEncoder().encode(app.toAppMenuItem())
        let decoded = try JSONDecoder().decode(AppMenuItem.self, from: data)
        #expect(decoded.opensContainingDir == explicit)
        #expect(!decoded.showInToolbar)
        #expect(decoded.showInContextMenu)
        #expect(decoded.opensNewInstance)
        #expect(!decoded.isVisible(for: .toolbar))
        #expect(decoded.isVisible(for: .contextualItems))
        #expect(decoded.isVisible(for: .contextualContainer))
        #expect(decoded.isVisible(for: .contextualSidebar))
    }

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
