//
//  SiteFolder.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import Foundation

struct SiteFolder: Identifiable, Hashable {
    let id: String
    let displayName: String
    let folderURL: URL
    let entryFileName: String

    var routeComponent: String {
        folderURL.lastPathComponent
    }
}

