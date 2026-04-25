//
//  StringExtensions.swift
//  Sortala
//
//  Shared string utilities used across views and view-models.
//  Kept as extensions on `String` for ergonomic call-site syntax.

import Foundation

// MARK: - Trimming

extension String {
    /// Convenience for `trimmingCharacters(in: .whitespaces)`.
    ///
    /// Used extensively in form validation (`isFormValid`) and save logic
    /// to avoid persisting leading/trailing whitespace to SwiftData.
    var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - WhatsApp

extension String {
    /// Normalises to international format: `"0812..."` → `"6281..."`.
    ///
    /// Strips all non-digit characters first, then converts local prefix `0`
    /// to country code `62` (Indonesia).
    var normalizedWhatsAppNumber: String {
        var number = self.filter { $0.isNumber }
        if number.hasPrefix("0") {
            number = "62" + number.dropFirst()
        }
        return number
    }

    /// Deep-link URL for opening a WhatsApp chat with this phone number.
    var whatsAppURL: URL? {
        URL(string: "https://wa.me/\(self.normalizedWhatsAppNumber)")
    }

    /// Validates that this string looks like a plausible phone number.
    ///
    /// Rules:
    /// - Contains 10–15 digits (covers all Indonesian mobile/landline formats)
    /// - Does NOT accept strings where non-digit characters outnumber digits
    ///   (e.g. `"amamam"` → 0 digits → false)
    var isValidWhatsAppNumber: Bool {
        let digits = self.filter { $0.isNumber }
        return digits.count >= 10 && digits.count <= 15
    }
}
