//
//  Helpers.swift
//  Sortala
//

import Foundation
import SwiftUI

// MARK: - Date Formatting

extension Date {

    /// Relatif: "Hari ini", "Besok", atau "11 Apr"
    var relativeFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Hari ini" }
        if calendar.isDateInTomorrow(self) { return "Besok" }
        if calendar.isDateInYesterday(self) { return "Kemarin" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: self)
    }

    /// Lengkap: "Minggu, 11 April 2025 · 08.00"
    var fullFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "EEEE, d MMMM yyyy · HH.mm"
        return formatter.string(from: self)
    }

    /// Section header: "14 April 2026 (Hari ini)" or "15 April 2026 (Besok)" or "20 April 2026"
    var sectionHeaderFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMMM yyyy"
        let dateString = formatter.string(from: self)

        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "\(dateString) (Hari ini)" }
        if calendar.isDateInTomorrow(self) { return "\(dateString) (Besok)" }
        return dateString
    }

    /// Date-only key for grouping (strips time component).
    var dateOnlyKey: Date {
        Calendar.current.startOfDay(for: self)
    }
}

// MARK: - WhatsApp

extension String {

    /// Normalisasi ke format internasional: "0812..." → "6281..."
    var normalizedWhatsAppNumber: String {
        var number = self
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "+", with: "")

        if number.hasPrefix("0") {
            number = "62" + number.dropFirst()
        }
        return number
    }

    var whatsAppURL: URL? {
        URL(string: "https://wa.me/\(normalizedWhatsAppNumber)")
    }

    var isValidWhatsAppNumber: Bool {
        let digits = self.filter { $0.isNumber }
        return digits.count >= 10 && digits.count <= 15
    }
}

// MARK: - OrderStatus UI

extension OrderStatus {

    var icon: String {
        switch self {
        case .baru:      return "sparkles"
        case .diproses:  return "arrow.triangle.2.circlepath"
        case .selesai:   return "checkmark.circle.fill"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .baru:      return .blue
        case .diproses:  return .orange
        case .selesai:   return .green
        }
    }

    var backgroundColor: Color {
        switch self {
        case .baru:      return .blue.opacity(0.15)
        case .diproses:  return .orange.opacity(0.15)
        case .selesai:   return .green.opacity(0.15)
        }
    }
}

// MARK: - OrderSource UI

extension OrderSource {

    var icon: String {
        switch self {
        case .whatsapp:  return "message.fill"
        case .instagram: return "camera.fill"
        case .langsung:  return "person.fill"
        }
    }

    var color: Color {
        switch self {
        case .whatsapp:  return .green
        case .instagram: return .purple
        case .langsung:  return .secondary
        }
    }
}
