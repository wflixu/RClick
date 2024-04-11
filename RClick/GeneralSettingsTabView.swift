//
//  GeneralSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/10.
//

import FinderSync
import SwiftUI

struct GeneralSettingsTabView: View {
  
    @Binding  var active:Tabs
    
    var extensionEabled: Bool {
        return FinderSync.FIFinderSyncController.isExtensionEnabled
    }

    var enableIcon: String {
        if FinderSync.FIFinderSyncController.isExtensionEnabled {
            return "checkmark.circle.fill"
        } else {
            return "checkmark.circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
           
            
            HStack(alignment: .bottom) {
                Text("启动 Finder Extension").font(.title3).fontWeight(.semibold)
                Spacer()
                Button(action: openExtensionset) {
                    Label("打开Finder 扩展设置", systemImage: enableIcon)
                }
            }

            Text(extensionEabled ? "扩展已经启用" : "扩展未启用")
            Text("需要启用 RClick Finder Extension 以便使其正常工作")
                .font(.headline)
                .fontWeight(.thin)
                .foregroundColor(Color.gray)
            Divider()

            HStack {
                
            }.frame(height: 20)
            HStack(alignment: .bottom) {
                Text("授权文件夹").font(.title3).fontWeight(.semibold)
                Spacer()
                Button(action: goSetFolder) {
                    Label("去授权", systemImage: "checkmark.circle")
                }
            }

            Text("授权的文件夹，才能能执行菜单的操作")
                .font(.headline)
                .fontWeight(.thin)
                .foregroundColor(Color.gray)
            Divider()

          
            Spacer()
    
            
        }

    }
    private func goSetFolder () {
        self.active = Tabs.folder
    }
    private func openExtensionset() {
        FinderSync.FIFinderSyncController.showExtensionManagementInterface()
    }
}
