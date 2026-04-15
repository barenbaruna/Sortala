//
//  HomeView.swift
//  Sortala
//

import SwiftData
import SwiftUI

// MARK: - OrderFilter

/// Maps directly to OrderStatus for filtering, plus "Semua" for all orders.
enum OrderFilter: String, CaseIterable {
    case semua = "Semua"
    case baru = "Baru"
    case diproses = "Diproses"
    case selesai = "Selesai"

    /// Returns the matching OrderStatus, or nil for .semua.
    var matchingStatus: OrderStatus? {
        switch self {
        case .semua: return nil
        case .baru: return .baru
        case .diproses: return .diproses
        case .selesai: return .selesai
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Query(sort: \Order.deadline, order: .forward)
    private var allOrders: [Order]

    @Environment(\.modelContext) private var modelContext

    @State private var selectedFilter: OrderFilter = .semua
    @State private var searchText: String = ""
    @State private var showAddOrder = false
    @State private var orderToDelete: Order?

    // MARK: Filtering

    private var filteredOrders: [Order] {
        var orders = allOrders

        if let status = selectedFilter.matchingStatus {
            orders = orders.filter { $0.status == status }
        }

        if !searchText.isEmpty {
            orders = orders.filter { order in
                order.customerName.localizedCaseInsensitiveContains(searchText) ||
                    order.items.contains {
                        $0.productName.localizedCaseInsensitiveContains(searchText)
                    }
            }
        }

        return orders
    }

    /// Groups filtered orders by deadline date for section headers.
    private var groupedOrders: [(date: Date, orders: [Order])] {
        let grouped = Dictionary(grouping: filteredOrders) { $0.deadline.dateOnlyKey }
        return grouped.sorted { $0.key < $1.key }
            .map { (date: $0.key, orders: $0.value) }
    }

    /// Whether to show status badge on each card (only in "Semua" tab).
    private var showStatusBadge: Bool {
        selectedFilter == .semua
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                if !allOrders.isEmpty {
                    filterSection
                    orderSections
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pre-Orders")
            .overlay { emptyStateView }
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: "Cari nama atau produk…"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddOrder = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddOrder) {
                OrderFormView()
            }
            .alert("Hapus Pesanan?", isPresented: Binding(
                get: { orderToDelete != nil },
                set: { if !$0 { orderToDelete = nil } }
            )) {
                Button("Hapus", role: .destructive) {
                    if let order = orderToDelete {
                        modelContext.delete(order)
                    }
                    orderToDelete = nil
                }
                Button("Batal", role: .cancel) { orderToDelete = nil }
            } message: {
                Text("Pesanan \(orderToDelete?.customerName ?? "") akan dihapus permanen.")
            }
        }
    }

    // MARK: - Subviews

    private var filterSection: some View {
        Section {
            VStack(spacing: 10) {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(OrderFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                orderCountSummary
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    private var orderCountSummary: some View {
        HStack {
            // Neutral count — no colored status text
            if selectedFilter == .semua {
                Text("\(allOrders.count) pesanan")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(filteredOrders.count) pesanan")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Overdue = ONLY non-neutral color (red = danger)
            let overdueCount = allOrders.filter(\.isOverdue).count
            if overdueCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("\(overdueCount) terlambat")
                        .font(.footnote)
                }
                .foregroundStyle(.red)
            }
        }
    }

    private var orderSections: some View {
        ForEach(groupedOrders, id: \.date) { group in
            Section {
                ForEach(group.orders) { order in
                    NavigationLink(destination: OrderDetailView(order: order)) {
                        OrderRowView(order: order, showStatus: showStatusBadge)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            orderToDelete = order
                        } label: {
                            Label("Hapus", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text(group.date.sectionHeaderFormatted)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(sectionHeaderColor(for: group.date))
                    .textCase(nil)
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if allOrders.isEmpty {
            ContentUnavailableView {
                    Label("Belum Ada Pesanan", systemImage: "tray")
                } description: {
                    Text("Mulai catat pesanan pertama kamu")
                } actions: {
                    Button("Tambah Pesanan") {
                        showAddOrder = true
                    }
                    .buttonStyle(.borderedProminent)
                }
        } else if filteredOrders.isEmpty && !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if filteredOrders.isEmpty {
            ContentUnavailableView(
                "Tidak Ada Pesanan",
                systemImage: "tray",
                description: Text("Belum ada pesanan dengan status \(selectedFilter.rawValue)")
            )
        }
    }

    // MARK: - Helpers

    private func sectionHeaderColor(for date: Date) -> Color {
        let calendar = Calendar.current
        if date < calendar.startOfDay(for: Date()) { return .red }
        return .primary
    }
}

// MARK: - OrderRowView

struct OrderRowView: View {
    let order: Order
    var showStatus: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                }
            }

            HStack(spacing: 4) {
                Image(systemName: order.orderSource.icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(order.itemsSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Order.self, OrderItem.self], inMemory: true)
}
