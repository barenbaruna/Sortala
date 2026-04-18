//
//  OrderDetailView.swift
//  Sortala
//

import SwiftData
import SwiftUI

struct OrderDetailView: View {
    @Bindable var order: Order

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    // MARK: - Body

    var body: some View {
        List {
            Section("Pelanggan") {
                LabeledContent(
                    "Nama",
                    value: order.customerName.isEmpty ? "-" : order.customerName
                )
                if !order.whatsappNumber.isEmpty {
                    HStack {
                        Text("WhatsApp")
                        Spacer()
                        if let url = order.whatsappNumber.whatsAppURL {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Text(order.whatsappNumber)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                }
                                .foregroundStyle(.tint)
                            }
                        } else {
                            Text(order.whatsappNumber)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !order.address.isEmpty {
                    LabeledContent("Alamat", value: order.address)
                }
            }

            Section("Produk") {
                if order.items.isEmpty {
                    Text("Belum ada produk")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(order.items) { item in
                        LabeledContent {
                            Text("\(item.quantity) pcs")
                                .foregroundStyle(.secondary)
                        } label: {
                            Text(item.productName)
                                .fontWeight(.medium)
                        }
                    }
                }
            }

            Section("Detail Pesanan") {
                HStack {
                    Text("Deadline")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(order.deadline.relativeFormatted)
                            .foregroundStyle(order.isOverdue ? .red : .primary)
                            .fontWeight(order.isDueToday || order.isOverdue ? .semibold : .regular)
                        Text(order.deadline.fullFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Sumber")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: order.orderSource.icon)
                        Text(order.orderSource.rawValue)
                    }
                    .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    Menu {
                        Picker("Status", selection: $order.status) {
                            ForEach(OrderStatus.allCases, id: \.self) { s in
                                Label(s.rawValue, systemImage: s.icon).tag(s)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: order.status.icon)
                                .contentTransition(.symbolEffect(.replace))
                                .font(.caption)
                            Text(order.status.rawValue)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(order.status.backgroundColor, in: Capsule())
                        .foregroundStyle(order.status.foregroundColor)
                        .animation(.snappy(duration: 0.25), value: order.status)
                    }
                }

                HStack {
                    Text("Dicatat pada")
                    Spacer()
                    Text(order.createdAt.fullFormatted)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !order.notes.isEmpty {
                Section("Catatan") {
                    Text(order.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text("Hapus Pesanan")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(
            order.customerName.isEmpty ? "Detail Pesanan" : order.customerName
        )
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            OrderFormView(existingOrder: order)
        }
        .alert("Hapus Pesanan?", isPresented: $showDeleteConfirmation) {
            Button("Hapus", role: .destructive) {
                NotificationManager.cancelReminder(for: order)
                modelContext.delete(order)
                dismiss()
            }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Pesanan \(order.customerName) akan dihapus permanen.")
        }
        .onChange(of: order.status) { _, newStatus in
            if newStatus == .selesai {
                NotificationManager.cancelReminder(for: order)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                NotificationManager.scheduleDeadlineReminder(for: order)
            }
        }
    }
}

#Preview {
    let order = Order(
        customerName: "Zahra Nur",
        whatsappNumber: "081234567890",
        deadline: Date().addingTimeInterval(3600),
        orderSource: .whatsapp,
        notes: "Tulisan kue: Happy Birthday Rina"
    )
    NavigationStack {
        OrderDetailView(order: order)
    }
    .modelContainer(for: [Order.self, OrderItem.self], inMemory: true)
}
