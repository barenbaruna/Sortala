//
//  OrderWidgetEntry.swift
//  SortalaWidget
//
//  Data structures for widget timeline entries.
//  Uses lightweight value types instead of @Model classes to avoid
//  ModelContext dependencies and ensure predictable performance.

import WidgetKit

// MARK: - Timeline Entry

/// The data snapshot that WidgetKit renders at a given point in time.
///
/// Each entry contains pre-computed statistics and a small list of
/// upcoming orders, keeping the widget view layer free of logic.
struct OrderWidgetEntry: TimelineEntry {
    let date: Date
    let activeCount: Int
    let attentionCount: Int
    let overdueCount: Int
    let dueTodayCount: Int
    let upcomingOrders: [OrderSnapshot]
    let nextDeadline: Date?

    /// Placeholder entry shown in the widget gallery and while loading.
    static let placeholder = OrderWidgetEntry(
        date: .now,
        activeCount: 3,
        attentionCount: 2,
        overdueCount: 0,
        dueTodayCount: 2,
        upcomingOrders: [
            .init(
                id: UUID(),
                customerName: "Zahra Nur",
                itemsSummary: "2x Brownies · 1x Kue Keju",
                deadline: Date(),
                statusRaw: "Baru",
                isDueToday: true,
                isOverdue: false
            ),
            .init(
                id: UUID(),
                customerName: "Ahmad Reza",
                itemsSummary: "3x Tart Strawberry",
                deadline: Date().addingTimeInterval(86400),
                statusRaw: "Baru",
                isDueToday: false,
                isOverdue: false
            ),
        ],
        nextDeadline: Date().addingTimeInterval(3600)
    )

    /// Empty entry — no active orders.
    static let empty = OrderWidgetEntry(
        date: .now,
        activeCount: 0,
        attentionCount: 0,
        overdueCount: 0,
        dueTodayCount: 0,
        upcomingOrders: [],
        nextDeadline: nil
    )

    static func empty(date: Date) -> OrderWidgetEntry {
        OrderWidgetEntry(
            date: date,
            activeCount: 0,
            attentionCount: 0,
            overdueCount: 0,
            dueTodayCount: 0,
            upcomingOrders: [],
            nextDeadline: nil
        )
    }
}

// MARK: - Order Snapshot

/// Lightweight, immutable copy of an `Order` for the widget.
///
/// Widget process is separate from app process — cannot share `@Model`
/// objects directly. This struct captures only the fields the widget
/// needs, pre-computed at fetch time for zero-overhead rendering.
struct OrderSnapshot: Identifiable, Sendable {
    let id: UUID
    let customerName: String
    let itemsSummary: String
    let deadline: Date
    let statusRaw: String
    let isDueToday: Bool
    let isOverdue: Bool

    /// The `OrderStatus` value, derived from the raw string.
    var status: OrderStatus {
        OrderStatus(rawValue: statusRaw) ?? .baru
    }
}
