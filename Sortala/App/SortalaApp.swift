//
//  SortalaApp.swift
//  Sortala
//

import SwiftData
import SwiftUI

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
            AnimatedSplashView()
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didBecomeActiveNotification
                    )
                ) { _ in
                    NotificationManager.clearBadge()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
