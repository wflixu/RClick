//
//  DeleteConfirmation.swift
//  RClick
//
//  Permanent-delete confirmation UI, injected into ActionService so tests can
//  assert confirm/cancel without opening a modal.
//

import AppKit
import Foundation

/// Confirms permanent (non-Trash) deletes. Injected so tests can mock the alert.
@MainActor
protocol DeleteConfirmationProviding: AnyObject {
    func confirmPermanentDelete(paths: [String]) -> Bool
}

@MainActor
final class AlertDeleteConfirmation: DeleteConfirmationProviding {
    private let previewLimit = 5

    func confirmPermanentDelete(paths: [String]) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppLocalization.localized("Delete"))
        alert.addButton(withTitle: AppLocalization.localized("Cancel"))
        alert.buttons[0].hasDestructiveAction = true

        let names = paths.map { URL(fileURLWithPath: $0).lastPathComponent }
        let irreversible = AppLocalization.localized("This cannot be undone and will not move items to Trash.")

        if names.count == 1 {
            alert.messageText = String(format: AppLocalization.localized("Permanently delete “%@”?"), names[0])
            alert.informativeText = irreversible
        } else {
            alert.messageText = String(format: AppLocalization.localized("Permanently delete %lld items?"), Int64(names.count))
            var listed = names.prefix(previewLimit).joined(separator: "\n")
            let remainder = names.count - previewLimit
            if remainder > 0 { listed += "\n" + String(format: AppLocalization.localized("...and %lld more"), Int64(remainder)) }
            alert.informativeText = listed + "\n\n" + irreversible
        }
        return alert.runModal() == .alertFirstButtonReturn
    }
}
