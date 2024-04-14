//
//  ContentView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import os.log
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: subsystem, category: "main")

struct ContentView: View {
    @State private var showFileImporter = false

    var body: some View {
        VStack {
           SettingsView()
        }.frame(width: 900, height: 900)
    }
    
    var settingsL = SettingsLink()
    
    private func open () {
//        settingsL.
    }
}

#Preview {
    ContentView()
}
