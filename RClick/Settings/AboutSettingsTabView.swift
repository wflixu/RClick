//
//  AboutSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import Foundation
import SwiftUI

struct AboutSettingsTabView: View {
    @EnvironmentObject var updateManager: UpdateManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            aboutSection
            communitySection
            appsSection
        }
        .formStyle(.grouped)
        // 带缓存，缓存新鲜时这里只是读一下 UserDefaults，不会真的发请求
        .task { await updateManager.loadStarCount() }
    }

    // MARK: - 版本与更新

    /// 版本、构建号、更新状态和简介同处一段。
    ///
    /// 侧边栏顶部已经有 Logo、名称和版本号，这里不再重复品牌区。原先竖排居中的
    /// 大块（约 250pt）是整个 About 页需要滚动的直接原因；现在把版本和构建号
    /// 作为普通设置行，简介收进 section footer，第一屏就能看到下面的内容。
    private var aboutSection: some View {
        Section {
            LabeledContent(AppLocalization.localized("Version")) {
                HStack(spacing: 4) {
                    Text(getAppVersion())
                        .monospacedDigit()
                    Text(verbatim: "(\(getBuildVersion()))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            // 更新状态行：左边是带状态色的名称，右边是状态说明 + 操作按钮。
            LabeledContent {
                HStack(spacing: 8) {
                    if let detail = updateStatus.detail {
                        Text(detail)
                            .foregroundStyle(.secondary)
                    }
                    if updateManager.isChecking {
                        ProgressView().controlSize(.small)
                    }
                    Button(updateStatus.actionTitle) {
                        switch updateStatus.action {
                        case .check:
                            Task { await updateManager.checkForUpdates(force: true) }
                        case .details:
                            // 只开弹窗看上次的结果，不重新发起检查
                            updateManager.showUpdateDetails()
                        }
                    }
                    .disabled(updateManager.isChecking)
                }
            } label: {
                Label(updateStatus.title, systemImage: updateStatus.icon)
                    .foregroundStyle(updateStatus.color)
            }
        } footer: {
            Text(appLocalized: "RClick is a right-click menu extension that allows you to add applications for opening folders and includes some common actions.")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 更新区一行的全部推导集中在这里，视图只读结果，不在 body 里散落一串 if。
    ///
    /// 判定顺序和更新弹窗保持一致：检查中 → 有新版本 → 出错 → 已是最新 → 未检查。
    private struct UpdateStatus {
        enum Action { case check, details }

        let title: String
        let icon: String
        let color: Color
        var detail: String? = nil
        let actionTitle: String
        let action: Action
    }

    private var updateStatus: UpdateStatus {
        if updateManager.isChecking {
            return UpdateStatus(
                title: AppLocalization.localized("Checking for updates..."),
                icon: "arrow.triangle.2.circlepath",
                color: .secondary,
                actionTitle: AppLocalization.localized("Check for Updates"),
                action: .check
            )
        }
        if let release = updateManager.availableUpdate {
            return UpdateStatus(
                title: AppLocalization.localized("New Version Available"),
                icon: "arrow.down.circle.fill",
                color: .blue,
                detail: String(format: AppLocalization.localized("Version %@"), release.version),
                actionTitle: AppLocalization.localized("View Details…"),
                action: .details
            )
        }
        if updateManager.updateError != nil {
            // 只给短句，具体原因留在弹窗里，免得长句把这一行挤变形
            return UpdateStatus(
                title: AppLocalization.localized("Failed to Check for Updates"),
                icon: "exclamationmark.triangle.fill",
                color: .yellow,
                actionTitle: AppLocalization.localized("Check for Updates"),
                action: .check
            )
        }
        if updateManager.isUpToDate {
            return UpdateStatus(
                title: AppLocalization.localized("Up to Date"),
                icon: "checkmark.circle.fill",
                color: .green,
                actionTitle: AppLocalization.localized("Check for Updates"),
                action: .check
            )
        }
        return UpdateStatus(
            title: AppLocalization.localized("Not checked yet"),
            icon: "arrow.triangle.2.circlepath",
            color: .secondary,
            actionTitle: AppLocalization.localized("Check for Updates"),
            action: .check
        )
    }

    // MARK: - 项目与反馈

    /// 两行：去项目看看 + 反馈问题。
    ///
    /// 原先只有一行裸地址，既没说明项目有没有人在用，也没给任何可做的事。现在每行左边是
    /// 去处、右边是动作。星数由 `loadStarCount` 带缓存地取，取不到就只少一个数字，
    /// 不占位也不报错。
    private var communitySection: some View {
        Section {
            LabeledContent {
                HStack(spacing: 8) {
                    if let stars = updateManager.starCount {
                        // 用系统的紧凑数字格式，中文会自动变成「1.2万」而不是「1.2K」
                        Text(stars.formatted(.number.notation(.compactName)))
                            .foregroundStyle(.secondary)
                    }
                    Button(AppLocalization.localized("Add a Star")) {
                        updateManager.openRepositoryPage()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image("github")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                    Text(AppLocalization.localized("RClick on GitHub"))
                }
            }

            LabeledContent {
                Button(AppLocalization.localized("Open Issues")) {
                    updateManager.openIssuesPage()
                }
            } label: {
                Label(AppLocalization.localized("Feedback & Issues"), systemImage: "exclamationmark.bubble")
            }
        }
    }

    // MARK: - 更多应用

    /// 作者的其他 App。仅在 About 页展示，不参与功能；链接直接开到 App Store。
    private struct PromotedApp: Identifiable {
        let id: String
        let name: String
        let icon: String
        let summary: String
        let appStoreURL: URL
    }

    private var promotedApps: [PromotedApp] {
        [
            PromotedApp(
                id: "imonet",
                name: "iMonet",
                icon: "iMonetIcon",
                summary: AppLocalization.localized("A mouse-first image viewer with animated GIF, APNG and WebP playback."),
                appStoreURL: URL(string: "https://apps.apple.com/cn/app/imonet/id6770070921?mt=12")!
            ),
            PromotedApp(
                id: "livecam",
                name: "LiveCam",
                icon: "LiveCamIcon",
                summary: AppLocalization.localized("Show your avatar while recording your screen or live streaming."),
                appStoreURL: URL(string: "https://apps.apple.com/cn/app/livecam/id6476108478?mt=12")!
            ),
        ]
    }

    private var appsSection: some View {
        Section {
            ForEach(promotedApps) { app in
                LabeledContent {
                    Button(AppLocalization.localized("View on the App Store")) {
                        openURL(app.appStoreURL)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(app.icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                            Text(app.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(appLocalized: "More Apps")
        }
    }

    func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return AppLocalization.localized("Unknown")
    }

    func getBuildVersion() -> String {
        if let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return buildVersion
        }
        return AppLocalization.localized("Unknown")
    }
}

#Preview {
    AboutSettingsTabView()
        .environmentObject(UpdateManager(owner: "wflixu", repo: "RClick", currentVersion: "1.0.0"))
}
