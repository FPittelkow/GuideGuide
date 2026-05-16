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
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    List(selection: $selection) {
                        ForEach(searchPathStore.searchPaths) { searchPath in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(searchPath.displayName)
                                    .lineLimit(1)
                                Text(searchPath.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .tag(searchPath.id)
                        }
                    }
                    .frame(minHeight: 180)

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
                }
            } header: {
                Text("Search Paths")
            } footer: {
                Text("Each folder can be folder A, a Resources folder, or any folder containing site subfolders.")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 560, height: 360)
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
