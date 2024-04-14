//
//  AdvancedSettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import SwiftUI

struct AboutSettingsTabView: View {
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
                Spacer()
            }
            HStack {
                Spacer()
                Text("RClick 是一个Finder 拓展，可以添加打开文件夹的App，可以添加一些常用的操作！").font(.title3)
                Spacer()
            }
            Spacer()
            Divider()
            HStack (alignment: .center) {
                Image("github")
                Text("https://github.com/wflixu/RClick")
                Spacer()
            }
        }
        
    }
}

#Preview {
    AboutSettingsTabView()
}
