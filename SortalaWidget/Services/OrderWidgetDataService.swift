//
//  OrderWidgetDataService.swift
//  SortalaWidget
//
//  Pure data service for the widget — no SwiftUI imports, no view logic.
//  Fetches Order data from the shared SwiftData store and transforms it
//  into lightweight OrderSnapshot values for the timeline provider.

import Foundation
import os
import SwiftData

/// Fetches and transforms order data for widget display.
///
/// Separated from the `TimelineProvider` to maintain clean architecture:
/// - `OrderWidgetDataService` → data layer (testable, no WidgetKit dependency)
/// - `OrderTimelineProvider` → timeline strategy (refresh policy)
/// - Widget Views → pure rendering
struct OrderWidgetDataService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.barenbaruna.Sortala",
        category: "WidgetData"
    )

    private let container: ModelContainer

    init(container: ModelContainer = SharedContainerFactory.makeContainer(readOnly: true)) {
        self.container = container
    }

    // MARK: - Data Fetching

    /// Fetches current order statistics and the 3 nearest upcoming orders.
    ///
    /// Uses a single `FetchDescriptor` for efficiency — widget memory
    /// budget is 30 MB, so we avoid multiple queries.
    func fetchEntry() -> OrderWidgetEntry {
        let context = ModelContext(container)
        let now = Date()

        let orders: [Order]
        do {
            orders = try fetchActiveOrders(in: context)
        } catch {
            Self.logger.error("Failed to fetch widget orders: \(error.localizedDescription)")
            return .empty(date: now)
        }

        let calendar = Calendar.current
        let overdue = orders.filter { $0.deadline < now }
        let dueToday = orders.filter { calendar.isDateInToday($0.deadline) }
        let needsAttention = orders.filter {
            $0.deadline < now || calendar.isDateInToday($0.deadline)
        }

        let snapshots = orders.prefix(3).map { order in
            OrderSnapshot(
                id: order.id,
                customerName: order.customerName.isEmpty ? "Tanpa Nama" : order.customerName,
                itemsSummary: order.itemsSummary,
                deadline: order.deadline,
                statusRaw: order.status.rawValue,
                isDueToday: calendar.isDateInToday(order.deadline),
                isOverdue: order.deadline < now
            )
        }

        return OrderWidgetEntry(
            date: now,
            activeCount: orders.count,
            attentionCount: needsAttention.count,
            overdueCount: overdue.count,
            dueTodayCount: dueToday.count,
            upcomingOrders: Array(snapshots),
            nextDeadline: orders.first(where: { $0.deadline > now })?.deadline
        )
    }

    // MARK: - Smart Refresh

    /// Computes the next meaningful time the widget data would change.
    ///
    /// Instead of fixed 30-minute intervals, refreshes exactly when:
    /// 1. An order transitions from "on time" → "overdue" (its deadline time)
    /// 2. The "due today" set changes (at midnight)
    ///
    /// This minimises system resource usage while keeping data accurate.
    func nextRefreshDate(after now: Date) -> Date {
        let context = ModelContext(container)
        let orders: [Order]
        do {
            orders = try fetchActiveOrders(in: context)
        } catch {
            Self.logger.error("Failed to compute widget refresh date: \(error.localizedDescription)")
            return now.addingTimeInterval(3600)
        }

        // Next order that will become overdue
        let nextOverdue = orders.first(where: { $0.deadline > now })?.deadline

        // Next midnight (when "due today" set changes)
        let midnight = Calendar.current.startOfDay(for: now)
            .addingTimeInterval(86400)

        // Ceiling: max 1 hour from now (fallback if no orders)
        let ceiling = now.addingTimeInterval(3600)

        return [nextOverdue, midnight, ceiling]
            .compactMap { $0 }
            .min() ?? ceiling
    }

    private func fetchActiveOrders(in context: ModelContext) throws -> [Order] {
        let descriptor = FetchDescriptor<Order>(
            sortBy: [SortDescriptor(\Order.deadline, order: .forward)]
        )
        let allOrders = try context.fetch(descriptor)

        // Filter in memory to avoid fragile SwiftData enum predicates in extensions.
        return allOrders.filter { $0.status != .selesai }
    }
}
