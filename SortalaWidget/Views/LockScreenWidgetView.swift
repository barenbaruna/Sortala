//
//  LockScreenWidgetView.swift
//  SortalaWidget
//
//  Lock Screen widgets — the highest-value surface for business owners.
//  Glanceable without even unlocking the phone.
//
//  Supports two accessory families:
//  - accessoryRectangular: 3-line text summary
//  - accessoryCircular: count gauge

import SwiftUI
import WidgetKit

// MARK: - Lock Screen Entry View

/// Dispatches to the correct layout based on the current widget family.
struct LockScreenEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: OrderWidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        default:
            LockScreenRectangularView(entry: entry)
        }
    }
}

// MARK: - Rectangular Lock Screen Widget

/// Lock Screen rectangular widget — 3 lines of text.
///
/// Line 1: Order count summary
/// Line 2: Overdue warning (if any)
/// Line 3: Next deadline time
struct LockScreenRectangularView: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let entry: OrderWidgetEntry

    private var warningColor: Color {
        widgetRenderingMode == .fullColor ? .red : .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Line 1: count
            HStack(spacing: 4) {
                Image(systemName: "shippingbox.fill")
                    .font(.caption)
                    .widgetAccentable()
                Text("\(entry.dueTodayCount) pesanan hari ini")
                    .font(.headline)
                    .widgetAccentable()
            }

            // Line 2: overdue or all clear
            if entry.overdueCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("\(entry.overdueCount) terlambat")
                }
                .font(.caption)
                .foregroundStyle(warningColor)
                .widgetAccentable()
            } else if entry.activeCount > 0 {
                Label("Semua tepat waktu", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Line 3: next deadline
            if let next = entry.nextDeadline {
                Text("Selanjutnya: \(next.relativeFormatted) · \(next.timeFormatted)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }
}

// MARK: - Circular Lock Screen Widget

/// Lock Screen circular widget — order count.
///
/// Shows the active order count as a simple number inside a
/// circular background. Minimal and glanceable.
struct LockScreenCircularView: View {
    let entry: OrderWidgetEntry

    var body: some View {
        VStack(spacing: 0) {
            Text("\(entry.activeCount)")
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .widgetAccentable()

            Image(systemName: "shippingbox.fill")
                .font(.caption)
                .widgetAccentable()
        }
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }
}

// MARK: - Widget Definition

/// Lock Screen widget supporting rectangular and circular families.
struct SortalaLockScreenWidget: Widget {
    let kind = SortalaWidgetKind.lockScreen

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OrderTimelineProvider()) { entry in
            LockScreenEntryView(entry: entry)
                .widgetURL(URL(string: "sortala://home"))
        }
        .configurationDisplayName("Sortala")
        .description("Pesanan aktif di Lock Screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    SortalaLockScreenWidget()
} timeline: {
    OrderWidgetEntry.placeholder
}
