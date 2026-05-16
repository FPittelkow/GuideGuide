//
//  GuideGuideApp.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import SwiftUI
import AppKit

@main
struct GuideGuideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var searchPathStore = SearchPathStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView(searchPathStore: searchPathStore)
                .environmentObject(searchPathStore)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(searchPathStore)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
