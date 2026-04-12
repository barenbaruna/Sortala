//
//  PasteOrderView.swift
//  Sortala
//

import SwiftUI

// MARK: - PasteStep

enum PasteStep {
    case input
    case preview
}

// MARK: - PasteOrderView

/// Two-step flow: paste chat text → preview parsed results → continue to form.
/// Prepared for Method 2 integration (not active in MVP).
struct PasteOrderView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var pastedText = ""
    @State private var currentStep: PasteStep = .input
    @State private var parsedOrder: ParsedOrder?
    @State private var showOrderForm = false

    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .input:   pasteInputView
                case .preview: parsePreviewView
                }
            }
            .navigationTitle(
                currentStep == .input ? "Paste Teks Pesanan" : "Hasil Deteksi"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showOrderForm) {
            if let parsed = parsedOrder {
                OrderFormView(parsedOrder: parsed)
            }
        }
    }

    // MARK: - Input Step

    private var pasteInputView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Cara pakai", systemImage: "info.circle")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text("Buka WhatsApp atau Instagram → copy teks pesanan dari customer → kembali ke sini → paste di bawah.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()

            VStack(alignment: .leading, spacing: 8) {
                Text("Teks Pesanan")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                TextEditor(text: $pastedText)
                    .frame(minHeight: 180)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(.separator), lineWidth: 0.5)
                    )
                    .padding(.horizontal)
                    .overlay(alignment: .topLeading) {
                        if pastedText.isEmpty {
                            Text("Contoh:\nNama: Zahra\nMau pesan kue ulang tahun medium 1 bj\nDeadline 11 april pagi")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .padding(20)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Spacer()

            VStack(spacing: 10) {
                Button {
                    if let text = UIPasteboard.general.string {
                        pastedText = text
                    }
                } label: {
                    Label("Paste dari Clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .tint(.primary)

                Button { parseText() } label: {
                    Label("Deteksi Otomatis", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(pastedText.isEmpty ? 0.5 : 1)
            }
            .padding()
        }
    }

    // MARK: - Preview Step

    private var parsePreviewView: some View {
        VStack(spacing: 0) {
            List {
                Section("Teks Asli") {
                    Text(pastedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                if let parsed = parsedOrder {
                    Section {
                        HStack {
                            Text("Kelengkapan data")
                            Spacer()
                            let score = Int(parsed.completenessScore * 100)
                            Text("\(score)%")
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    score >= 75 ? .green :
                                    score >= 50 ? .orange : .red
                                )
                        }
                    } header: {
                        Text("Hasil Deteksi ✨")
                    } footer: {
                        Text("Data yang terdeteksi akan diisi otomatis ke form. Kamu bisa ubah sebelum simpan.")
                    }

                    Section("Data Terdeteksi") {
                        detectedField("Nama", value: parsed.customerName, icon: "person.fill")
                        detectedField("No. WA", value: parsed.whatsappNumber, icon: "phone.fill")
                        detectedField("Produk", value: parsed.productName, icon: "shippingbox.fill")
                        detectedField("Jumlah", value: parsed.quantity.map { "\($0) pcs" }, icon: "number")
                        detectedField("Deadline", value: parsed.deadline.map { $0.fullFormatted }, icon: "calendar")
                    }
                }
            }
            .listStyle(.insetGrouped)

            VStack(spacing: 10) {
                Button { showOrderForm = true } label: {
                    Label("Lanjut ke Form", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }

                Button {
                    withAnimation { currentStep = .input }
                } label: {
                    Text("Edit Teks")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .tint(.primary)
            }
            .padding()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func detectedField(
        _ label: String,
        value: String?,
        icon: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 20)

            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            if let value, !value.isEmpty {
                Text(value)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.trailing)
            } else {
                Label("Tidak terdeteksi", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func parseText() {
        parsedOrder = OrderParser.parse(pastedText)
        withAnimation { currentStep = .preview }
    }
}

#Preview {
    PasteOrderView()
}
