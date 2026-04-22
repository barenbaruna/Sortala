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
    @State private var showDeleteAlert = false
    @State private var orderToAdvance: Order?
    @State private var showAdvanceConfirm = false
    
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
            .overlay { emptyStateView }
            .navigationTitle("Pre-Orders")
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
                    .buttonStyle(.glassProminent)
                }
            }
            .sheet(isPresented: $showAddOrder) {
                OrderFormView()
            }
            .alert("Hapus Pesanan?", isPresented: $showDeleteAlert) {
                Button("Hapus", role: .destructive) {
                    if let order = orderToDelete {
                        NotificationManager.cancelReminder(for: order)
                        withAnimation {
                            modelContext.delete(order)
                        }
                        Task { await NotificationManager.updateEveningRadar(modelContext: modelContext) }
                    }
                    orderToDelete = nil
                }
                Button("Batal", role: .cancel) {
                    orderToDelete = nil
                }
            } message: {
                Text("Pesanan \(orderToDelete?.customerName ?? "") akan dihapus permanen.")
            }
            .alert("Ubah Status?", isPresented: $showAdvanceConfirm) {
                if let order = orderToAdvance, let next = order.status.nextStatus {
                    Button(next.rawValue) {
                        advanceStatus(of: order, to: next)
                    }
                    Button("Batal", role: .cancel) {
                        orderToAdvance = nil
                    }
                }
            } message: {
                if let order = orderToAdvance, let next = order.status.nextStatus {
                    Text("Status \(order.customerName) akan diubah dari \(order.status.rawValue) ke \(next.rawValue).")
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var filterSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(OrderFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 6) // Clearance for ~10pt card corner radius clip mask
                .onChange(of: selectedFilter) {
                    UISelectionFeedbackGenerator().selectionChanged()
                }

                orderCountSummary
                    .padding(.horizontal, 16) // Align with card content + clear corner clipping
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listSectionSpacing(.compact)
    }
    
    private var orderCountSummary: some View {
        HStack {
            if selectedFilter == .semua {
                Text("\(allOrders.count) pesanan")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(filteredOrders.count) pesanan")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            let overdueCount = allOrders.filter(\.isOverdue).count
            if overdueCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("\(overdueCount) terlambat")
                        .font(.subheadline)
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
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            let target = order
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                orderToDelete = target
                                showDeleteAlert = true
                            }
                        } label: {
                            Label("Hapus", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if let next = order.status.nextStatus {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                let target = order
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    orderToAdvance = target
                                    showAdvanceConfirm = true
                                }
                            } label: {
                                Label(next.rawValue, systemImage: next.icon)
                            }
                            .tint(next.foregroundColor)
                        }
                    }
                    .contextMenu {
                        if let next = order.status.nextStatus {
                            Button {
                                orderToAdvance = order
                                showAdvanceConfirm = true
                            } label: {
                                Label(next.rawValue, systemImage: next.icon)
                            }
                        }
                        
                        if !order.whatsappNumber.isEmpty,
                           let url = order.whatsappNumber.whatsAppURL
                        {
                            Link(destination: url) {
                                Label("WhatsApp", systemImage: "message.fill")
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            orderToDelete = order
                            showDeleteAlert = true
                        } label: {
                            Label("Hapus", systemImage: "trash")
                        }
                    }
                    .listRowBackground(rowBackground(for: order))
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
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.regular)
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
    
    /// Advances an order's status and handles notification + haptic side-effects.
    private func advanceStatus(of order: Order, to next: OrderStatus) {
        withAnimation { order.status = next }
        if next == .selesai {
            NotificationManager.cancelReminder(for: order)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await NotificationManager.scheduleDeadlineReminder(for: order) }
        }
        Task { await NotificationManager.updateEveningRadar(modelContext: modelContext) }
        orderToAdvance = nil
    }
    
    private func sectionHeaderColor(for date: Date) -> Color {
        let calendar = Calendar.current
        if date < calendar.startOfDay(for: Date()) { return .red }
        return .primary
    }
    
    /// Subtle background tint for urgent cards.
    /// Gestalt Figure/Ground: urgent cards visually "lift" from neutral ground.
    /// HIG triple signal: color (bg) + icon (⚠️/🕐) + text (Terlambat/Hari ini).
    private func rowBackground(for order: Order) -> Color {
        if order.isOverdue {
            return .overdueRowBackground
        }
        if order.isDueToday {
            return .todayRowBackground
        }
        return Color(.secondarySystemGroupedBackground)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Order.self, OrderItem.self], inMemory: true)
}
