//
//  OrderFormView.swift
//  Sortala
//

import SwiftData
import SwiftUI

struct OrderFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    /// Pass an existing order to enter edit mode; `nil` creates a new order.
    var existingOrder: Order? = nil
    
    // MARK: - Form State
    
    @State private var customerName = ""
    @State private var whatsappNumber = ""
    @State private var address = ""
    @State private var items: [DraftItem] = [DraftItem()]
    @State private var deadline: Date = OrderImportViewModel.defaultDeadline

    @State private var orderSource: OrderSource = .whatsapp
    @State private var notes = ""
    @State private var status: OrderStatus = .baru
    
    @State private var alertTitle = "Perlu Dilengkapi"
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var selectedPresetDays: Int?
    @State private var addProductBounce: Int = 0
    @State private var originalSnapshot: FormSnapshot?
    
    private var isEditMode: Bool {
        existingOrder != nil
    }
    
    // MARK: - Change Detection
    
    /// Snapshot of form data at load time for dirty-checking in edit mode.
    private struct FormSnapshot {
        let customerName: String
        let whatsappNumber: String
        let address: String
        let notes: String
        let deadline: Date
        let orderSource: OrderSource
        let status: OrderStatus
        let items: [(name: String, quantity: Int)]
    }
    
    /// Returns true when the form has unsaved data worth protecting.
    ///
    /// - New orders: true when the user has entered any data.
    /// - Edit orders: true when any field differs from the snapshot.
    private var hasChanges: Bool {
        guard let snapshot = originalSnapshot else {
            // New order: check if user has typed anything
            return hasUserInput
        }
        if customerName != snapshot.customerName { return true }
        if whatsappNumber != snapshot.whatsappNumber { return true }
        if address != snapshot.address { return true }
        if notes != snapshot.notes { return true }
        if orderSource != snapshot.orderSource { return true }
        if status != snapshot.status { return true }
        if !Calendar.current.isDate(deadline, equalTo: snapshot.deadline, toGranularity: .minute) { return true }
        let currentItems = items.filter { !$0.productName.isEmpty }
            .map { ($0.productName, $0.quantity) }
        if currentItems.count != snapshot.items.count { return true }
        for (current, original) in zip(currentItems, snapshot.items) {
            if current.0 != original.0 || current.1 != original.1 { return true }
        }
        return false
    }

    /// Whether the user has entered any data in a new order form.
    private var hasUserInput: Bool {
        !customerName.trimmingCharacters(in: .whitespaces).isEmpty ||
        !whatsappNumber.trimmingCharacters(in: .whitespaces).isEmpty ||
        !address.trimmingCharacters(in: .whitespaces).isEmpty ||
        !notes.trimmingCharacters(in: .whitespaces).isEmpty ||
        items.contains { !$0.productName.isEmpty }
    }
    
    /// Required fields are filled: customer name + at least one product.
    private var isFormValid: Bool {
        let hasName = !customerName.trimmingCharacters(in: .whitespaces).isEmpty
        let hasProduct = items.contains { !$0.productName.isEmpty }
        return hasName && hasProduct
    }
    
    /// Save button should be visually highlighted (teal) when ready to save.
    private var canSave: Bool {
        isFormValid && (!isEditMode || hasChanges)
    }
    
    /// Common pre-order durations in days. (1=Besok, 3=Medium, 7=Satu Minggu)
    private let presetDays = [1, 3, 7]
    
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
                           let url = whatsappNumber.whatsAppURL
                        {
                            Link(destination: url) {
                                Image(systemName: "message.fill")
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alamat")
                        TextField("Jalan Medan Tenggara", text: $address, axis: .vertical)
                            .lineLimit(3 ... 5)
                    }
                }
                
                Section("Detail Pesanan") {
                    // Quick deadline presets
                    HStack(spacing: 8) {
                        Text("Durasi PO")
                            .foregroundStyle(.secondary)
                        Spacer()
                        ForEach(presetDays, id: \.self) { days in
                            presetButton(for: days)
                        }
                    }
                    
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
                    .pickerStyle(.menu)
                }
                
                Section("Catatan (Opsional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
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
                        withAnimation(.snappy(duration: 0.3)) {
                            items.append(DraftItem())
                        }
                        addProductBounce += 1
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label("Tambah Produk", systemImage: "plus.circle.fill")
                            .symbolEffect(.bounce, value: addProductBounce)
                    }
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
            }
            .tint(.teal)
            .navigationTitle(isEditMode ? "Edit Pesanan" : "Pesanan Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        saveOrder()
                    }
                    .disabled(isEditMode && !hasChanges)
                }
            }
            .alert(alertTitle, isPresented: $showValidationError) {
                Button("OK") {}
            } message: {
                Text(validationMessage)
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .onAppear { prefillForm() }
    }
    
    // MARK: - Subviews
    
    private func presetButton(for days: Int) -> some View {
        let isSelected = selectedPresetDays == days
        return Button {
            withAnimation(.snappy(duration: 0.25)) {
                selectedPresetDays = days
            }
            let base = Calendar.current.startOfDay(for: Date())
            if let date = Calendar.current.date(
                byAdding: .day, value: days, to: base
            ) {
                deadline = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: date) ?? date.addingTimeInterval(54000) // 15:00 Sore
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text("H+\(days)")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.teal : Color.secondary)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.presetSelected : Color(.quaternarySystemFill))
                )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
    
    // MARK: - Prefill
    
    private func prefillForm() {
        guard let order = existingOrder else { return }
        customerName = order.customerName
        whatsappNumber = order.whatsappNumber
        address = order.address
        items = order.items.map { DraftItem(from: $0) }
        deadline = order.deadline
        orderSource = order.orderSource
        notes = order.notes
        status = order.status
        
        // Capture snapshot for change detection
        originalSnapshot = FormSnapshot(
            customerName: order.customerName,
            whatsappNumber: order.whatsappNumber,
            address: order.address,
            notes: order.notes,
            deadline: order.deadline,
            orderSource: order.orderSource,
            status: order.status,
            items: order.items.map { ($0.productName, $0.quantity) }
        )
    }
    
    // MARK: - Save
    
    private func saveOrder() {
        guard !customerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            alertTitle = "Perlu Dilengkapi"
            validationMessage = "Nama pelanggan tidak boleh kosong."
            showValidationError = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        
        guard items.contains(where: { !$0.productName.isEmpty }) else {
            alertTitle = "Perlu Dilengkapi"
            validationMessage = "Tambahkan minimal satu produk."
            showValidationError = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        
        let savedOrder: Order
        let didEditExistingOrder: Bool

        if let order = existingOrder {
            order.customerName = customerName
            order.whatsappNumber = whatsappNumber
            order.address = address
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

            savedOrder = order
            didEditExistingOrder = true
        } else {
            let newOrder = Order(
                customerName: customerName,
                whatsappNumber: whatsappNumber,
                address: address,
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

            savedOrder = newOrder
            didEditExistingOrder = false
        }

        do {
            try modelContext.save()
        } catch {
            alertTitle = "Tidak Dapat Menyimpan"
            validationMessage = "Pesanan belum disimpan. Coba lagi sebelum menutup halaman ini."
            showValidationError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        Task {
            if didEditExistingOrder {
                NotificationManager.cancelReminder(for: savedOrder)
            } else {
                _ = await NotificationManager.requestPermission()
            }
            if savedOrder.status != .selesai {
                await NotificationManager.scheduleDeadlineReminder(for: savedOrder)
            }
            await NotificationManager.updateEveningRadar(modelContext: modelContext)
            SortalaWidgetReloader.reloadTimelines()
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

#Preview {
    OrderFormView()
        .modelContainer(for: [Order.self, OrderItem.self], inMemory: true)
}
