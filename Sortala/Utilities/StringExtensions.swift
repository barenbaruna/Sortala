//
//  StringExtensions.swift
//  Sortala
//

import Foundation

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
