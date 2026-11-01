//
//  ActionService.swift
//  RClick
//
//  文件操作 / 动作执行服务。从原 AppDelegate 迁移而来，是主 app 的"动作执行层"。
//  依赖 AppState（只读状态）、PermissionService 与删除确认（经协议注入，可 mock 单测）。
//  注意：第一版不过度拆分，用私有方法 + MARK 分组（FileActions / AppActions / FinderActions / SystemActions）。
//

import AppKit
import ApplicationServices
import Foundation
import os.log

@MainActor
final class ActionService {
    @AppLog(category: "ActionService")
    private var logger

    private let state: ActionStateProviding
    private let permission: PermissionProviding
    private let confirmation: DeleteConfirmationProviding

    init(state: ActionStateProviding, permission: PermissionProviding, confirmation: DeleteConfirmationProviding) {
        self.state = state
        self.permission = permission
        self.confirmation = confirmation
    }

    // MARK: - SystemActions

    /// 复制路径到剪贴板
    func copyPath(_ target: [String]) {
        if let dirPath = target.first {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(dirPath.removingPercentEncoding ?? dirPath, forType: .string)
        }
    }

    // MARK: - AppActions

    /// 用指定应用打开选中文件/目录（沙盒门控：先 hasAccess，失败兜底再授权重试）
    func openApp(rid: String, target: [String]) async {
        guard let rcitem = state.getAppItem(rid: rid) else {
            logger.warning("when openapp, but not have app \(rid)")
            return
        }

        let appUrl = rcitem.url
        logger.debug("openApp: rid=\(rid) app=\(appUrl.path) target=\(target) opensNewInstance=\(rcitem.opensNewInstance)")

        for dirPath in target {
            let decodedPath = dirPath.removingPercentEncoding ?? dirPath
            let url = URL(fileURLWithPath: decodedPath)
            await openWithApp(url, appUrl: appUrl, opensNewInstance: rcitem.opensNewInstance)
        }
    }

