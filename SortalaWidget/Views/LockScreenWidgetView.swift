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
    let entry: OrderWidgetEntry

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            // Left: Big number
            Text("\(entry.attentionCount)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .widgetAccentable()
            
            // Right: Details
            VStack(alignment: .leading, spacing: 1) {
                Text("Prioritas")
                    .font(.headline)
                    .widgetAccentable()
                
                if entry.overdueCount > 0 {
                    Text("\(entry.overdueCount) telat")
                        .font(.caption)
                } else if let next = entry.nextDeadline {
                    Text(next.timeFormatted)
                        .font(.caption)
                } else {
                    Text("Aman ✓")
                        .font(.caption)
                }
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
        Gauge(value: Double(entry.attentionCount), in: 0...Double(max(1, entry.activeCount))) {
            Image(systemName: "shippingbox.fill")
        } currentValueLabel: {
            Text("\(entry.attentionCount)")
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
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
