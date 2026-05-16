//
//  BookmarkStore.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import Foundation

struct BookmarkStore {
    private let key = "LibraryFolderBookmark"

    func save(_ url: URL) {
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func restore() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                save(url)
            }

            return url
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }
}

