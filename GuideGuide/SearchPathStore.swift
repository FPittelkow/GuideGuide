//
//  SearchPathStore.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import Foundation
import Combine

struct SearchPath: Identifiable, Hashable {
    let url: URL

    var id: String {
        url.path(percentEncoded: false)
    }

    var displayName: String {
        url.lastPathComponent
    }

    var detail: String {
        url.deletingLastPathComponent().path(percentEncoded: false)
    }
}

@MainActor
final class SearchPathStore: ObservableObject {
    static let shared = SearchPathStore()

    @Published private(set) var searchPaths: [SearchPath] = []

    private let bookmarksKey = "SearchPathBookmarks"
    private let legacyBookmarkStore = BookmarkStore()
    private var scopedURLs: [URL] = []

    private init() {
        restore()
    }

    deinit {
        for url in scopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }

    var resourcesURLs: [URL] {
        searchPaths.compactMap { ResourceRootResolver.resourcesURL(for: $0.url) }
    }

    func add(_ url: URL) {
        let resolvedURL = ResourceRootResolver.resourcesURL(for: url) ?? url
        guard !searchPaths.contains(where: { $0.id == resolvedURL.path(percentEncoded: false) }) else {
            return
        }

        _ = resolvedURL.startAccessingSecurityScopedResource()
        scopedURLs.append(resolvedURL)
        searchPaths.append(SearchPath(url: resolvedURL))
        save()
    }

    func remove(_ searchPath: SearchPath) {
        searchPaths.removeAll { $0.id == searchPath.id }

        if let index = scopedURLs.firstIndex(where: { $0.path(percentEncoded: false) == searchPath.id }) {
            scopedURLs[index].stopAccessingSecurityScopedResource()
            scopedURLs.remove(at: index)
        }

        save()
    }

    private func save() {
        let bookmarkData = scopedURLs.compactMap { url in
            try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarkData, forKey: bookmarksKey)
    }

    private func restore() {
        let bookmarkData = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] ?? []

        if bookmarkData.isEmpty, let legacyURL = legacyBookmarkStore.restore() {
            add(legacyURL)
            return
        }

        for data in bookmarkData {
            guard let url = restoreURL(from: data) else { continue }
            _ = url.startAccessingSecurityScopedResource()
            scopedURLs.append(url)
            searchPaths.append(SearchPath(url: url))
        }
    }

    private func restoreURL(from data: Data) -> URL? {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                save()
            }

            return url
        } catch {
            return nil
        }
    }
}
