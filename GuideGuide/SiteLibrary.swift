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
    private let searchPathStore: SearchPathStore
    private var directoryMonitors: [DirectoryMonitor] = []
    private var cancellables: Set<AnyCancellable> = []

    init(searchPathStore: SearchPathStore) {
        self.searchPathStore = searchPathStore

        searchPathStore.$searchPaths
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.openConfiguredSearchPaths()
                }
            }
            .store(in: &cancellables)
    }

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
        openConfiguredSearchPaths()
    }

    func showFolderPicker() {
        isChoosingFolder = true
    }

    func handleFolderPicker(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            searchPathStore.add(url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func reload() {
        openConfiguredSearchPaths()
    }

    private func openConfiguredSearchPaths() {
        let resourcesURLs = searchPathStore.resourcesURLs

        guard !resourcesURLs.isEmpty else {
            errorMessage = searchPathStore.searchPaths.isEmpty ? nil : "No configured search path contains HTML site folders."
            resourcesURL = nil
            sites = []
            selectedSiteID = nil
            server.stop()
            serverBaseURL = nil
            stopMonitoring()
            return
        }

        resourcesURL = resourcesURLs.first
        errorMessage = nil
        scan(resourcesURLs: resourcesURLs)
        startServer(resourcesURLs: resourcesURLs)
        startMonitoring(resourcesURLs: resourcesURLs)
        probeSelectedSite()
    }

    private func scan(resourcesURLs: [URL]) {
        let discoveredSites = SiteScanner.scan(resourcesURLs: resourcesURLs)
        sites = discoveredSites

        if let selectedSiteID, discoveredSites.contains(where: { $0.id == selectedSiteID }) {
            return
        }

        selectedSiteID = discoveredSites.first?.id
        probeSelectedSite()
    }

    private func startServer(resourcesURLs: [URL]) {
        do {
            serverBaseURL = try server.start(resourcesURLs: resourcesURLs)
            probeSelectedSite()
        } catch {
            serverBaseURL = nil
            errorMessage = "Could not start local server: \(error.localizedDescription)"
        }
    }

    private func startMonitoring(resourcesURLs: [URL]) {
        stopMonitoring()

        directoryMonitors = resourcesURLs.map { resourcesURL in
            DirectoryMonitor(url: resourcesURL) { [weak self] in
                Task { @MainActor in
                    self?.reload()
                }
            }
        }

        for monitor in directoryMonitors {
            monitor.start()
        }
    }

    private func stopMonitoring() {
        for monitor in directoryMonitors {
            monitor.stop()
        }
        directoryMonitors = []
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
