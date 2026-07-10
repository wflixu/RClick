//
//  RClickTests.swift
//  RClickTests
//
//  Created by luke on 2026/4/6.
//

import Testing
@testable import RClick

struct RClickTests {
    private struct TestPayload: Codable {
        let values: [String: Int]
    }

    @Test @MainActor func signedPayloadAcceptsUntamperedContent() throws {
        let signed = try MessageSecurity.sign(TestPayload(values: ["alpha": 1, "beta": 2]))
        #expect(MessageSecurity.verify(signed))
    }

    @Test @MainActor func signedPayloadRejectsReplacedContent() throws {
        let signed = try MessageSecurity.sign(TestPayload(values: ["safe": 1]))
        let tampered = SignedPayload(
            payload: TestPayload(values: ["delete": 1]),
            signature: signed.signature,
            jsonData: signed.jsonData
        )
        #expect(!MessageSecurity.verify(tampered))
    }

    @Test @MainActor func newFileMenuIncludesBlankFileAndEnabledTypesOnly() {
        let enabled = NewFile(ext: ".txt", name: "Text", enabled: true, idx: 0, id: "enabled")
        let disabled = NewFile(ext: ".md", name: "Markdown", enabled: false, idx: 1, id: "disabled")

        let items = NewFileMenuItem.configuredItems(from: [enabled, disabled])

        #expect(items.map(\.id) == [NewFileMenuItem.customFileId, "enabled"])
    }
}
