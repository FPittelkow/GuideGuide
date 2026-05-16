//
//  GuideGuideApp.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import SwiftUI
import CoreData

@main
struct GuideGuideApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
