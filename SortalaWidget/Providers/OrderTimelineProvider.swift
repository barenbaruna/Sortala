//
//  OrderTimelineProvider.swift
//  SortalaWidget
//
//  Timeline strategy for WidgetKit. Delegates all data fetching to
//  OrderWidgetDataService and focuses solely on when to refresh.

import WidgetKit

/// Provides timeline entries to WidgetKit using smart refresh scheduling.
///
/// Refresh triggers:
/// - **Automatic**: at the next order deadline or midnight (computed by data service)
/// - **Manual**: when the app calls `WidgetCenter.shared.reloadTimelines(ofKind:)`
///   after saving, deleting, or advancing an order
struct OrderTimelineProvider: TimelineProvider {
    private let dataService = OrderWidgetDataService()

    /// Placeholder shown in the widget gallery — uses sample data.
    func placeholder(in context: Context) -> OrderWidgetEntry {
        .placeholder
    }

    /// Snapshot for quick preview — fetches real data unless in preview mode.
    func getSnapshot(in context: Context, completion: @escaping (OrderWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(dataService.fetchEntry())
        }
    }

    /// Generates the timeline with smart refresh scheduling.
    ///
    /// Instead of a fixed interval, the next refresh is set to the earliest
    /// meaningful event: the next order deadline or midnight.
    func getTimeline(in context: Context, completion: @escaping (Timeline<OrderWidgetEntry>) -> Void) {
        let entry = dataService.fetchEntry()
        let nextRefresh = dataService.nextRefreshDate(after: Date())
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}
