//
//  Util.swift
//  RClick
//
//  Created by 李旭 on 2024/8/8.
//

import Foundation
import FinderSync


class Util {
    
   @objc func extensionable () -> Bool {
        return FinderSync.FIFinderSyncController.isExtensionEnabled
    }
}
