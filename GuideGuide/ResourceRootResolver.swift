//
//  ResourceRootResolver.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import Foundation

enum ResourceRootResolver {
    static func resourcesURL(for pickedURL: URL) -> URL? {
        let fileManager = FileManager.default

        if pickedURL.lastPathComponent.localizedCaseInsensitiveCompare("Resources") == .orderedSame,
           SiteScanner.containsSiteFolders(pickedURL) {
            return pickedURL
        }

        let preferredChildren = ["Resources", "resources"]
        for childName in preferredChildren {
            let childURL = pickedURL.appending(path: childName)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: childURL.path(percentEncoded: false), isDirectory: &isDirectory),
               isDirectory.boolValue,
               SiteScanner.containsSiteFolders(childURL) {
                return childURL
            }
        }

        if SiteScanner.containsSiteFolders(pickedURL) {
            return pickedURL
        }

        return nil
    }
}

