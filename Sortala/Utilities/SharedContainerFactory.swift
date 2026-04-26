//
//  SharedContainerFactory.swift
//  Sortala
//
//  Single factory for creating the shared ModelContainer.
//  Used by ALL three targets (App, Share Extension, Widget) to ensure
//  they all point to the same SQLite store in the App Group container.
//
//  This eliminates the duplicated `makeSharedContainer()` logic that
//  previously existed in SortalaApp.swift and ShareExtensionViewController.swift.

import Foundation
import SwiftData

/// Centralised container factory shared across App, Share Extension, and Widget.
///
/// Both read-write (app, extension) and read-only (widget) containers
/// are created from the same App Group URL, ensuring data consistency.
enum SharedContainerFactory {
    /// The App Group identifier shared across all targets.
    static let appGroupID = "group.com.barenbaruna.Sortala"

    /// The SQLite filename within the App Group container.
    private static let storeName = "Sortala.sqlite"

    /// The shared schema used by all targets.
    static let schema = Schema([Order.self, OrderItem.self])

    /// Creates a `ModelContainer` pointing to the App Group shared store.
    ///
    /// - Parameter readOnly: Pass `true` for Widget Extension to prevent
    ///   SQLite write conflicts across processes. Default is `false`.
    /// - Returns: A configured `ModelContainer`.
    static func makeContainer(readOnly: Bool = false) -> ModelContainer {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError(
                """
                App Group '\(appGroupID)' unavailable.
                In Xcode: Target → Signing & Capabilities → + App Groups → \(appGroupID)
                """
            )
        }

        let storeURL = groupURL.appendingPathComponent(storeName)
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: !readOnly
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
