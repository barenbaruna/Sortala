//
//  SortalaApp.swift
//  Sortala
//
//  Main app entry point. Uses SharedContainerFactory for the ModelContainer
//  and handles deep links from widgets via .onOpenURL.

import SwiftData
import SwiftUI

@main
struct SortalaApp: App {
    var sharedModelContainer: ModelContainer = Self.makeSharedContainer()

    /// The order ID received from a widget deep link, used to navigate to detail.
    @State private var deepLinkedOrderID: UUID?
    @State private var shouldPresentAddOrder = false

    var body: some Scene {
        WindowGroup {
            AnimatedSplashView(
                deepLinkedOrderID: $deepLinkedOrderID,
                shouldPresentAddOrder: $shouldPresentAddOrder
            )
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didBecomeActiveNotification
                    )
                ) { _ in
                    NotificationManager.clearBadge()
                }
                .onOpenURL { url in
                    handleWidgetDeepLink(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Container Setup

    /// Builds a `ModelContainer` backed by the App Group shared directory.
    ///
    /// Uses `SharedContainerFactory` for the container, but keeps the
    /// one-time legacy migration here since only the main app needs it.
    private static func makeSharedContainer() -> ModelContainer {
        let fm = FileManager.default
        let groupID = SharedContainerFactory.appGroupID

        // Resolve the shared store URL for migration check
        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            let sharedStoreURL = groupURL.appendingPathComponent("Sortala.sqlite")
            migrateStoreIfNeeded(fm: fm, destination: sharedStoreURL)
        }

        return SharedContainerFactory.makeContainer()
    }

    // MARK: - Deep Link Handling

    /// Handles URLs from widget taps.
    ///
    /// Supported schemes:
    /// - `sortala://home` → opens HomeView (default)
    /// - `sortala://add` → opens the new order sheet
    /// - `sortala://order/{uuid}` → opens OrderDetailView for that order
    private func handleWidgetDeepLink(_ url: URL) {
        guard url.scheme == "sortala" else { return }

        switch url.host {
        case "add":
            shouldPresentAddOrder = true
        case "order":
            // Extract UUID from path: sortala://order/{uuid}
            let uuidString = url.pathComponents.dropFirst().first ?? ""
            deepLinkedOrderID = UUID(uuidString: uuidString)
        default:
            // "home" or unknown → just open app (default behavior)
            break
        }
    }

    // MARK: - Legacy Migration

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
                return
            } catch {
                print("⚠️ Sortala: Store migration failed (\(legacy.lastPathComponent)): \(error.localizedDescription)")
            }
        }
    }
}
