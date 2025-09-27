//
//  Updater.swift
//  RClick
//
//  Created by 李旭 on 2025/9/21.
//

import Foundation
import SwiftUI

// MARK: - 数据模型

struct GitHubRelease: Codable, Identifiable {
    let id: Int
    let tagName: String
    let name: String
    let body: String
    let draft: Bool
    let prerelease: Bool
    let publishedAt: Date
    let assets: [Asset]
    let htmlUrl: String
    
    var version: String {
        tagName.replacingOccurrences(of: "v", with: "")
    }
    
    struct Asset: Codable {
        let id: Int
        let name: String
        let browserDownloadUrl: String
        let size: Int
        let contentType: String?
        
        enum CodingKeys: String, CodingKey {
            case id, name, size
            case browserDownloadUrl = "browser_download_url"
            case contentType = "content_type"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name, body, draft, prerelease, assets
        case publishedAt = "published_at"
        case htmlUrl = "html_url"
    }
}

// MARK: - 用户偏好设置

class UpdatePreferences: ObservableObject {
    @AppStorage("ignoredVersion") private var ignoredVersionData: Data = .init()
    
    // 获取忽略的版本列表
    var ignoredVersions: [String] {
        get {
            do {
                return try JSONDecoder().decode([String].self, from: ignoredVersionData)
            } catch {
                return []
            }
        }
        set {
            do {
                ignoredVersionData = try JSONEncoder().encode(newValue)
            } catch {
                print("Failed to save ignored versions: \(error)")
            }
        }
    }
    
    // 忽略特定版本
    func ignoreVersion(_ version: String) {
        var ignored = ignoredVersions
        if !ignored.contains(version) {
            ignored.append(version)
            ignoredVersions = ignored
        }
    }
    
    // 检查版本是否被忽略
    func isVersionIgnored(_ version: String) -> Bool {
        ignoredVersions.contains(version)
    }
}

// MARK: - GitHub API 服务

class GitHubReleaseChecker {
    private let owner: String
    private let repo: String
    
    init(owner: String, repo: String) {
        self.owner = owner
        self.repo = repo
    }
    
    // 获取最新release
    func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        print(url)
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GitHubRelease.self, from: data)
    }
    
    // 检查是否需要更新
    func checkForUpdate(currentVersion: String, includePrereleases: Bool = false) async -> GitHubRelease? {
        print(currentVersion)
        do {
            let latestRelease = try await fetchLatestRelease()
            
            // 跳过草稿版和预发布版（除非明确包含）
            if latestRelease.draft || (!includePrereleases && latestRelease.prerelease) {
                return nil
            }
            
            // 比较版本
            if compareVersions(currentVersion, latestRelease.version) == .orderedAscending {
                return latestRelease
            } else {
                print("the last verison \(latestRelease.version)")
            }
        } catch {
            print("检查更新失败: \(error)")
        }
        
        return nil
    }
    
    // 语义化版本比较
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        let components1 = version1.components(separatedBy: ".")
        let components2 = version2.components(separatedBy: ".")
        
        for i in 0 ..< max(components1.count, components2.count) {
            let part1 = i < components1.count ? components1[i] : "0"
            let part2 = i < components2.count ? components2[i] : "0"
            
            if let num1 = Int(part1), let num2 = Int(part2) {
                if num1 < num2 { return .orderedAscending }
                if num1 > num2 { return .orderedDescending }
            } else {
                // 处理非数字部分（如beta、rc等）
                let comparison = part1.compare(part2)
                if comparison != .orderedSame {
                    return comparison
                }
            }
        }
        
        return .orderedSame
    }
}

// MARK: - 更新管理器

@MainActor
class UpdateManager: ObservableObject {
    @Published var availableUpdate: GitHubRelease?
    @Published var isChecking = false
    @Published var updateError: String?
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var showUpdateSheet = false
    
    private let githubChecker: GitHubReleaseChecker
    private let preferences: UpdatePreferences
    private let currentVersion: String
    
    init(owner: String, repo: String, currentVersion: String) {
        self.githubChecker = GitHubReleaseChecker(owner: owner, repo: repo)
        self.preferences = UpdatePreferences()
        self.currentVersion = currentVersion
    }
    
    // 关闭更新提示
    func dismissUpdateSheet() {
        showUpdateSheet = false
        availableUpdate = nil
        updateError = nil
    }
      
    // 检查更新
    func checkForUpdates(force: Bool = false) async {
        isChecking = true
        updateError = nil
        showUpdateSheet = true
        
        defer { isChecking = false }
        
        guard let release = await githubChecker.checkForUpdate(currentVersion: currentVersion) else {
            print("not release")
            updateError = "当前已经是最新版本"
            return
        }
            
        // 检查用户是否忽略了此版本
        if !force && preferences.isVersionIgnored(release.version) {
            print("忽略这个版本")
            updateError = "已忽略版本 \(release.version)"
            return
        }
            
        availableUpdate = release
    }
    
    // MARK: - 下载和安装方法

