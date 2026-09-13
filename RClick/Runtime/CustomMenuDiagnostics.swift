//
//  CustomMenuDiagnostics.swift
//  RClick
//
//  把自定义菜单的加载失败翻译成用户能据以行动的一句话。
//

import Foundation

/// Turns custom menu load failures into something the user can act on.
///
/// Only the wrapper sentences are localized. The parts that carry the actual
/// diagnosis - a JSON position, or the reference that failed to match - are
/// appended verbatim: they are the precise bit, and they are also what the
/// "hand the file to an assistant" workflow in examples/README.md relies on.
enum CustomMenuDiagnostics {

    /// `DecodingError.Context.underlyingError` stores the JSON parser's line and
    /// column readout under this key. There is no Swift constant for it.
    private static let debugDescriptionKey = "NSDebugDescription"

    static func message(for error: any Error) -> String {
        switch error {
        case let error as CustomMenuError:
            // Already a full, specific sentence from the layout validator.
            return error.description
        case let error as DecodingError:
            return decodingMessage(for: error)
        default:
            // CocoaError and friends: the system already produces a localized,
            // accurate sentence ("...you don't have permission to view it."),
            // which beats anything we would hand-write here.
            return error.localizedDescription
        }
    }

    // MARK: - Decoding failures

    private static func decodingMessage(for error: DecodingError) -> String {
        switch error {
        case let .keyNotFound(key, context):
            return located(context) + AppLocalization.localized("Missing required field") + " \"\(key.stringValue)\""
        case let .typeMismatch(_, context), let .valueNotFound(_, context):
            return located(context) + AppLocalization.localized("Invalid value") + ": " + context.debugDescription
        case let .dataCorrupted(context):
            // A malformed document has no coding path; the parser's line/column
            // lives in the underlying error instead.
            guard !context.codingPath.isEmpty else { return syntaxMessage(context) }
            return located(context) + AppLocalization.localized("Invalid value") + ": " + context.debugDescription
        @unknown default:
            return AppLocalization.localized("The JSON file is malformed.")
        }
    }

    private static func syntaxMessage(_ context: DecodingError.Context) -> String {
        let base = AppLocalization.localized("The JSON file is malformed.")
        guard let nsError = context.underlyingError as? NSError,
              let detail = nsError.userInfo[debugDescriptionKey] as? String
        else { return base }
        // Already reads "around line 5, column 3" and is localized by the system.
        return base + " " + detail
    }

    /// Renders a coding path as a 1-based menu item path.
    ///
    /// JSONDecoder only emits integer keys for array positions, so `intValue`
    /// reliably identifies the element index and everything else is a field name.
    /// `[Index 1, "title"]` becomes `[2] title `, `[Index 1, Index 0]` becomes `[2.1]`.
    private static func located(_ context: DecodingError.Context) -> String {
        var indices: [Int] = []
        var field: String?
        for key in context.codingPath {
            if let index = key.intValue { indices.append(index + 1) } else { field = key.stringValue }
        }
        guard !indices.isEmpty else {
            return field.map { "\"\($0)\" " } ?? ""
        }
        return "[" + indices.map(String.init).joined(separator: ".") + "]" + (field.map { " \($0) " } ?? " ")
    }
}
