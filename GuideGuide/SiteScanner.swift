//
//  SiteScanner.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import Foundation

enum SiteScanner {
    static func scan(resourcesURL: URL) -> [SiteFolder] {
        let fileManager = FileManager.default
        guard let children = try? fileManager.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return children.compactMap { childURL in
            guard childURL.isDirectory else { return nil }
            guard let entryFileName = entryFileName(in: childURL) else { return nil }

            return SiteFolder(
                id: childURL.path(percentEncoded: false),
                displayName: childURL.lastPathComponent.replacingOccurrences(of: "-", with: " "),
                folderURL: childURL,
                entryFileName: entryFileName
            )
        }
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    static func containsSiteFolders(_ url: URL) -> Bool {
        !scan(resourcesURL: url).isEmpty
    }

    private static func entryFileName(in folderURL: URL) -> String? {
        let fileManager = FileManager.default
        let preferredNames = ["index.html", "index.htm"]

        for name in preferredNames {
            let candidate = folderURL.appending(path: name)
            if fileManager.fileExists(atPath: candidate.path(percentEncoded: false)) {
                return name
            }
        }

        guard let htmlFiles = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return htmlFiles
            .filter { $0.pathExtension.localizedCaseInsensitiveCompare("html") == .orderedSame }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .first?
            .lastPathComponent
    }
}

private extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}

