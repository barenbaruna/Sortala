//
//  OrderFormView.swift
//  Sortala
//

import SwiftUI
import SwiftData

struct OrderFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing order to enter edit mode; `nil` creates a new order.
    var existingOrder: Order? = nil

    /// Pre-fills fields from parsed chat text (Method 2).
    var parsedOrder: ParsedOrder? = nil

    // MARK: - Form State

    @State private var customerName = ""
    @State private var whatsappNumber = ""
    @State private var items: [DraftItem] = [DraftItem()]
    @State private var deadline = Date().addingTimeInterval(86400)
    @State private var orderSource: OrderSource = .whatsapp
    @State private var notes = ""
    @State private var status: OrderStatus = .baru

    @State private var showValidationError = false
    @State private var validationMessage = ""

    private var isEditMode: Bool { existingOrder != nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Pelanggan") {
                    LabeledContent {
                        TextField("Nama pelanggan", text: $customerName)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text("Nama")
                    }

                    HStack {
                        Text("WhatsApp")
                        Spacer()
                        TextField("0812-3456-7890", text: $whatsappNumber)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.phonePad)

                        if whatsappNumber.isValidWhatsAppNumber,
                           let url = whatsappNumber.whatsAppURL {
                            Link(destination: url) {
                                Image(systemName: "message.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                Section {
                    ForEach($items) { $item in
                        ItemRowEditor(item: $item)
                    }
                    .onDelete { indexSet in
                        guard items.count > 1 else { return }
                        items.remove(atOffsets: indexSet)
                    }

                    Button {
                        items.append(DraftItem())
                    } label: {
                        Label("Tambah Produk", systemImage: "plus.circle.fill")
                    }
                    .tint(.accentColor)
                } header: {
                    HStack {
                        Text("Produk")
                        Spacer()
                        if items.count > 1 {
                            Text("Geser untuk hapus")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Detail Pesanan") {
                    DatePicker(
                        "Deadline",
                        selection: $deadline,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.locale, Locale(identifier: "id_ID"))

                    Picker("Sumber", selection: $orderSource) {
                        ForEach(OrderSource.allCases, id: \.self) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Catatan (Opsional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle(isEditMode ? "Edit Pesanan" : "Pesanan Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { saveOrder() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Perlu Dilengkapi", isPresented: $showValidationError) {
                Button("OK") {}
            } message: {
                Text(validationMessage)
            }
        }
        .onAppear { prefillForm() }
    }

    // MARK: - Prefill

    private func prefillForm() {
        if let order = existingOrder {
            customerName = order.customerName
            whatsappNumber = order.whatsappNumber
            items = order.items.map { DraftItem(from: $0) }
            deadline = order.deadline
            orderSource = order.orderSource
            notes = order.notes
            status = order.status
        } else if let parsed = parsedOrder {
            customerName = parsed.customerName ?? ""
            whatsappNumber = parsed.whatsappNumber ?? ""
            deadline = parsed.deadline ?? Date().addingTimeInterval(86400)
            notes = parsed.notes ?? ""

            if let product = parsed.productName {
                items = [DraftItem(productName: product, quantity: parsed.quantity ?? 1)]
            }
        }
    }

    // MARK: - Save

    private func saveOrder() {
        guard !customerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Nama pelanggan tidak boleh kosong."
            showValidationError = true
            return
        }

        guard items.contains(where: { !$0.productName.isEmpty }) else {
            validationMessage = "Tambahkan minimal satu produk."
            showValidationError = true
            return
        }

        if let order = existingOrder {
            order.customerName = customerName
            order.whatsappNumber = whatsappNumber
            order.deadline = deadline
            order.orderSource = orderSource
            order.notes = notes
            order.status = status

            // Replace items (simple approach, suitable for small item counts)
            order.items.forEach { modelContext.delete($0) }
            order.items = []

            for draft in items where !draft.productName.isEmpty {
                let item = OrderItem(productName: draft.productName, quantity: draft.quantity)
                order.items.append(item)
                modelContext.insert(item)
            }
        } else {
            let newOrder = Order(
                customerName: customerName,
                whatsappNumber: whatsappNumber,
                deadline: deadline,
                orderSource: orderSource,
                notes: notes
            )

            for draft in items where !draft.productName.isEmpty {
                let item = OrderItem(productName: draft.productName, quantity: draft.quantity)
                newOrder.items.append(item)
                modelContext.insert(item)
            }

            modelContext.insert(newOrder)
        }

        dismiss()
    }
}

// MARK: - DraftItem

/// Transient model for form editing before persisting to SwiftData.
struct DraftItem: Identifiable {
    let id = UUID()
    var productName: String = ""
    var quantity: Int = 1

    init(from orderItem: OrderItem) {
        self.productName = orderItem.productName
        self.quantity = orderItem.quantity
    }

    init(productName: String = "", quantity: Int = 1) {
        self.productName = productName
        self.quantity = quantity
    }
}

// MARK: - ItemRowEditor

struct ItemRowEditor: View {
    @Binding var item: DraftItem

    var body: some View {
        TextField("Nama produk", text: $item.productName)
        Stepper("\(item.quantity) pcs", value: $item.quantity, in: 1...99)
            .monospacedDigit()
    }
}

#Preview {
    OrderFormView()
        .modelContainer(for: [Order.self, OrderItem.self], inMemory: true)
}
