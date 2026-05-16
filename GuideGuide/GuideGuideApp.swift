//
//  GuideGuideApp.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import SwiftUI

@main
struct GuideGuideApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
