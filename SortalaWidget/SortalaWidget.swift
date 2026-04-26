//
//  SortalaWidget.swift
//  SortalaWidget
//
//  Small widget (systemSmall) — deadline counter at a glance.
//  Shows count of orders due today + overdue, with a warning
//  indicator when orders are past their deadline.
//
//  Replaces the Xcode template file.

import SwiftUI
import WidgetKit

// MARK: - Small Widget View

/// The `systemSmall` widget — a single glanceable metric.
///
/// Displays the number of orders due today + overdue as a large number,
/// with an optional overdue warning. Empty state shows a reassuring
/// checkmark when there are no pending deadlines.
struct SmallWidgetView: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let entry: OrderWidgetEntry

    /// The primary count: active orders due today or already overdue.
    private var urgentCount: Int {
        entry.attentionCount
    }

    private var warningColor: Color {
        widgetRenderingMode == .fullColor ? .red : .primary
    }

    var body: some View {
        if entry.activeCount == 0 {
            emptyState
        } else {
            normalState
        }
    }

    // MARK: - Normal State

    private var normalState: some View {
        VStack(alignment: .leading, spacing: 4) {
            // App identity
            HStack(spacing: 4) {
                Image(systemName: "shippingbox.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .widgetAccentable()
                Text("Sortala")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            // Primary metric — large count
            Text("\(urgentCount)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .widgetAccentable()

            Text("perlu diproses")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            // Overdue warning (conditional)
            if entry.overdueCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("\(entry.overdueCount) terlambat")
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(warningColor)
                .widgetAccentable()
            }

            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)
                .widgetAccentable()

            Text("Semua aman")
                .font(.callout)
                .fontWeight(.medium)

            Text("Tidak ada deadline")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Widget Definition

/// The small deadline-counter widget.
struct SortalaSmallWidget: Widget {
    let kind = SortalaWidgetKind.small

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OrderTimelineProvider()) { entry in
            SmallWidgetView(entry: entry)
                .widgetURL(URL(string: "sortala://home"))
        }
        .configurationDisplayName("Deadline Hari Ini")
        .description("Lihat jumlah pesanan yang deadline hari ini.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    SortalaSmallWidget()
} timeline: {
    OrderWidgetEntry.placeholder
    OrderWidgetEntry.empty
}
