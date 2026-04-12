//
//  HomeView.swift
//  Sortala
//

import SwiftUI
import SwiftData

// MARK: - OrderFilter

enum OrderFilter: String, CaseIterable {
    case semua   = "Semua"
    case hariIni = "Hari Ini"
    case aktif   = "Aktif"
}

// MARK: - HomeView

struct HomeView: View {

    @Query(sort: \Order.deadline, order: .forward)
    private var allOrders: [Order]

    @Environment(\.modelContext) private var modelContext

    @State private var selectedFilter: OrderFilter = .semua
    @State private var searchText: String = ""
    @State private var showAddOrder = false

    private var filteredOrders: [Order] {
        var orders = allOrders

        switch selectedFilter {
        case .semua:   break
        case .hariIni: orders = orders.filter { $0.isDueToday }
        case .aktif:   orders = orders.filter { $0.status != .selesai }
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

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                if !allOrders.isEmpty {
                    Section {
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(OrderFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                    Section {
                        ForEach(filteredOrders) { order in
                            NavigationLink(destination: OrderDetailView(order: order)) {
                                OrderRowView(order: order)
                            }
                        }
                        .onDelete(perform: deleteOrders)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pre-Orders")
            .overlay {
                if allOrders.isEmpty {
                    ContentUnavailableView(
                        "Belum Ada Pesanan",
                        systemImage: "tray",
                        description: Text("Tap + untuk menambahkan pesanan pertama")
                    )
                } else if filteredOrders.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: "Cari nama atau produk…"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddOrder = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddOrder) {
                OrderFormView()
            }
        }
    }

    // MARK: - Actions

    private func deleteOrders(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredOrders[index])
        }
    }
}

// MARK: - OrderRowView

struct OrderRowView: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(order.customerName.isEmpty ? "Tanpa Nama" : order.customerName)
                    .font(.headline)
                Spacer()
                Text(order.deadline.relativeFormatted)
                    .font(.caption)
                    .foregroundStyle(order.isOverdue ? .red : .secondary)
                    .fontWeight(order.isDueToday ? .semibold : .regular)
            }

            HStack(spacing: 4) {
                Image(systemName: order.orderSource.icon)
                    .font(.caption2)
                    .foregroundStyle(order.orderSource.color)
                Text(order.itemsSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Image(systemName: order.status.icon)
                    .font(.caption2)
                Text(order.status.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(order.status.backgroundColor, in: Capsule())
            .foregroundStyle(order.status.foregroundColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Order.self, OrderItem.self], inMemory: true)
}
