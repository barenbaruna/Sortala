//
//  MediumWidgetView.swift
//  SortalaWidget
//
//  Medium widget (systemMedium) — shows up to 3 upcoming orders.
//  Each row mirrors OrderRowView typography for Gestalt similarity.
//  Rows are Link elements for per-order deep linking.

import SwiftUI
import WidgetKit

// MARK: - Medium Widget View

/// The `systemMedium` widget — a compact order list.
///
/// Shows the 3 nearest-deadline active orders with name, items summary,
/// and deadline. Each row links directly to its order detail in the app.
struct MediumWidgetView: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let entry: OrderWidgetEntry

    private var warningColor: Color {
        widgetRenderingMode == .fullColor ? .red : .primary
    }

    private var todayColor: Color {
        widgetRenderingMode == .fullColor ? .teal : .primary
    }

    var body: some View {
        if entry.upcomingOrders.isEmpty {
            emptyState
        } else {
            orderList
        }
    }

    // MARK: - Order List

    private var orderList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "shippingbox.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .widgetAccentable()
                Text("Sortala")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.activeCount) pesanan aktif")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            // Order rows
            ForEach(entry.upcomingOrders) { order in
                Link(destination: URL(string: "sortala://order/\(order.id.uuidString)")!) {
                    orderRow(order)
                }

                if order.id != entry.upcomingOrders.last?.id {
                    Divider()
                }
            }

            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    /// A single order row — mirrors `OrderRowView` typography.
    private func orderRow(_ order: OrderSnapshot) -> some View {
        HStack {
            // Status dot
            Circle()
                .fill(deadlineColor(for: order))
                .frame(width: 6, height: 6)
                .widgetAccentable(order.isOverdue || order.isDueToday)

            // Name + items
            VStack(alignment: .leading, spacing: 1) {
                Text(order.customerName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(order.itemsSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Deadline label
            deadlineLabel(for: order)
        }
        .padding(.vertical, 4)
    }

    /// Deadline text with semantic color.
    private func deadlineLabel(for order: OrderSnapshot) -> some View {
        Group {
            if order.isOverdue {
                Text("Terlambat")
                    .fontWeight(.semibold)
                    .foregroundStyle(warningColor)
                    .widgetAccentable()
            } else if order.isDueToday {
                Text("Hari ini · \(order.deadline.timeFormatted)")
                    .fontWeight(.medium)
                    .foregroundStyle(todayColor)
                    .widgetAccentable()
            } else {
                Text(order.deadline.relativeFormatted)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    /// The status dot color — matches `StatusHelpers` semantics.
    private func deadlineColor(for order: OrderSnapshot) -> Color {
        if widgetRenderingMode != .fullColor {
            return order.isOverdue || order.isDueToday ? .primary : .secondary
        }
        if order.isOverdue { return .red }
        if order.isDueToday { return .teal }
        return Color(.tertiaryLabel)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()

            Image(systemName: "list.clipboard")
                .font(.title2)
                .foregroundStyle(.secondary)
                .widgetAccentable()

            Text("Tidak ada pesanan aktif")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Tap untuk buat pesanan baru")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Widget Definition

/// The medium order-list widget.
struct SortalaMediumWidget: Widget {
    let kind = SortalaWidgetKind.medium

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OrderTimelineProvider()) { entry in
            MediumWidgetView(entry: entry)
                .widgetURL(URL(string: entry.upcomingOrders.isEmpty ? "sortala://add" : "sortala://home"))
        }
        .configurationDisplayName("Pesanan Mendatang")
        .description("Lihat 3 pesanan terdekat dengan deadline-nya.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    SortalaMediumWidget()
} timeline: {
    OrderWidgetEntry.placeholder
    OrderWidgetEntry.empty
}
