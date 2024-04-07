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
  
       
    @AppStorage("mydirs") private var mydirs:[MyDir] = []
    
    
    
    var body: some View {
        VStack {
            Text("main window")
            SettingsLink {
                Text("Open App Settings Window...")
           }
            Button(action: addDir) {
                Label("添加授权文件夹", systemImage: "folder.fill.badge.plus")
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.directory,.application],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let files):
                    files.forEach { file in
                        // gain access to the directory
                        let gotAccess = file.startAccessingSecurityScopedResource()
                        if !gotAccess { return }
                        // access the directory URL
                        // (read templates in the directory, make a bookmark, etc.)
                        handlePickedPDF(file)
                        // release access
                        file.stopAccessingSecurityScopedResource()
                    }
                case .failure(let error):
                    // handle error
                    print(error)
                }
            }
            Divider()
            ForEach(mydirs) { item in
                HStack {
                    Text(item.path)
                }
            }
            
        }.frame(width: 800, height: 600)
    }
    
    private func addDir() {
        showFileImporter = true
    }
    
    private func handlePickedPDF (_ file: URL) {
        print(file.path())
        mydirs.append(MyDir(path: file.path()))
//        dirs.append(Dir(path: file.path()))
       
        
    }

    
}

#Preview {
    ContentView()
       
}
