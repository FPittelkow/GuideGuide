//
//  SiteLibrary.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import Foundation
import Combine

@MainActor
final class SiteLibrary: ObservableObject {
    @Published var sites: [SiteFolder] = []
    @Published var selectedSiteID: SiteFolder.ID? {
        didSet {
            probeSelectedSite()
        }
    }
    @Published var searchText = ""
    @Published var isChoosingFolder = false
    @Published var resourcesURL: URL?
    @Published var serverBaseURL: URL?
    @Published var errorMessage: String?
    @Published var serverProbeMessage: String?

    private let server = LocalSiteServer()
    private let bookmarkStore = BookmarkStore()
    private var directoryMonitor: DirectoryMonitor?
    private var securityScopedURL: URL?

    var selectedSite: SiteFolder? {
        filteredSites.first { $0.id == selectedSiteID } ?? sites.first { $0.id == selectedSiteID }
    }

    var filteredSites: [SiteFolder] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return sites }
        return sites.filter { $0.displayName.localizedStandardContains(trimmedSearch) }
    }

    var currentURL: URL? {
        guard let serverBaseURL else { return nil }
        guard let selectedSite else { return serverBaseURL }
        return URL(string: selectedSite.routeComponent.urlPathEncoded + "/", relativeTo: serverBaseURL)?.absoluteURL
    }

    func bootstrap() {
        guard resourcesURL == nil else { return }

        if let savedURL = bookmarkStore.restore() {
            openLibrary(at: savedURL)
            return
        }
    }

    func showFolderPicker() {
        isChoosingFolder = true
    }

    func handleFolderPicker(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            bookmarkStore.save(url)
            openLibrary(at: url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func reload() {
        guard let resourcesURL else { return }
        scan(resourcesURL: resourcesURL)
    }

    private func openLibrary(at pickedURL: URL) {
        securityScopedURL?.stopAccessingSecurityScopedResource()

        let hasAccess = pickedURL.startAccessingSecurityScopedResource()
        securityScopedURL = hasAccess ? pickedURL : nil

        guard let resolvedResourcesURL = ResourceRootResolver.resourcesURL(for: pickedURL) else {
            errorMessage = "The folder does not contain a Resources folder or HTML site folders."
            resourcesURL = nil
            sites = []
            selectedSiteID = nil
            server.stop()
            serverBaseURL = nil
            return
        }

        resourcesURL = resolvedResourcesURL
        errorMessage = nil
        scan(resourcesURL: resolvedResourcesURL)
        startServer(resourcesURL: resolvedResourcesURL)
        startMonitoring(resourcesURL: resolvedResourcesURL)
        probeSelectedSite()
    }

    private func scan(resourcesURL: URL) {
        let discoveredSites = SiteScanner.scan(resourcesURL: resourcesURL)
        sites = discoveredSites

        if let selectedSiteID, discoveredSites.contains(where: { $0.id == selectedSiteID }) {
            return
        }

        selectedSiteID = discoveredSites.first?.id
        probeSelectedSite()
    }

    private func startServer(resourcesURL: URL) {
        do {
            serverBaseURL = try server.start(resourcesURL: resourcesURL)
            probeSelectedSite()
        } catch {
            serverBaseURL = nil
            errorMessage = "Could not start local server: \(error.localizedDescription)"
        }
    }

    private func startMonitoring(resourcesURL: URL) {
        directoryMonitor = DirectoryMonitor(url: resourcesURL) { [weak self] in
            Task { @MainActor in
                self?.reload()
            }
        }
        directoryMonitor?.start()
    }

    private func probeSelectedSite() {
        guard let currentURL else {
            serverProbeMessage = nil
            return
        }

        serverProbeMessage = "Checking \(currentURL.absoluteString)"

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(from: currentURL)
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                await MainActor.run {
                    self.serverProbeMessage = "Server \(statusCode.map(String.init) ?? "OK"): \(currentURL.absoluteString)"
                }
            } catch {
                await MainActor.run {
                    self.serverProbeMessage = "Server check failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
