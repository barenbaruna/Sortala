//
//  SortalaApp.swift
//  Sortala
//

import SwiftData
import SwiftUI

@main
struct SortalaApp: App {
    var sharedModelContainer: ModelContainer = Self.makeSharedContainer()

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

    // MARK: - Container Setup

    /// Builds a ModelContainer backed by the App Group shared directory.
    /// This enables the Share Extension to read/write the same store.
    /// Includes a one-time migration of any legacy default.store.
    private static func makeSharedContainer() -> ModelContainer {
        let schema = Schema([Order.self, OrderItem.self])
        let groupID = "group.com.barenbaruna.Sortala"
        let fm = FileManager.default

        // Resolve the App Group shared directory
        guard let groupURL = fm.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        ) else {
            // App Group capability not yet added in Xcode — fail fast with
            // a clear message so the developer knows exactly what to fix.
            fatalError(
                """
                App Group '\(groupID)' unavailable.
                In Xcode: Target → Signing & Capabilities → + App Groups → group.com.barenbaruna.Sortala
                """
            )
        }

        let sharedStoreURL = groupURL.appendingPathComponent("Sortala.sqlite")

        // One-time migration: move the legacy default.store to the shared location.
        // This preserves existing user data after the App Group migration.
        migrateStoreIfNeeded(fm: fm, destination: sharedStoreURL)

        let config = ModelConfiguration(schema: schema, url: sharedStoreURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// Moves the legacy SwiftData store (default.store) to the shared App Group
    /// container if it has not been migrated yet. Non-fatal on failure — user
    /// starts with an empty store rather than a crashed app.
    private static func migrateStoreIfNeeded(fm: FileManager, destination: URL) {
        guard !fm.fileExists(atPath: destination.path) else { return }

        let legacyCandidates: [URL] = [
            fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?.appendingPathComponent("default.store"),
            fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?.appendingPathComponent("Sortala.sqlite"),
        ].compactMap { $0 }

        for legacy in legacyCandidates where fm.fileExists(atPath: legacy.path) {
            do {
                try fm.moveItem(at: legacy, to: destination)
                return // Successfully migrated — stop checking
            } catch {
                // Non-fatal: log and continue; user will have a fresh store
                print("⚠️ Sortala: Store migration failed (\(legacy.lastPathComponent)): \(error.localizedDescription)")
            }
        }
    }
}
