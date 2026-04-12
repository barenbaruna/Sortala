//
//  SortalaApp.swift
//  Sortala
//

import SwiftUI
import SwiftData

@main
struct SortalaApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Order.self, OrderItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
        .modelContainer(sharedModelContainer)
    }
}
