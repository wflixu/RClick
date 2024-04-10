//
//  ContentView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import SwiftUI
import SwiftData

struct ContentView: View {
     @State private var showFileImporter = false
  

    var body: some View {
        VStack {
            Text("main window")
            
            HStack {
                SettingsLink {
                     Text("Settings")
                }
            }
            
        }.frame(width: 800, height: 600)
    }

    

    
}

#Preview {
    ContentView()
       
}
