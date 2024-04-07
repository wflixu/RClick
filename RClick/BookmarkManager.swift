//
//  BookMarkManager.swift
//  RClick
//
//  Created by 李旭 on 2024/4/5.
//

import Foundation

import Cocoa

class BookmarkManager {
    
    static func allowFolder(for url: URL?, note str: String) -> URL? {
        
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.directoryURL = url
        openPanel.message = str
        
        
//        if let mainWindow = NSApplication.shared.mainWindow {
//            openPanel.beginSheetModal(for: mainWindow){(response) in
//                if response.rawValue == NSApplication.ModalResponse.OK.rawValue {
//                    if let selectedURL =  openPanel.url{
//                        if !selectedURL.path.isChildPath(of: PreferenceManager.urlAccess()) {
//                            callXPCSaveSecurityBookmark(url: selectedURL)
//                        } else {
//                            _ = NotifyManager.messageNotify(message: NSLocalizedString("general.addChilderOfExistingFolder", comment: ""), inform: "", style: .informational)
//                        }
//                    }
//                }
//                NSApplication.shared.stopModal(withCode: .OK)
//            }
//            NSApplication.shared.runModal(for: mainWindow)
//        } else {
//            let result = openPanel.runModal()
//            if result == .OK {
//                if let selectedURL =  openPanel.url{
//                    if !selectedURL.path.isChildPath(of: PreferenceManager.urlAccess()) {
//                        callXPCSaveSecurityBookmark(url: selectedURL)
//                    } else {
//                        _ = NotifyManager.messageNotify(message: NSLocalizedString("general.addChilderOfExistingFolder", comment: ""), inform: "", style: .informational)
//                    }
//                }
//            }
//        }
        return openPanel.url
    }
    
//    static func isBookmarkEmpty(with option: PreferenceManager.Key) -> Bool {
//        if (PreferenceManager.urlAccess()).isEmpty {
//            return true
//        } else {
//            return false
//        }
//    }
//    
//    static func callXPCSaveSecurityBookmark(url: URL) {
//        if let minimal = try? url.bookmarkData(options: NSURL.BookmarkCreationOptions.minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
//            _ = XPCServiceManager.bookmarkXPCUpdate(minimalBookmark: minimal)
//        }
//    }
//    
//    static func saveSecurityBookmark(minimalBookmark: Data) -> Bool {
//        var existingBookmarkDict = PreferenceManager.bookmark()
//        var stale = false
//        do {
//            let restoredUrl = try URL.init(resolvingBookmarkData: minimalBookmark, options: NSURL.BookmarkResolutionOptions.withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale)
//            let helperBookmark = try restoredUrl.bookmarkData(options: NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
//            existingBookmarkDict[restoredUrl] = PreferenceManager.SharedBookmark(helperBookmark)
//        } catch {
//            return false
//        }
//        PreferenceManager.set(for: .bookmarkAccessFolder, with: existingBookmarkDict)
//        return true
//    }
//    
//    static func loadHelperBookmarks() -> Bool {
//        let existingBookmarkDict = PreferenceManager.bookmark()
//        if !existingBookmarkDict.isEmpty {
//            for bookmark in existingBookmarkDict {
//                if let helperBookmark = bookmark.value.helperBookmark {
//                    restoreBookmark(data: helperBookmark)
//                }
//            }
//            return true
//        } else {
//            return false
//        }
//    }
//    
//    static func stopAccessing(){
//        let existingBookmarkDict = PreferenceManager.bookmark()
//        for bookmark in existingBookmarkDict {
//            if let helperBookmark = bookmark.value.helperBookmark {
//                stopAccessingBookmark(data: helperBookmark)
//            }
//        }
//    }
//    
//    static private func restoreBookmark(data: Data){
//        var restoredUrl: URL?
//        var isStale = false
//        do{
//            restoredUrl = try URL.init(resolvingBookmarkData: data, options: NSURL.BookmarkResolutionOptions.withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
//        }
//        catch{
//            restoredUrl = nil
//        }
//        if let url = restoredUrl{
//            if !isStale{
//                _ = url.startAccessingSecurityScopedResource()
//            }
//        }
//    }
//    
//    static private func stopAccessingBookmark(data: Data){
//        var restoredUrl: URL?
//        var isStale = false
//        do{
//            restoredUrl = try URL.init(resolvingBookmarkData: data, options: NSURL.BookmarkResolutionOptions.withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
//        }
//        catch{
//            restoredUrl = nil
//        }
//        if let url = restoredUrl{
//            if !isStale{
//                url.stopAccessingSecurityScopedResource()
//            }
//        }
//    }
}
 

