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

    var body: some View {
        Form {
            identitySection
            updateSection
            communitySection
        }
        .formStyle(.grouped)
        // 带缓存，缓存新鲜时这里只是读一下 UserDefaults，不会真的发请求
        .task { await updateManager.loadStarCount() }
    }

    // MARK: - 应用标识

    /// 图标、名字、版本、简介同处一个居中的块。
    ///
    /// 简介原先单独占一个 Section，分组样式会在两者之间画一个框、留一段空隙，
    /// 加上一个居中一个左对齐，看起来就是两截互不相干的内容。
    private var identitySection: some View {
        Section {
            VStack(spacing: 12) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)

                VStack(spacing: 4) {
                    Text("RClick")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(String(format: AppLocalization.localized("Version %@ (%@)"), getAppVersion(), getBuildVersion()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(appLocalized: "RClick is a right-click menu extension that allows you to add applications for opening folders and includes some common actions.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    // MARK: - 更新

    /// 更新状态行。
    ///
    /// 沿用 General 里「状态行」的写法（见 `GeneralSettingsTabView` 的 Finder 扩展那一行）：
    /// 左边是带状态色的名称，右边是状态说明 + 操作按钮。原先这里只有一个光秃秃的按钮
    /// 单独占一段，上下都是空白，所以显得突兀——按钮旁边永远有说明它当前状态的文字，
    /// 它才成为一句话的结尾，而不是一个孤立的控件。
    private var updateSection: some View {
        Section {
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
                Label(AppLocalization.localized("RClick on GitHub"), image: "github")
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
