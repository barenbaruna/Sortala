//
//  ShareImportView.swift
//  SortalaShare
//
//  SwiftUI review sheet presented inside the Share Extension.
//  Uses native `Form` + `NavigationStack` to match ClipboardImportView
//  exactly, ensuring a consistent user experience across both import flows.
//
//  Reuses `OrderImportViewModel` for all business logic (parse, validate, save).

import SwiftData
import SwiftUI

/// SwiftUI review sheet presented inside the Share Extension.
///
/// Uses native `Form` + `NavigationStack` to match `ClipboardImportView`
/// exactly, ensuring a consistent user experience across both import flows.
/// Reuses `OrderImportViewModel` for all business logic.
struct ShareImportView: View {
    @Environment(\.modelContext) private var modelContext

    @State var viewModel: OrderImportViewModel
    @State private var showSaveError = false
    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                confidenceSection
                pelangganSection
                produkSection
                detailSection
                catatanSection
                rawTextSection
            }
            .tint(.teal)
            .navigationTitle("Import Pesanan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog(
                "Batalkan Import?",
                isPresented: $viewModel.showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Batalkan Import", role: .destructive) { onDismiss() }
                Button("Tetap Edit", role: .cancel) {}
            } message: {
                Text("Data yang sudah kamu edit tidak akan disimpan.")
            }
            .alert("Tidak Dapat Menyimpan", isPresented: $showSaveError) {
                Button("OK") {}
            } message: {
                Text("Pesanan belum disimpan. Coba lagi sebelum menutup halaman ini.")
            }
        }
        .interactiveDismissDisabled(viewModel.hasEdited)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                if viewModel.hasEdited {
                    viewModel.showCancelConfirm = true
                } else {
                    onDismiss()
                }
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                Task {
                    if await viewModel.saveOrder(context: modelContext) {
                        NotificationManager.scheduleImportConfirmation(
                            customerName: viewModel.customerName
                        )
                        onDismiss()
                    } else {
                        showSaveError = true
                    }
                }
            }
            .disabled(!viewModel.isFormValid)
        }
    }

    // MARK: - Confidence Section

    private var confidenceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(viewModel.confidenceLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(viewModel.confidenceColor)
                    Spacer()
                    Text("\(Int(viewModel.currentConfidence * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.confidenceColor)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                ConfidenceBar(
                    value: viewModel.currentConfidence,
                    color: viewModel.confidenceColor
                )

                Text(viewModel.confidenceHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(Int(viewModel.currentConfidence * 100)) persen field terdeteksi. \(viewModel.confidenceHint)"
            )
        }
    }

    // MARK: - Pelanggan Section

    private var pelangganSection: some View {
        Section("Pelanggan") {
            LabeledContent {
                HStack {
                    TextField("Nama pelanggan", text: $viewModel.customerName)
                        .multilineTextAlignment(.trailing)
                    if viewModel.parsedOrder.detectedFields.contains(.name) { DetectedBadge() }
                }
            } label: {
                Text("Nama")
            }

            HStack {
                Text("WhatsApp")
                Spacer()
                TextField("08xx-xxxx-xxxx", text: $viewModel.whatsappNumber)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.phonePad)
                if viewModel.whatsappNumber.isValidWhatsAppNumber,
                   let url = viewModel.whatsappNumber.whatsAppURL
                {
                    Link(destination: url) {
                        Image(systemName: "message.fill").foregroundStyle(.teal)
                    }
                }
                if viewModel.parsedOrder.detectedFields.contains(.phone) { DetectedBadge() }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Alamat")
                    Spacer()
                    if viewModel.parsedOrder.detectedFields.contains(.address) { DetectedBadge() }
                }
                TextField("Jl. Medan Tenggara 7 No. 89", text: $viewModel.address, axis: .vertical)
                    .lineLimit(2 ... 4)
            }
        }
    }

    // MARK: - Produk Section

    private var produkSection: some View {
        Section {
            ForEach($viewModel.items) { $item in
                ItemRowEditor(item: $item)
            }
            .onDelete { indexSet in
                guard viewModel.items.count > 1 else { return }
                viewModel.items.remove(atOffsets: indexSet)
            }

            Button {
                withAnimation(.snappy(duration: 0.3)) {
                    viewModel.items.append(DraftItem())
                }
                viewModel.addProductBounce += 1
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("Tambah Produk", systemImage: "plus.circle.fill")
                    .symbolEffect(.bounce, value: viewModel.addProductBounce)
            }
        } header: {
            HStack {
                Text("Produk")
                if viewModel.parsedOrder.detectedFields.contains(.items) { DetectedBadge() }
                Spacer()
                if viewModel.items.count > 1 {
                    Text("Geser untuk hapus")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Detail Section

    private var detailSection: some View {
        Section("Detail Pesanan") {
            HStack {
                DatePicker(
                    "Deadline",
                    selection: $viewModel.deadline,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .environment(\.locale, Locale(identifier: "id_ID"))
                if viewModel.parsedOrder.detectedFields.contains(.deadline) { DetectedBadge() }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Picker("Sumber", selection: $viewModel.orderSource) {
                        ForEach(OrderSource.allCases, id: \.self) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                    .pickerStyle(.menu)

                    if viewModel.parsedOrder.detectedFields.contains(.source) {
                        DetectedBadge()
                    } else {
                        // Orange indicator: source was NOT auto-detected
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                            .accessibilityLabel("Sumber belum dikonfirmasi")
                    }
                }

                Text(viewModel.sourceHint)
                    .font(.caption)
                    .foregroundColor(
                        viewModel.parsedOrder.detectedFields.contains(.source)
                            ? Color.secondary : Color.orange
                    )
            }
        }
    }

    // MARK: - Catatan Section

    private var catatanSection: some View {
        Section("Catatan (Opsional)") {
            TextEditor(text: $viewModel.notes)
                .frame(minHeight: 60)
        }
    }

    // MARK: - Raw Text Section

    private var rawTextSection: some View {
        Section {
            DisclosureGroup("Teks Asli", isExpanded: $viewModel.showRawText) {
                Text(viewModel.parsedOrder.rawText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}
