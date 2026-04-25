//
//  OrderRowView.swift
//  Sortala
//

import SwiftUI

// MARK: - OrderRowView

struct OrderRowView: View {
    let order: Order
    var showStatus: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Level 1: Customer name + status
            HStack {
                Text(order.customerName.isEmpty ? "Tanpa Nama" : order.customerName)
                    .font(.headline)
                Spacer()
                if showStatus {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(order.status.foregroundColor)
                            .frame(width: 6, height: 6)
                        Text(order.status.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 76, alignment: .leading)
                }
            }

            Text(order.itemsSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Level 3: Deadline + Source (left-grouped), Spacer on right
            HStack(spacing: 8) {
                deadlineIndicator

                HStack(spacing: 4) {
                    Image(systemName: order.orderSource.icon)
                    Text(order.orderSource.rawValue)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Spacer()
            }
        }
    }

    private var deadlineIndicator: some View {
        HStack(spacing: 4) {
            if order.isOverdue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                Text("Terlambat")
                    .font(.caption)
                    .fontWeight(.semibold)
            } else if order.isDueToday {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                Text("Hari ini · \(order.deadline.timeFormatted)")
                    .font(.caption)
                    .fontWeight(.medium)
            } else {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(order.deadline.timeFormatted)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .foregroundStyle(deadlineColor)
    }

    private var deadlineColor: Color {
        if order.isOverdue { return .red }
        if order.isDueToday { return .teal }
        return .secondary
    }
}
