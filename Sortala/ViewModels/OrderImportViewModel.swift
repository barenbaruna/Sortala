//
//  OrderImportViewModel.swift
//  Sortala
//
//  ViewModel for the clipboard import review sheet (MVVM pattern).
//  Owns all business logic for `OrderImportPreviewView`, keeping the view
//  as a pure binding layer.
//
//  Uses `@Observable` (iOS 17+) for granular SwiftUI property tracking
//  without requiring individual `@Published` declarations.

import Observation
import SwiftData
import SwiftUI

@Observable
final class OrderImportViewModel {

    // MARK: - Source

    /// The original parsed result. Used for dirty-checking and as the badge source
    /// (which fields were auto-detected vs. manually entered).
    let parsedOrder: ParsedOrder

    // MARK: - Form State

    var customerName: String
    var whatsappNumber: String
    var address: String
    var items: [DraftItem]
    var deadline: Date
    var orderSource: OrderSource
    var notes: String

    // MARK: - UI State

    var showCancelConfirm = false
    var showRawText = false
    var addProductBounce = 0

    // MARK: - Init

    init(parsedOrder: ParsedOrder) {
        self.parsedOrder = parsedOrder
        customerName   = parsedOrder.customerName ?? ""
        whatsappNumber = parsedOrder.whatsappNumber ?? ""
        address        = parsedOrder.address ?? ""
        items          = parsedOrder.items.isEmpty
            ? [DraftItem()]
            : parsedOrder.items.map { DraftItem(productName: $0.productName, quantity: $0.quantity) }
        deadline       = parsedOrder.deadline ?? Self.defaultDeadline
        orderSource    = parsedOrder.orderSource
        notes          = parsedOrder.notes ?? ""
    }

    // MARK: - Validation

    /// All required fields (name + at least one product) are present.
    var isFormValid: Bool {
        !customerName.trimmed.isEmpty &&
        items.contains { !$0.productName.trimmed.isEmpty }
    }

    // MARK: - Reactive Confidence
    //
    // Computed from *current* form state so the confidence bar and percentage
    // animate as the user fills in or clears fields.
    //
    // Weight table (must sum to 1.0):
    //   items    0.35  — most critical for the order to make sense
    //   name     0.30  — required for customer identification
    //   deadline 0.20  — needed for scheduling
    //   phone    0.10  — needed for WhatsApp follow-up
    //   source   0.05  — always present (has a default)

    var currentConfidence: Double {
        var score = 0.05
        if !customerName.trimmed.isEmpty                                   { score += 0.30 }
        if items.contains(where: { !$0.productName.trimmed.isEmpty })      { score += 0.35 }
        if deadline > Date()                                               { score += 0.20 }
        if !whatsappNumber.trimmed.isEmpty                                 { score += 0.10 }
        return min(score, 1.0)
    }

    var confidenceColor: Color {
        switch currentConfidence {
        case 0.80...: return .teal
        case 0.50..<0.80: return .orange
        default: return .red
        }
    }

    var confidenceLabel: String {
        switch currentConfidence {
        case 0.80...: return "Data lengkap — siap disimpan"
        case 0.50..<0.80: return "Beberapa field perlu diperiksa"
        default: return "Isi manual diperlukan"
        }
    }

    var confidenceHint: String {
        switch currentConfidence {
        case 0.80...: return "Periksa sekali lagi sebelum menyimpan."
        case 0.50..<0.80: return "Lengkapi field yang masih kosong."
        default: return "Teks tidak dikenali — isi seluruh field secara manual."
        }
    }

    // MARK: - Order Source Hint

    /// Contextual hint below the source picker.
    /// Shows "Terdeteksi otomatis" when the parser inferred the source,
    /// otherwise prompts the user to verify.
    var sourceHint: String {
        parsedOrder.detectedFields.contains(.source)
            ? "Terdeteksi otomatis dari teks."
            : "Periksa dan sesuaikan sumber pesanan ini."
    }

    // MARK: - Dirty Check

    /// True when the user has modified any parser-filled value.
    /// Used to gate interactive swipe-dismiss and show the cancel confirmation.
    var hasEdited: Bool {
        customerName   != (parsedOrder.customerName ?? "")   ||
        whatsappNumber != (parsedOrder.whatsappNumber ?? "") ||
        address        != (parsedOrder.address ?? "")        ||
        notes          != (parsedOrder.notes ?? "")          ||
        orderSource    != parsedOrder.orderSource            ||
        !Calendar.current.isDate(
            deadline,
            equalTo: parsedOrder.deadline ?? Self.defaultDeadline,
            toGranularity: .minute
        )
    }

    // MARK: - Default Deadline

    /// 12:00 noon tomorrow — shared by both clipboard import and the manual form.
    static var defaultDeadline: Date {
        let cal      = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 12, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    // MARK: - Save

    /// Persists the confirmed order to SwiftData and schedules notifications.
    ///
    /// - Parameter context: The `ModelContext` from the view's environment.
    /// - Returns: `true` when the order was successfully inserted.
    @MainActor
    @discardableResult
    func saveOrder(context: ModelContext) async -> Bool {
        let trimmedName = customerName.trimmed
        let validItems  = items.filter { !$0.productName.trimmed.isEmpty }
        guard !trimmedName.isEmpty, !validItems.isEmpty else { return false }

        let newOrder = Order(
            customerName: trimmedName,
            whatsappNumber: whatsappNumber.trimmed,
            address: address.trimmed,
            deadline: deadline,
            orderSource: orderSource,
            notes: notes.trimmed
        )

        for draft in validItems {
            let item = OrderItem(
                productName: draft.productName.trimmed,
                quantity: draft.quantity
            )
            newOrder.items.append(item)
            context.insert(item)
        }

        context.insert(newOrder)
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        _ = await NotificationManager.requestPermission()
        await NotificationManager.scheduleDeadlineReminder(for: newOrder)
        await NotificationManager.updateEveningRadar(modelContext: context)

        return true
    }
}

// MARK: - String.trimmed

private extension String {
    /// Convenience for `trimmingCharacters(in: .whitespaces)`.
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
