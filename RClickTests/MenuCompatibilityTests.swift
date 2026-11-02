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

    @Test(arguments: [nil, true, false] as [Bool?], [false, true])
    func appOptionsSurvivePersistenceAndIPC(explicit: Bool?, toolbarVisible: Bool) throws {
        let container = try SwiftData.ModelContainer(
            for: AppEntity.self, ActionEntity.self, NewFileTypeEntity.self, CommonDirEntity.self,
            configurations: SwiftData.ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let service = ConfigService(modelContext: ModelContext(container))
        var app = OpenWithApp(appURL: URL(fileURLWithPath: "/Applications/Terminal.app"))
        app.opensContainingDir = explicit
        app.showInToolbar = toolbarVisible
        app.showInContextMenu = !toolbarVisible
        app.opensNewInstance = true
        try service.save(AppConfigData(apps: [app]))

        // Reload through the production mapping in a fresh context, so missing
        // ConfigService.load fields cannot be hidden by the original app value.
        let restored = try #require(ConfigService(modelContext: ModelContext(container)).load().apps.first)
        #expect(restored.id == app.id)
        #expect(restored.opensContainingDir == explicit)
        #expect(restored.showInToolbar == toolbarVisible)
        #expect(restored.showInContextMenu == !toolbarVisible)
        #expect(restored.opensNewInstance)
        let data = try JSONEncoder().encode(restored.toAppMenuItem())
        let decoded = try JSONDecoder().decode(AppMenuItem.self, from: data)
        #expect(decoded.opensContainingDir == explicit)
        #expect(decoded.showInToolbar == toolbarVisible)
        #expect(decoded.showInContextMenu == !toolbarVisible)
        #expect(decoded.opensNewInstance)
        #expect(decoded.isVisible(for: .toolbar) == toolbarVisible)
        #expect(decoded.isVisible(for: .contextualItems) == !toolbarVisible)
        #expect(decoded.isVisible(for: .contextualContainer) == !toolbarVisible)
        #expect(decoded.isVisible(for: .contextualSidebar) == !toolbarVisible)
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
