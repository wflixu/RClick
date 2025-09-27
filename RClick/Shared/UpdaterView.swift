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
            Text("正在检查更新...")
                .font(.headline)
        }
    }
    
    private func updateAvailableView(_ release: GitHubRelease) -> some View {
        // 更新可用视图实现保持不变...
        VStack(spacing: 15) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("发现新版本")
                .font(.title2)
                .bold()
            
            Text("版本 \(release.version)")
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
                Button("忽略此版本") {
                    updateManager.ignoreCurrentUpdate()
                    updateManager.dismissUpdateSheet()
                }
                
                Button("手动下载") {
                    updateManager.openReleasesPage()
                    updateManager.dismissUpdateSheet()
                }
                
                Button("下载并安装") {
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
            
            Text("已是最新版本")
                .font(.title2)
                .bold()
            
            Text("当前版本已是最新，无需更新。")
                .foregroundColor(.secondary)
            
            Button("确定") {
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
            
            Text("检查更新失败")
                .font(.title2)
                .bold()
            
            Text(error)
                .font(.body)
                .multilineTextAlignment(.center)
            
            Button("确定") {
                updateManager.dismissUpdateSheet()
            }
            .buttonStyle(.bordered)
        }
    }
}
