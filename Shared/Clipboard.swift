import AppKit

/// 剪贴板写入。App 与 Finder Sync 扩展共用，保证在线/离线两条路径语义一致。
enum Clipboard {
    /// 复制多个路径：一行一个，同时写入文件 URL，粘到 Finder 里可以直接得到这些文件。
    ///
    /// 只有第一个 pasteboard item 带 `.string`（整段多行文本）。文本编辑器读取的是
    /// first item 的字符串；如果每个 item 都带文本，部分应用会把内容重复粘贴。
    nonisolated static func copyPaths(_ paths: [String], to pasteboard: NSPasteboard = .general) {
        guard !paths.isEmpty else { return }
        let decoded = paths.map { $0.removingPercentEncoding ?? $0 }
        let text = decoded.joined(separator: "\n")

        let items = decoded.enumerated().map { index, path -> NSPasteboardItem in
            let item = NSPasteboardItem()
            item.setString(URL(fileURLWithPath: path).absoluteString, forType: .fileURL)
            if index == 0 {
                item.setString(text, forType: .string)
            }
            return item
        }

        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }

    /// 复制多个文件名（不含路径），一行一个。只写文本——写成文件 URL 会让
    /// 粘到 Finder 的行为变成复制文件，与「复制文件名」的语义不符。
    nonisolated static func copyFileNames(_ paths: [String], to pasteboard: NSPasteboard = .general) {
        let names = paths
            .map { URL(fileURLWithPath: $0.removingPercentEncoding ?? $0).lastPathComponent }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else { return }

        pasteboard.clearContents()
        pasteboard.setString(names.joined(separator: "\n"), forType: .string)
    }
}