    func downloadAndInstallUpdate() async {
        print("start downloadAndInstallUpdate")
        guard let release = availableUpdate else {
            updateError = "没有可用的更新"
            print("没有可用的更新")
            return
        }
        
        // 查找 .app.zip 附件
        guard let appZipAsset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".app.zip") }) else {
            updateError = "未找到 .app.zip 格式的应用程序包"
            print("没有可用的更新")
            return
        }
        
        isDownloading = true
        downloadProgress = 0
        
        do {
            // 1. 下载 ZIP 文件
            let downloadedURL = try await downloadAsset(asset: appZipAsset)
            
            // 2. 解压到临时目录
            let appURL = try await extractAppZip(zipURL: downloadedURL)
            
            // 3. 安装应用到应用程序目录
            try await installApplication(appURL: appURL)
            
            // 4. 清理临时文件
            try? FileManager.default.removeItem(at: downloadedURL)
            try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent())
            
            // 5. 提示用户安装完成
            showInstallationCompleteAlert()
            
        } catch {
            updateError = "安装失败: \(error.localizedDescription)"
        }
        
        isDownloading = false
    }

    func downloadAsset(asset: GitHubRelease.Asset) async throws -> URL {
        print("start downloadAsset:\(asset.browserDownloadUrl)")
        let tempDir = FileManager.default.temporaryDirectory
        let downloadURL = tempDir.appendingPathComponent(asset.name)
        
        var request = URLRequest(url: URL(string: asset.browserDownloadUrl)!)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        
        // 使用 AsyncThrowingStream 来包装下载进度和结果
        return try await withCheckedThrowingContinuation { continuation in
            // Stream bytes and write to destination file
            let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
            let task = session.downloadTask(with: request) { tempURL, response, error in

                print("start do")
                if let error = error {
                    print("downn error")
                    continuation.resume(throwing: error)
                    return
                }

                guard let tempURL = tempURL,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200
                else {
                    continuation.resume(throwing: DownloadError.downloadFailed("下载失败"))
                    print("downn error")
                    return
                }

                do {
                    // 移动文件到目标位置
                    try? FileManager.default.removeItem(at: downloadURL)
                    try FileManager.default.moveItem(at: tempURL, to: downloadURL)
                    print("download url: \(downloadURL.path)")
                    continuation.resume(returning: downloadURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            task.resume()
        }
    }

    // 关联对象键
    private var DownloadDelegateKey: UInt8 = 0

    // MARK: - 解压 APP Zip 文件

    private func extractAppZip(zipURL: URL) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let extractionDir = tempDir.appendingPathComponent("app_extraction")
        
        // 创建解压目录
        try FileManager.default.createDirectory(at: extractionDir, withIntermediateDirectories: true)
        
        // 使用系统命令解压
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipURL.path, "-d", extractionDir.path]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "未知错误"
            throw InstallationError.zipExtractionFailed("解压失败: \(errorString)")
        }
        
        // 查找解压后的 .app 文件
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: extractionDir, includingPropertiesForKeys: nil)
        
        guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
            throw InstallationError.noAppFound("在ZIP文件中未找到.app应用程序")
        }
        
        return appURL
    }

    // MARK: - 安装应用到应用程序目录

    private func installApplication(appURL: URL) async throws {
        let fileManager = FileManager.default
        let applicationsURL = fileManager.urls(for: .applicationDirectory, in: .localDomainMask).first!
        let destinationAppURL = applicationsURL.appendingPathComponent(appURL.lastPathComponent)
        print("start install \(appURL.path) --- \(destinationAppURL.path)")
        do {
            // 检查目标位置是否已存在应用
            if fileManager.fileExists(atPath: destinationAppURL.path) {
                // 先尝试移动到废纸篓而不是直接删除
                try fileManager.trashItem(at: destinationAppURL, resultingItemURL: nil)
            }
            
            // 复制应用到应用程序目录
            try fileManager.copyItem(at: appURL, to: destinationAppURL)
            
            // 验证应用程序是否有效
            guard Bundle(url: destinationAppURL) != nil else {
//                try fileManager.removeItem(at: destinationAppURL)
                throw InstallationError.invalidAppBundle("应用程序包无效或损坏")
            }
        } catch {
            print("❌ 安装失败: \(error)")
        }
        
    }

    // MARK: - 显示安装完成提示

    private func showInstallationCompleteAlert() {
        let alert = NSAlert()
        alert.messageText = "更新安装完成"
        alert.informativeText = "应用程序已成功更新。需要重启应用来完成更新过程。"
        alert.addButton(withTitle: "立即重启")
        alert.addButton(withTitle: "稍后重启")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 启动新应用并退出当前应用
            launchNewApplicationAndExit()
        }
    }

    // MARK: - 启动新应用并退出

    private func launchNewApplicationAndExit() {
        let fileManager = FileManager.default
        let applicationsURL = fileManager.urls(for: .applicationDirectory, in: .localDomainMask).first!
        let currentAppName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "RClick"
        let newAppURL = applicationsURL.appendingPathComponent("\(currentAppName).app")
        
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: newAppURL, configuration: configuration) { _, error in
            if error != nil {
                print("启动新应用失败，可能需要手动启动")
            }
            // 无论如何都退出当前应用
            NSApp.terminate(nil)
        }
    }

    // 忽略当前可用更新
    func ignoreCurrentUpdate() {
        if let version = availableUpdate?.version {
            preferences.ignoreVersion(version)
            availableUpdate = nil
        }
    }
    
    // 打开GitHub发布页面
    func openReleasesPage() {
        if let url = URL(string: "https://github.com/wflixu/RClick/releases") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - 错误类型

    enum DownloadError: LocalizedError {
        case downloadFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .downloadFailed(let message):
                return message
            }
        }
    }

    enum InstallationError: LocalizedError {
        case zipExtractionFailed(String)
        case noAppFound(String)
        case invalidAppBundle(String)
        
        var errorDescription: String? {
            switch self {
            case .zipExtractionFailed(let message):
                return message
            case .noAppFound(let message):
                return message
            case .invalidAppBundle(let message):
                return message
            }
        }
    }
}
