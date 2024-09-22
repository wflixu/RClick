//
//  FinderSyncExtConfig.swift
//  RClick
//
//  Created by 李旭 on 2024/9/17.
//

import Security
import SwiftUI
import Foundation

struct FinderSyncExtConfig: View {
    @AppLog(category: "ext-config")
    private var logger

    @State private var pluginStr: String = "--"

    var body: some View {
        HStack {
            Button("test") {
                runPluginKitWithSudo()
            }
        }
        HStack {
            Text(pluginStr)
        }
    }

    

    func runPluginkitCommand() {
        let task = Process()

        // Option 1: Run pluginkit directly
        task.launchPath="/usr/bin/pluginkit"
        task.arguments = ["-m", "-p", "com.apple.FinderSync"]
    }

    func runPluginKitWithSudo() {
        // 创建一个 AppleScript 来执行 sudo 命令
        let appleScript = """
        do shell script "/usr/bin/pluginkit -mAD -p com.apple.FinderSync -vvv" with administrator privileges
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            let output = scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("Error: \(error)")
            } else {
                print("Command output: \(output.stringValue ?? "No output")")
            }
        }
    }
}

#Preview {
    FinderSyncExtConfig()
}
