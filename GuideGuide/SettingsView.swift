//
//  SettingsView.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var searchPathStore: SearchPathStore
    @State private var isChoosingSearchPath = false
    @State private var selection: SearchPath.ID?

    var body: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Paths")
                        .font(.title3.weight(.semibold))
                    Text("GuideGuide scans these folders for local HTML sites.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    List(selection: $selection) {
                        ForEach(searchPathStore.searchPaths) { searchPath in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(searchPath.displayName)
                                        .lineLimit(1)
                                    Text(searchPath.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            } icon: {
                                Image(systemName: "folder")
                                    .symbolRenderingMode(.hierarchical)
                            }
                            .tag(searchPath.id)
                        }
                    }
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)

                    HStack {
                        Button {
                            isChoosingSearchPath = true
                        } label: {
                            Label("Add", systemImage: "plus")
                        }

                        Button {
                            removeSelection()
                        } label: {
                            Label("Remove", systemImage: "minus")
                        }
                        .disabled(selection == nil)

                        Spacer()
                    }
                    .controlSize(.regular)
                }
                .padding(16)
                .guideGlassSurface(cornerRadius: 22)

                Text("Each folder can be folder A, a Resources folder, or any folder containing site subfolders.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(22)
        }
        .frame(width: 560, height: 360)
        .containerBackground(.thinMaterial, for: .window)
        .toolbarBackgroundVisibility(
            .hidden, for: .windowToolbar
        )
        .fileImporter(
            isPresented: $isChoosingSearchPath,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls {
                    searchPathStore.add(url)
                }
            }
        }
    }

    private func removeSelection() {
        guard let selection,
              let searchPath = searchPathStore.searchPaths.first(where: { $0.id == selection }) else {
            return
        }

        searchPathStore.remove(searchPath)
        self.selection = nil
    }
}
