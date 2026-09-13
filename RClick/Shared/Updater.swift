//
//  Updater.swift
//  RClick
//
//  Created by 李旭 on 2025/9/21.
//

import Combine
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
    let objectWillChange: ObservableObjectPublisher = ObservableObjectPublisher()

    init() {}

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

/// 一次更新检查的结果。
///
/// 以前 `checkForUpdate` 返回 `GitHubRelease?`，那一个 `nil` 同时背着三种含义：
/// 网络失败、最新 release 是草稿/预发布、确实已是最新。而 `catch` 又把真实的网络
/// 错误吞成一句 `print`，上层拿到 `nil` 只能一律当成「已是最新」——所以断网会被
/// 报成「已是最新」。三种情况不拆开，界面就没法说实话。
enum UpdateCheckResult {
    case updateAvailable(GitHubRelease)
    case upToDate
    case failed(String)
}

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

    /// 拉仓库的星标数。走 `/repos/{owner}/{repo}`，和 release 是两个端点。
    func fetchStarCount() async throws -> Int {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        struct Repository: Decodable {
            let stargazersCount: Int
            enum CodingKeys: String, CodingKey { case stargazersCount = "stargazers_count" }
        }
        return try JSONDecoder().decode(Repository.self, from: data).stargazersCount
    }

    // 检查是否需要更新。
    // 返回枚举而不是 `GitHubRelease?`：那个 `nil` 原来同时背着「网络失败」
    // 「最新 release 是草稿或预发布」「确实已是最新」三种含义，而 `catch` 又把
    // 真实的网络错误吞成一句 `print`，上层只能一律当成「已是最新」——
    // 于是断网会被报成「已是最新」。三种情况分开，界面才可能说实话。
    func checkForUpdate(currentVersion: String, includePrereleases: Bool = false) async -> UpdateCheckResult {
        do {
            let latestRelease = try await fetchLatestRelease()

            // 草稿版和预发布版不算可更新版本，但这是一次成功的检查
            if latestRelease.draft || (!includePrereleases && latestRelease.prerelease) {
                return .upToDate
            }

            if compareVersions(currentVersion, latestRelease.version) == .orderedAscending {
                return .updateAvailable(latestRelease)
            }

            return .upToDate
        } catch {
            return .failed(error.localizedDescription)
        }
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
    /// 上一次检查的结论是「已是最新」。
    ///
    /// 单独一个字段，不再借用 `updateError`：借用会让界面无法区分「检查成功且已是最新」
    /// 和「检查失败」，弹窗里那张绿色「Up to Date」卡片也因此永远走不到。
    @Published var isUpToDate = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var showUpdateSheet = false

    /// 仓库星标数。nil 表示还没拿到——界面就不显示数字，不占位、不报错。
    @Published private(set) var starCount: Int?
    
    private let githubChecker: GitHubReleaseChecker
    private let preferences: UpdatePreferences
    private let currentVersion: String
    /// 存下来只为拼仓库/Issues 地址，别处不再硬编码 URL。
    private let owner: String
    private let repo: String

    /// 是否来自 Mac App Store（通过 `Contents/_MASReceipt/receipt` 是否存在判断）。
    /// App Store 构建禁止自更新（MAS 审核要求），改为引导用户去 App Store 更新。
    private var isAppStoreBuild: Bool {
        let receiptPath = Bundle.main.bundlePath + "/Contents/_MASReceipt/receipt"
        return FileManager.default.fileExists(atPath: receiptPath)
    }

    init(owner: String, repo: String, currentVersion: String) {
        self.githubChecker = GitHubReleaseChecker(owner: owner, repo: repo)
        self.preferences = UpdatePreferences()
        self.currentVersion = currentVersion
        self.owner = owner
        self.repo = repo
    }

    // MARK: - 星标数

    private enum StarCache {
        static let count = "githubStarCount"
        static let fetchedAt = "githubStarCountFetchedAt"
        /// 一天拉一次。星数不是实时指标，没必要每次打开「关于」都请求一次。
        static let lifetime: TimeInterval = 24 * 60 * 60
    }

    /// 取星标数：优先用缓存，过期或没有才请求。
    ///
    /// 失败不打扰用户——有旧值就继续用（别让数字忽然消失），没有就保持 nil，
    /// 「关于」页那一行只会少一个数字，不会多一条错误。
    func loadStarCount() async {
        let defaults = UserDefaults.group
        let cachedAt = defaults.object(forKey: StarCache.fetchedAt) as? Date
        let cached = defaults.object(forKey: StarCache.count) as? Int

        if let cachedAt, let cached, Date().timeIntervalSince(cachedAt) < StarCache.lifetime {
            starCount = cached
            return
        }

        if let fresh = try? await githubChecker.fetchStarCount() {
            starCount = fresh
            defaults.set(fresh, forKey: StarCache.count)
            defaults.set(Date(), forKey: StarCache.fetchedAt)
        } else if let cached {
            starCount = cached
        }
    }
    
    // 关闭更新提示。
    // 只关窗，**不清空检查结果**：清空会让「关于」页的状态行在关窗后退回「尚未检查」，
    // 把用户刚拿到的信息抹掉；再用「查看详情…」打开时也会看到一张空白的卡片。
    func dismissUpdateSheet() {
        showUpdateSheet = false
    }

    /// 打开更新弹窗展示上次的检查结果，不重新发起检查。
    func showUpdateDetails() {
        showUpdateSheet = true
    }
      
    // 检查更新
    func checkForUpdates(force: Bool = false) async {
        isChecking = true
        updateError = nil
        isUpToDate = false
        showUpdateSheet = true

        defer { isChecking = false }

        switch await githubChecker.checkForUpdate(currentVersion: currentVersion) {
        case .failed(let reason):
            // 真失败。从此不再和「已是最新」共用 updateError，弹窗标题才对得上内容。
            updateError = reason

        case .upToDate:
            // 单独置位。updateError 保持 nil，弹窗因此会走到它原本走不到的 else 分支，
            // 显示作者早就写好、却从未显示过的绿色「Up to Date」卡片。
            isUpToDate = true

        case .updateAvailable(let release):
            // 检查用户是否忽略了此版本
            if !force && preferences.isVersionIgnored(release.version) {
                updateError = String(format: AppLocalization.localized("Version %@ is ignored"), release.version)
                return
            }
            availableUpdate = release
        }
    }
    
    // MARK: - 下载和安装方法

    func downloadAndInstallUpdate() async {
        print("start downloadAndInstallUpdate")

        // App Store 构建：禁止自更新，引导用户去 Mac App Store
        guard !isAppStoreBuild else {
            showAppStoreUpdateAlert()
            return
        }

        guard let release = availableUpdate else {
            updateError = AppLocalization.localized("No update is available.")
            print("没有可用的更新")
            return
        }
        
        // 查找 .app.zip 附件
        guard let appZipAsset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".app.zip") }) else {
            updateError = AppLocalization.localized("No .app.zip application package was found.")
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
            updateError = String(format: AppLocalization.localized("Installation failed: %@"), error.localizedDescription)
        }
        
        isDownloading = false
    }

    func downloadAsset(asset: GitHubRelease.Asset) async throws -> URL {
        print("start downloadAsset:\(asset.browserDownloadUrl)")
        let tempDir = FileManager.default.temporaryDirectory
        let downloadURL = tempDir.appendingPathComponent(asset.name)
        
        var request = URLRequest(url: URL(string: asset.browserDownloadUrl)!)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        
        let downloadFailedMessage = AppLocalization.localized("Download failed")
        
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
                    continuation.resume(throwing: DownloadError.downloadFailed(downloadFailedMessage))
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
            let errorString = String(data: errorData, encoding: .utf8) ?? AppLocalization.localized("Unknown error")
            throw InstallationError.zipExtractionFailed(String(format: AppLocalization.localized("Extraction failed: %@"), errorString))
        }
        
        // 查找解压后的 .app 文件
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: extractionDir, includingPropertiesForKeys: nil)
        
        guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
            throw InstallationError.noAppFound(AppLocalization.localized("No .app application was found in the ZIP file."))
        }
        
        return appURL
    }

    // MARK: - 请求文件夹权限
    @MainActor
    private func requestApplicationsFolderAccess() async throws {
        let openPanel = NSOpenPanel()
        openPanel.message = AppLocalization.localized("RClick needs permission to install the update into your Applications folder.")
        openPanel.prompt = AppLocalization.localized("Grant Permission")
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first

        let response = await openPanel.begin()
        
        guard response == .OK, let selectedURL = openPanel.url else {
            throw InstallationError.permissionDenied(AppLocalization.localized("The user cancelled authorization."))
        }

        // 验证用户是否选择了正确的文件夹
        let applicationsURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first!
        guard selectedURL.path == applicationsURL.path else {
            throw InstallationError.permissionDenied(AppLocalization.localized("Please select the correct Applications folder."))
        }
    }
    // MARK: - 安装应用到应用程序目录
    private func installApplication(appURL: URL) async throws {
        let fileManager = FileManager.default
        let applicationsURL = fileManager.urls(for: .applicationDirectory, in: .localDomainMask).first!
        let destinationAppURL = applicationsURL.appendingPathComponent(appURL.lastPathComponent)
        print("start install \(appURL.path) --- \(destinationAppURL.path)")
        // 安装之前，先检查一下destinationAppURL 是否有权限读写，如果没有权限，请求权限
         // 检查对应用程序文件夹的写入权限
        if !fileManager.isWritableFile(atPath: applicationsURL.path) {
            print("没有应用程序文件夹的写入权限，正在请求权限...")
            try await requestApplicationsFolderAccess()
        }
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
                throw InstallationError.invalidAppBundle(AppLocalization.localized("The application bundle is invalid or damaged."))
            }
        } catch {
            print("❌ 安装失败: \(error)")
        }
        
    }

    // MARK: - App Store 更新引导

    /// App Store 构建：提示用户通过 Mac App Store 更新
    private func showAppStoreUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = AppLocalization.localized("Update via Mac App Store")
        alert.informativeText = AppLocalization.localized("RClick is installed from the Mac App Store. Please update it from the App Store.")
        alert.addButton(withTitle: AppLocalization.localized("Open App Store"))
        alert.addButton(withTitle: AppLocalization.localized("Later"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "macappstore://")!)
        }
    }

    // MARK: - 显示安装完成提示

    private func showInstallationCompleteAlert() {
        let alert = NSAlert()
        alert.messageText = AppLocalization.localized("Update Installed")
        alert.informativeText = AppLocalization.localized("The application has been updated successfully. Restart the app to finish the update.")
        alert.addButton(withTitle: AppLocalization.localized("Restart Now"))
        alert.addButton(withTitle: AppLocalization.localized("Restart Later"))
        
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
            // 无论如何都退出当前应用（切回主线程）
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }

    // 忽略当前可用更新
    func ignoreCurrentUpdate() {
        if let version = availableUpdate?.version {
            preferences.ignoreVersion(version)
            availableUpdate = nil
        }
    }
    
    /// 统一的仓库地址拼接：owner/repo 来自 init，不在各处再硬编码一遍。
    private func openGitHub(_ path: String = "") {
        guard let url = URL(string: "https://github.com/\(owner)/\(repo)\(path)") else { return }
        NSWorkspace.shared.open(url)
    }

    // 打开GitHub发布页面
    func openReleasesPage() { openGitHub("/releases") }

    /// 打开仓库主页（「关于」页的「加星」走这里）。
    func openRepositoryPage() { openGitHub() }

    /// 打开 Issues 列表（「关于」页的「反馈问题」走这里）。
    func openIssuesPage() { openGitHub("/issues") }
    
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
        case permissionDenied(String)
        
        var errorDescription: String? {
            switch self {
            case .zipExtractionFailed(let message):
                return message
            case .noAppFound(let message):
                return message
            case .invalidAppBundle(let message):
                return message
            case .permissionDenied(let message):
                return message
            }
        }
    }
}
