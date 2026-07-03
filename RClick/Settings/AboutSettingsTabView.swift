//
//  AdvancedSettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import ExtensionFoundation
import ExtensionKit
import FinderSync
import SwiftUI

struct AboutSettingsTabView: View {
    let messager = Messager.shared
    @EnvironmentObject var updateManager: UpdateManager

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image("Logo")
                        .resizable()
                        .frame(width: 96, height: 96)

                    VStack(spacing: 4) {
                        Text("RClick").font(.title)
                        Text(String(format: AppLocalization.localized("Version %@ (%@)"), getAppVersion(), getBuildVersion()))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Section {
                Text(appLocalized: "RClick is a right-click menu extension that allows you to add applications for opening folders and includes some common actions.")
                    .font(.body)
            }

            Section {
                HStack {
                    Button(AppLocalization.localized("Check for Updates")) {
                        Task {
                            await updateManager.checkForUpdates(force: true)
                        }
                    }
                    if updateManager.isChecking {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }

            Section {
                Link(destination: URL(string: "https://github.com/wflixu/RClick")!) {
                    Label("github.com/wflixu/RClick", image: "github")
                }
            }
        }
        .formStyle(.grouped)
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
}
