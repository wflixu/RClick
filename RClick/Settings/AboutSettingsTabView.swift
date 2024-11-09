//
//  AdvancedSettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import FinderSync
import SwiftUI
import AppKit
import ExtensionKit
import ExtensionFoundation


struct AboutSettingsTabView: View {
    let messager = Messager.shared
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Image("Logo")
                    .resizable()
                    .frame(maxWidth: 128, maxHeight: 128)
                Spacer()
            }
            HStack {
                Spacer()
                Text("RClick").font(.title)
                Text("\(getAppVersion())（\(getBuildVersion())）")
                Spacer()
            }
            HStack {
                Spacer()
                Text("RClick is a right-click menu extension that allows you to add applications for opening folders and includes some common actions!").font(.title3)
                Spacer()
            }
            Spacer()
            Divider()
            HStack(alignment: .center) {
                Image("github")

                Text(verbatim: "https://github.com/wflixu/RClick")
                Spacer()
            }
        }
    }

    func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Unknown"
    }

    func getBuildVersion() -> String {
        if let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return buildVersion
        }
        return "Unknown"
    }
}

#Preview {
    AboutSettingsTabView()
}
