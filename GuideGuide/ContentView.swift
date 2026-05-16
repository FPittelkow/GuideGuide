//
//  ContentView.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct ContentView: View {
    @StateObject private var library: SiteLibrary

    init(searchPathStore: SearchPathStore) {
        _library = StateObject(wrappedValue: SiteLibrary(searchPathStore: searchPathStore))
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $library.selectedSiteID) {
                Section("Sites") {
                    ForEach(library.filteredSites) { site in
                        SiteSidebarRow(site: site)
                            .tag(site.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("GuideGuide")
            .safeAreaInset(edge: .bottom) {
                LibraryStatusView(library: library)
            }
        } detail: {
            DetailView(library: library)
        }
        .searchable(text: $library.searchText, prompt: "Search sites")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    library.reload()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }

                Button {
                    library.showFolderPicker()
                } label: {
                    Label("Choose Folder", systemImage: "folder")
                }
            }
        }
        .containerBackground(.thinMaterial, for: .window)
        .toolbarBackgroundVisibility(
            .hidden, for: .windowToolbar
        )
        .fileImporter(
            isPresented: $library.isChoosingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            library.handleFolderPicker(result)
        }
        .task {
            library.bootstrap()
        }
    }
}

private struct SiteSidebarRow: View {
    let site: SiteFolder

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(site.displayName)
                    .lineLimit(1)
                Text(site.routeComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: "doc.richtext")
                .symbolRenderingMode(.hierarchical)
        }
    }
}

private struct DetailView: View {
    @ObservedObject var library: SiteLibrary

    var body: some View {
        ZStack {
            if let url = library.currentURL {
                WebContentView(url: url)
                    .id(url)
                    .ignoresSafeArea(.container, edges: .bottom)
            } else {
                EmptyHubView {
                    library.showFolderPicker()
                }
            }
        }
        .navigationTitle(library.selectedSite?.displayName ?? "Hub")
    }
}

private struct EmptyHubView: View {
    let chooseFolder: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 44, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Choose a Folder")
                    .font(.title2.weight(.semibold))
                Text("Select folder A or its Resources folder to build the local hub.")
                    .foregroundStyle(.secondary)
            }

            Button(action: chooseFolder) {
                Label("Choose Folder", systemImage: "folder")
            }
            .buttonStyle(.glassProminent)
        }
        .padding(34)
        .guideGlassSurface(cornerRadius: 28)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct LibraryStatusView: View {
    @ObservedObject var library: SiteLibrary

    var body: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 4) {
                Label(statusTitle, systemImage: statusImage)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .guideGlassSurface(cornerRadius: 16, shadow: false)
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
    }

    private var statusTitle: String {
        if library.resourcesURL == nil {
            "No Library"
        } else if library.serverBaseURL == nil {
            "Starting Server"
        } else {
            "\(library.sites.count) Site\(library.sites.count == 1 ? "" : "s")"
        }
    }

    private var statusDetail: String {
        if let errorMessage = library.errorMessage {
            errorMessage
        } else if let serverProbeMessage = library.serverProbeMessage {
            serverProbeMessage
        } else if let resourcesURL = library.resourcesURL {
            resourcesURL.path(percentEncoded: false)
        } else {
            "Local HTML folders will appear here."
        }
    }

    private var statusImage: String {
        library.resourcesURL == nil ? "folder.badge.questionmark" : "network"
    }
}

private struct WebContentView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showError(error, in: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showError(error, in: webView)
        }

        private func showError(_ error: Error, in webView: WKWebView) {
            let message = """
            <!doctype html>
            <html>
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <style>
                :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; }
                body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: Canvas; color: CanvasText; }
                main { max-width: 640px; padding: 32px; }
                h1 { font-size: 22px; margin: 0 0 10px; }
                p { color: color-mix(in srgb, CanvasText 72%, transparent); line-height: 1.45; }
                code { overflow-wrap: anywhere; }
              </style>
            </head>
            <body>
              <main>
                <h1>The site could not load</h1>
                <p><code>\(error.localizedDescription.htmlEscaped)</code></p>
              </main>
            </body>
            </html>
            """
            webView.loadHTMLString(message, baseURL: nil)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(searchPathStore: .shared)
    }
}
