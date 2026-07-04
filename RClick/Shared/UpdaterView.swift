//
//  Up.swift
//  RClick
//
//  Created by 李旭 on 2025/9/21.
//
import SwiftUI

struct UpdateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var updateManager: UpdateManager
    
    var body: some View {
        VStack(spacing: 20) {
            if updateManager.isChecking {
                checkingView
            } else if let release = updateManager.availableUpdate {
                updateAvailableView(release)
            } else if let error = updateManager.updateError {
                errorView(error)
            } else {
                noUpdateView
            }
        }
        .padding(20)
        .frame(width: 400)
    }
    
    private var checkingView: some View {
        VStack(spacing: 15) {
            ProgressView()
                .scaleEffect(1.5)
            Text(appLocalized: "Checking for updates...")
                .font(.headline)
        }
    }
    
    private func updateAvailableView(_ release: GitHubRelease) -> some View {
        // 更新可用视图实现保持不变...
        VStack(spacing: 15) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text(appLocalized: "New Version Available")
                .font(.title2)
                .bold()
            
            Text(String(format: AppLocalization.localized("Version %@"), release.version))
                .font(.title3)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(release.body)
                    .font(.body)
                    .padding(5)
            }
            .frame(maxHeight: 150)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            HStack {
                Button(AppLocalization.localized("Ignore This Version")) {
                    updateManager.ignoreCurrentUpdate()
                    updateManager.dismissUpdateSheet()
                }
                
                Button(AppLocalization.localized("Download Manually")) {
                    updateManager.openReleasesPage()
                    updateManager.dismissUpdateSheet()
                }
                
                Button(AppLocalization.localized("Download and Install")) {
                    Task {
                        await updateManager.downloadAndInstallUpdate()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var noUpdateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text(appLocalized: "Up to Date")
                .font(.title2)
                .bold()
            
            Text(appLocalized: "The current version is already up to date.")
                .foregroundColor(.secondary)
            
            Button(AppLocalization.localized("OK")) {
                updateManager.dismissUpdateSheet()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text(appLocalized: "Failed to Check for Updates")
                .font(.title2)
                .bold()
            
            Text(error)
                .font(.body)
                .multilineTextAlignment(.center)
            
            Button(AppLocalization.localized("OK")) {
                updateManager.dismissUpdateSheet()
            }
            .buttonStyle(.bordered)
        }
    }
}
