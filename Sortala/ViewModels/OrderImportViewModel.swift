//
//  OrderImportViewModel.swift
//  Sortala
//
//  Business logic for the Clipboard Import and Share Extension review sheets.
//
//  Owns all state, validation, and persistence logic, keeping the views as
//  pure binding layers. Uses `@Observable` for granular SwiftUI property
//  tracking without requiring individual `@Published` declarations.
//
//  Shared by both `ClipboardImportView` (main app) and `ShareImportView`
//  (Share Extension) to guarantee identical behaviour across import flows.

import Observation
import SwiftData
import SwiftUI

@Observable
final class OrderImportViewModel {
    // MARK: - Source

    /// The original parsed result. Used for dirty-checking and as the badge
    /// source (which fields were auto-detected vs. manually entered).
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
        customerName = parsedOrder.customerName ?? ""
        whatsappNumber = parsedOrder.whatsappNumber ?? ""
        address = parsedOrder.address ?? ""
        items = parsedOrder.items.isEmpty
            ? [DraftItem()]
            : parsedOrder.items.map { DraftItem(productName: $0.productName, quantity: $0.quantity) }
        deadline = parsedOrder.deadline ?? Self.defaultDeadline
        orderSource = parsedOrder.orderSource
        notes = parsedOrder.notes ?? ""
    }

    // MARK: - Validation

    /// All required fields (name + at least one product) are present.
    var isFormValid: Bool {
        !customerName.trimmed.isEmpty &&
            items.contains { !$0.productName.trimmed.isEmpty }
    }

    // MARK: - Reactive Confidence

    /// Computed from *current* form state so the confidence bar and percentage
    /// animate as the user fills in or clears fields.
    ///
    /// Weight table (sums to 1.0):
    ///
    /// | Field    | Weight | Rationale                        |
    /// |----------|--------|----------------------------------|
    /// | items    | 0.30   | Most critical for order meaning  |
    /// | name     | 0.25   | Required for customer ID         |
    /// | deadline | 0.15   | Needed for scheduling            |
    /// | phone    | 0.10   | Needed for WhatsApp follow-up    |
    /// | address  | 0.10   | Delivery/pickup location         |
    /// | notes    | 0.05   | Optional extra context           |
    /// | source   | 0.05   | Channel the order arrived from   |
    var currentConfidence: Double {
        var score = 0.0
        if !customerName.trimmed.isEmpty { score += 0.25 }
        if items.contains(where: { !$0.productName.trimmed.isEmpty }) { score += 0.30 }
        if deadline > Date() { score += 0.15 }
        if !whatsappNumber.trimmed.isEmpty { score += 0.10 }
        if !address.trimmed.isEmpty { score += 0.10 }
        if !notes.trimmed.isEmpty { score += 0.05 }
        // Source counts toward confidence only when auto-detected or when
        // the user has explicitly chosen a source other than .lainnya.
        if sourceIsConfirmed { score += 0.05 }
        return min(score, 1.0)
    }

    /// Whether the order source has been confirmed (either auto-detected
    /// by the parser, or manually changed by the user from the default).
    var sourceIsConfirmed: Bool {
        parsedOrder.detectedFields.contains(.source) || orderSource != .lainnya
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
    ///
    /// When the parser successfully detected the source from keywords,
    /// shows "Terdeteksi otomatis". Otherwise, prompts the user to verify.
    var sourceHint: String {
        if parsedOrder.detectedFields.contains(.source) {
            return "Terdeteksi otomatis dari teks."
        }
        return "Pilih sumber pesanan yang benar."
    }

    // MARK: - Dirty Check

    /// True when the user has modified any parser-filled value.
    /// Used to gate interactive swipe-dismiss and show the cancel confirmation.
    var hasEdited: Bool {
        customerName != (parsedOrder.customerName ?? "") ||
            whatsappNumber != (parsedOrder.whatsappNumber ?? "") ||
            address != (parsedOrder.address ?? "") ||
            notes != (parsedOrder.notes ?? "") ||
            orderSource != parsedOrder.orderSource ||
            !Calendar.current.isDate(
                deadline,
                equalTo: parsedOrder.deadline ?? Self.defaultDeadline,
                toGranularity: .minute
            )
    }

    // MARK: - Default Deadline

    /// 12:00 noon tomorrow — shared by both clipboard import and the manual form.
    static var defaultDeadline: Date {
        let cal = Calendar.current
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
        let validItems = items.filter { !$0.productName.trimmed.isEmpty }
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

        do {
            try context.save()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }

        _ = await NotificationManager.requestPermission()
        await NotificationManager.scheduleDeadlineReminder(for: newOrder)
        await NotificationManager.updateEveningRadar(modelContext: context)
        SortalaWidgetReloader.reloadTimelines()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        return true
    }
}
