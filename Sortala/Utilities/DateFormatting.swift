//
//  DateFormatting.swift
//  Sortala
//

import Foundation

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

    /// Time-only: "08.00"
    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "HH.mm"
        return formatter.string(from: self)
    }

    /// Date-only key for grouping (strips time component).
    var dateOnlyKey: Date {
        Calendar.current.startOfDay(for: self)
    }
}