    private func openWithApp(_ url: URL, appUrl: URL, opensNewInstance: Bool) async {
        let logger = self.logger  // 捕获 Sendable logger，供完成回调使用
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let accessURL = (exists && isDir.boolValue) ? url : url.deletingLastPathComponent()

        // 门控先行：未授权先弹窗，避免"只是打开一个文件"也要用户授权整个父目录的弹窗偏重
        if !permission.hasAccess(to: accessURL) {
            guard await permission.promptForPermission(for: accessURL) != nil else {
                logger.warning("用户取消授权，跳过打开：\(url.path)")
                return
            }
        }

        let config = NSWorkspace.OpenConfiguration()
        // 以新实例打开（浏览器类 app 会新开窗口而非新 tab）
        config.createsNewApplicationInstance = opensNewInstance
        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: config) { [weak self] runningApp, error in
            guard let self else { return }
            if let error {
                // 失败兜底：再弹授权并重试一次
                Task { @MainActor in
                    await self.openRetryAfterPermission(url: url, appUrl: appUrl, accessURL: accessURL, opensNewInstance: opensNewInstance, firstError: error)
                }
            } else if let runningApp {
                logger.debug("Successfully opened with application: \(runningApp.localizedName ?? "Unknown")")
            }
        }
    }

    private func openRetryAfterPermission(url: URL, appUrl: URL, accessURL: URL, opensNewInstance: Bool, firstError: Error) async {
        let logger = self.logger  // 捕获 Sendable logger
        guard await permission.promptForPermission(for: accessURL) != nil else {
            logger.error("打开失败且用户取消授权：\(url.path) — \(firstError.localizedDescription)")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = opensNewInstance
        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: config) { _, retryError in
            if let retryError {
                logger.error("重试打开仍失败：\(url.path) — \(retryError.localizedDescription)")
            }
        }
    }

    /// 打开常用目录（沙盒门控：目录需已授权，B4 之后添加时即存 bookmark，此处为兜底）
    func openCommonDirs(target: [String]) async {
        logger.debug("开始打开常用目录，目标路径：\(target)")

        for dirPath in target {
            let path = dirPath.removingPercentEncoding ?? dirPath
            let url = URL(fileURLWithPath: path, isDirectory: true)

            if !permission.hasAccess(to: url) {
                guard await permission.promptForPermission(for: url) != nil else {
                    logger.warning("用户取消授权，跳过打开目录：\(path)")
                    continue
                }
            }
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - FileActions

    /// 动作分发入口
    func actionHandler(rid: String, target: [String], trigger: String) async {
        guard let rcitem = state.getActionItem(rid: rid) else {
            logger.warning("when actionHandler, but not have action \(rid)")
            return
        }

        switch rcitem.id {
        case "copy-path":
            copyPath(target)
        case "delete-direct":
            await deleteFoldorFile(target, trigger)
        case "unhide":
            await unhideFilesAndDirs(target, trigger)
        case "hide":
            await hideFilesAndDirs(target, trigger)
        case "airdrop":
            await showAirDrop(target, trigger)
        default:
            logger.warning("no action id matched")
        }
    }

    func showAirDrop(_ target: [String], _ trigger: String) async {
        logger.info("---- showAirDrop trigger:\(trigger)")
        let fm = FileManager.default
        var fileURLs: [URL] = []

        if trigger == "ctx-container" {
            let alert = NSAlert()
            alert.messageText = AppLocalization.localized("Warning")
            alert.informativeText = AppLocalization.localized("The current folder cannot be shared. Please select files or subfolders instead.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: AppLocalization.localized("OK"))
            alert.runModal()
            return
        }

        for item in target {
            let decodedPath = item.removingPercentEncoding ?? item
            logger.info("airdrop path \(decodedPath)")

            if Utils.isProtectedFolder(decodedPath) {
                let alert = NSAlert()
                alert.messageText = AppLocalization.localized("Warning")
                alert.informativeText = String(format: AppLocalization.localized("Protected system folders cannot be shared: %@"), decodedPath)
                alert.alertStyle = .warning
                alert.addButton(withTitle: AppLocalization.localized("OK"))
                alert.runModal()
                logger.warning("试图分享受保护的系统文件夹，操作已被阻止：\(decodedPath)")
                continue
            }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: decodedPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    logger.warning("不能通过 AirDrop 分享文件夹：\(decodedPath)")
                    let alert = NSAlert()
                    alert.messageText = AppLocalization.localized("Notice")
                    alert.informativeText = String(format: AppLocalization.localized("Folders cannot be shared via AirDrop: %@"), decodedPath)
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: AppLocalization.localized("OK"))
                    alert.runModal()
                    continue
                } else {
                    // 确保有文件所在目录的访问权限
                    let fileURL = URL(fileURLWithPath: decodedPath)
                    let dirURL = fileURL.deletingLastPathComponent()
                    if !permission.hasAccess(to: dirURL) {
                        guard await permission.promptForPermission(for: dirURL) != nil else {
                            logger.warning("用户取消授权，跳过 AirDrop：\(decodedPath)")
                            continue
                        }
                    }
                    fileURLs.append(fileURL)
                }
            }
        }

        if !fileURLs.isEmpty {
            if let airDropService = NSSharingService(named: .sendViaAirDrop) {
                airDropService.perform(withItems: fileURLs)
                logger.info("已通过 AirDrop 分享文件：\(fileURLs.map { $0.path }.joined(separator: ", "))")
            } else {
                logger.warning("无法获取 AirDrop 服务")
            }
        }
    }

    func unhideFilesAndDirs(_ target: [String], _ trigger: String) async {
        logger.info("开始取消隐藏文件和目录，目标路径：\(target)")
        if let dirPath = target.first {
            let fileManager = FileManager.default
            let path = dirPath.removingPercentEncoding ?? dirPath
            logger.info("处理主目录：\(path)")
            let url = URL(fileURLWithPath: path)

            // 确保有目录的访问权限
            if !permission.hasAccess(to: url) {
                guard await permission.promptForPermission(for: url) != nil else {
                    logger.warning("用户取消授权，跳过取消隐藏：\(path)")
                    return
                }
            }

            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isHiddenKey], options: [.skipsPackageDescendants])
                for case var fileURL in contents {
                    do {
                        var resourceValues = URLResourceValues()
                        resourceValues.isHidden = false
                        try fileURL.setResourceValues(resourceValues)
                        logger.info("成功取消隐藏：\(fileURL.path)")
                    } catch {
                        logger.error("取消隐藏失败：\(fileURL.path): \(error)")
                    }
                }
            } catch {
                logger.error("获取目录内容失败：\(error)")
            }

            do {
                var resourceValues = URLResourceValues()
                resourceValues.isHidden = false
                var targetURL = url
                try targetURL.setResourceValues(resourceValues)
                logger.info("成功取消隐藏主目录：\(path)")
            } catch {
                logger.error("取消隐藏主目录失败：\(path): \(error)")
            }
            logger.info("取消隐藏操作完成，共处理目录：\(path)")
        }
    }

    func hideFilesAndDirs(_ target: [String], _ trigger: String) async {
        logger.info("开始隐藏文件和目录，目标路径：\(target), 触发器：\(trigger)")
        let fileManager = FileManager.default

        if trigger == "ctx-container", let dirPath = target.first {
            let path = dirPath.removingPercentEncoding ?? dirPath
            logger.info("处理主目录：\(path)")
            let url = URL(fileURLWithPath: path)

            // 确保有目录的访问权限
            if !permission.hasAccess(to: url) {
                guard await permission.promptForPermission(for: url) != nil else {
                    logger.warning("用户取消授权，跳过隐藏：\(path)")
                    return
                }
            }

            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsPackageDescendants])
                for case var fileURL in contents {
                    if Utils.isProtectedFolder(fileURL.path) {
                        logger.warning("跳过受保护的文件路径：\(fileURL.path)")
                        continue
                    }
                    do {
                        var resourceValues = URLResourceValues()
                        resourceValues.isHidden = true
                        try fileURL.setResourceValues(resourceValues)
                        logger.info("成功隐藏：\(fileURL.path)")
                    } catch {
                        logger.error("隐藏失败：\(fileURL.path): \(error)")
                    }
                }
            } catch {
                logger.error("获取目录内容失败：\(error)")
            }
        } else if trigger == "ctx-items" {
            for dirPath in target {
                let path = dirPath.removingPercentEncoding ?? dirPath
                logger.info("处理路径：\(path)")
                let url = URL(fileURLWithPath: path)

                if Utils.isProtectedFolder(path) {
                    logger.warning("跳过受保护的文件路径：\(path)")
                    continue
                }

                // 确保有文件所在目录的访问权限
                let dirURL = url.deletingLastPathComponent()
                if !permission.hasAccess(to: dirURL) {
                    guard await permission.promptForPermission(for: dirURL) != nil else {
                        logger.warning("用户取消授权，跳过隐藏：\(path)")
                        continue
                    }
                }

                do {
                    var resourceValues = URLResourceValues()
                    resourceValues.isHidden = true
                    var targetURL = url
                    try targetURL.setResourceValues(resourceValues)
                    logger.info("成功隐藏：\(path)")
                } catch {
                    logger.error("隐藏失败：\(path): \(error)")
                }
            }
        }
        logger.info("隐藏操作完成")
    }

    func deleteFoldorFile(_ target: [String], _ trigger: String) async {
        logger.info("---- deleteFoldorFile trigger:\(trigger)")
        let fm = FileManager.default

        if trigger == "ctx-container" {
            let alert = NSAlert()
            alert.messageText = AppLocalization.localized("Warning")
            alert.informativeText = AppLocalization.localized("The current folder cannot be deleted. Please select files or subfolders instead.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: AppLocalization.localized("OK"))
            alert.runModal()
            return
        }

        var pathsToDelete: [String] = []
        for item in target {
            let decodedPath = item.removingPercentEncoding ?? item

            if Utils.isProtectedFolder(decodedPath) {
                let alert = NSAlert()
                alert.messageText = AppLocalization.localized("Warning")
                alert.informativeText = String(format: AppLocalization.localized("Protected system folders cannot be deleted: %@"), decodedPath)
                alert.alertStyle = .warning
                alert.addButton(withTitle: AppLocalization.localized("OK"))
                alert.runModal()
                logger.warning("试图删除受保护的系统文件夹，操作已被阻止：\(decodedPath)")
                continue
            }

            pathsToDelete.append(decodedPath)
        }

        guard !pathsToDelete.isEmpty else { return }

        // 先把授权问完，再让确认框当最后一道关卡：确认框里的条目数就是
        // "确认后真的会被删掉的数量"，取消授权的项在确认之前就已经出局。
        // 授权由 BookmarkManager 持有到进程结束，提前检查不会失效。
        var authorized: [String] = []
        for decodedPath in pathsToDelete {
            let dirURL = URL(fileURLWithPath: decodedPath).deletingLastPathComponent()
            if !permission.hasAccess(to: dirURL) {
                guard await permission.promptForPermission(for: dirURL) != nil else {
                    logger.warning("用户取消授权，跳过删除：\(decodedPath)")
                    continue
                }
                guard permission.hasAccess(to: dirURL) else {
                    logger.warning("授权未覆盖目标目录，跳过删除：\(decodedPath)")
                    continue
                }
            }
            authorized.append(decodedPath)
        }

        guard !authorized.isEmpty else { return }

        if state.confirmBeforeDelete {
            guard confirmation.confirmPermanentDelete(paths: authorized) else {
                logger.info("用户取消了删除确认，共 \(authorized.count) 项未删除")
                return
            }
        }

        for decodedPath in authorized {
            do { try fm.removeItem(atPath: decodedPath) }
            catch { logger.error("delete \(decodedPath) file run error \(error)") }
        }
    }

    // MARK: - NewFileActions

    func createFile(rid: String, target: [String]) async {
        guard let dirPath = targetDirectoryForNewFile(target) else {
            logger.warning("when createFile, but not have target directory")
            return
        }

        let dirURL = URL(fileURLWithPath: dirPath)

        // 确保有目标目录的访问权限
        if !permission.hasAccess(to: dirURL) {
            guard await permission.promptForPermission(for: dirURL) != nil else {
                logger.warning("用户取消授权，跳过创建文件")
                return
            }
        }

        if rid == NewFileMenuItem.customFileId {
            let filePath = getUniqueFilePath(dir: dirPath, ext: "")
            let fileURL = URL(fileURLWithPath: filePath)
            do {
                try Data().write(to: fileURL)
                logger.info("created editable file: \(fileURL.path)")
                revealInFinderAndRename(fileURL)
            } catch {
                logger.error("create editable file error: \(error.localizedDescription)")
            }
            return
        }

        guard let rcitem = state.getFileType(rid: rid) else {
            logger.warning("when createFile, but not have fileType \(rid) ")
            return
        }

        let ext = rcitem.ext
        logger.info("create file dir:\(dirPath) -- ext \(ext)")
        let filePath = getUniqueFilePath(dir: dirPath, ext: ext)
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            let fileManager = FileManager.default

            if let templateUrl = rcitem.template {
                try fileManager.copyItem(at: templateUrl, to: fileURL)
                logger.info("已成功复制模板到目标路径：\(fileURL.path)")
            } else {
                if let defaultTemplateURL = Bundle.main.url(forResource: "template", withExtension: ext.replacingOccurrences(of: ".", with: "")) {
                    logger.info("使用模板创建文件，模板路径：\(defaultTemplateURL.path)")
                    try fileManager.copyItem(at: defaultTemplateURL, to: fileURL)
                    logger.info("已成功复制模板到目标路径：\(fileURL.path)")
                } else {
                    logger.warning("模板文件不存在：\(ext)")
                    try Data().write(to: fileURL)
                }
            }
            revealInFinderAndRename(fileURL)
        } catch let error as NSError {
            switch error.domain {
            case NSCocoaErrorDomain:
                switch error.code {
                case NSFileNoSuchFileError:
                    logger.error("文件不存在：\(filePath)")
                case NSFileWriteOutOfSpaceError:
                    logger.error("磁盘空间不足")
                case NSFileWriteNoPermissionError:
                    logger.error("没有写入权限：\(filePath)")
                default:
                    logger.error("创建文件错误：\(error.localizedDescription) (错误码：\(error.code))")
                }
            default:
                logger.error("未处理的错误：\(error.localizedDescription) (错误码：\(error.code))")
            }
        }
    }

    // MARK: - 辅助

    /// 生成目录内唯一的文件名（避免重名冲突）
    func getUniqueFilePath(dir: String, ext: String) -> String {
        let fileManager = FileManager.default
        let dirURL = URL(fileURLWithPath: dir.hasSuffix("/") ? String(dir.dropLast()) : dir)
        let baseFileName = AppLocalization.localized("Untitled")
        var filePath = dirURL.appendingPathComponent("\(baseFileName)\(ext)").path
        var counter = 1

        while fileManager.fileExists(atPath: filePath) {
            let newFileName = "\(baseFileName)\(counter)"
            filePath = dirURL.appendingPathComponent("\(newFileName)\(ext)").path
            counter += 1
        }

        return filePath
    }

    /// 解析新建文件的目标目录（目录直接用；文件取父目录）
    private func targetDirectoryForNewFile(_ target: [String]) -> String? {
        guard let rawPath = target.first else { return nil }
        let path = rawPath.removingPercentEncoding ?? rawPath
        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return path
            }
            return URL(fileURLWithPath: path).deletingLastPathComponent().path
        }

        return path
    }

    /// 在 Finder 中选中新文件并触发重命名（需要辅助功能权限）
    private func revealInFinderAndRename(_ fileURL: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [logger] in
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            guard AXIsProcessTrustedWithOptions(options) else {
                logger.warning("Accessibility permission is required to trigger Finder rename for \(fileURL.path)")
                return
            }

            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.activate()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                let keyCodeReturn: CGKeyCode = 36
                let source = CGEventSource(stateID: .hidSystemState)
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeReturn, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeReturn, keyDown: false)
                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
            }
        }
    }
}
