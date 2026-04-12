//
//  OrderParser.swift
//  Sortala
//

import Foundation

// MARK: - ParsedOrder

/// Result of parsing free-form Indonesian chat text into structured order fields.
/// All fields are optional since detection is best-effort.
struct ParsedOrder {
    var customerName: String?
    var whatsappNumber: String?
    var productName: String?
    var quantity: Int?
    var deadline: Date?
    var notes: String?

    /// Ratio of successfully detected fields (0.0–1.0).
    var completenessScore: Double {
        let fields: [Any?] = [customerName, productName, quantity, deadline]
        let filled = fields.filter { $0 != nil }.count
        return Double(filled) / Double(fields.count)
    }
}

// MARK: - OrderParser

/// Regex-based extractor that runs entirely on-device (offline).
/// Supports common Indonesian chat patterns from WhatsApp and Instagram.
struct OrderParser {

    static func parse(_ text: String) -> ParsedOrder {
        var result = ParsedOrder()
        result.customerName   = extractName(from: text)
        result.whatsappNumber = extractPhoneNumber(from: text)
        result.productName    = extractProduct(from: text)
        result.quantity       = extractQuantity(from: text)
        result.deadline       = extractDeadline(from: text)
        result.notes          = extractNotes(from: text)
        return result
    }

    // MARK: - Extractors

    /// Patterns: "nama: Zahra", "a/n Budi", "atas nama Siti"
    private static func extractName(from text: String) -> String? {
        let patterns = [
            #"(?:nama|name|an|a\/n|atas nama)[:\s]+([A-Za-z\s]+)"#,
            #"(?:dari|from|pemesan)[:\s]+([A-Za-z\s]+)"#,
        ]
        for pattern in patterns {
            if let match = firstMatch(pattern, in: text, group: 1) {
                let cleaned = match.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count > 1 { return cleaned }
            }
        }
        return nil
    }

    /// Indonesian phone formats: 08xx, +628xx, 628xx
    private static func extractPhoneNumber(from text: String) -> String? {
        let pattern = #"(?:\+?62|0)[\s\-]?8[\d\s\-]{8,12}"#
        if let match = firstMatch(pattern, in: text) {
            return match.components(separatedBy: CharacterSet(charactersIn: " -")).joined()
        }
        return nil
    }

    /// Patterns: "pesan: kue", "mau beli brownies"
    private static func extractProduct(from text: String) -> String? {
        let patterns = [
            #"(?:pesan|order|mau pesan|mau beli|beli|minta)[:\s]+(.+?)(?:\n|,|\.|\d+\s*(?:pcs|biji|buah|box|cup))"#,
            #"(\d+)\s*(?:pcs|biji|buah|box|cup|porsi)\s+(.+?)(?:\n|,|\.)"#,
        ]
        for pattern in patterns {
            if let match = firstMatch(pattern, in: text, group: 1) {
                let cleaned = match.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count > 2 { return cleaned }
            }
        }
        return nil
    }

    /// Matches number + Indonesian unit: "2 pcs", "3 biji", "1 box"
    private static func extractQuantity(from text: String) -> Int? {
        let pattern = #"(\d+)\s*(?:pcs|biji|buah|box|cup|porsi|loyang|lusin)"#
        if let match = firstMatch(pattern, in: text, group: 1),
           let qty = Int(match) {
            return qty
        }
        return nil
    }

    /// Supports relative ("besok", "lusa"), Indonesian months ("11 april"),
    /// and numeric formats ("11/04").
    private static func extractDeadline(from text: String) -> Date? {
        let calendar = Calendar.current
        let today = Date()

        let relativeMap: [String: Int] = [
            "besok": 1, "lusa": 2, "minggu depan": 7,
            "tomorrow": 1, "next week": 7
        ]

        let lowerText = text.lowercased()
        for (keyword, days) in relativeMap {
            if lowerText.contains(keyword) {
                return calendar.date(byAdding: .day, value: days, to: today)
            }
        }

        let indonesianMonths = [
            "januari": 1, "februari": 2, "maret": 3, "april": 4,
            "mei": 5, "juni": 6, "juli": 7, "agustus": 8,
            "september": 9, "oktober": 10, "november": 11, "desember": 12
        ]

        let monthPattern = #"(\d{1,2})\s+(januari|februari|maret|april|mei|juni|juli|agustus|september|oktober|november|desember)"#
        if let dayStr = firstMatch(monthPattern, in: lowerText, group: 1),
           let monthStr = firstMatch(monthPattern, in: lowerText, group: 2),
           let day = Int(dayStr),
           let month = indonesianMonths[monthStr] {

            var components = calendar.dateComponents([.year], from: today)
            components.month = month
            components.day = day
            components.hour = 8
            components.minute = 0

            // Assume next year if the date has already passed.
            if let date = calendar.date(from: components), date < today {
                components.year = (components.year ?? 2025) + 1
            }
            return calendar.date(from: components)
        }

        let numericPattern = #"(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?"#
        if let dayStr = firstMatch(numericPattern, in: text, group: 1),
           let monthStr = firstMatch(numericPattern, in: text, group: 2),
           let day = Int(dayStr), let month = Int(monthStr) {

            var components = calendar.dateComponents([.year], from: today)
            components.month = month
            components.day = day
            components.hour = 8
            return calendar.date(from: components)
        }

        return nil
    }

    private static func extractNotes(from text: String) -> String? {
        let pattern = #"(?:catatan|note|request|keterangan|tambahan)[:\s]+(.+?)(?:\n|$)"#
        return firstMatch(pattern, in: text, group: 1)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Regex Utility

    private static func firstMatch(
        _ pattern: String,
        in text: String,
        group: Int = 0
    ) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        let targetRange = group == 0 ? match.range : match.range(at: group)
        guard targetRange.location != NSNotFound,
              let swiftRange = Range(targetRange, in: text) else { return nil }
        return String(text[swiftRange])
    }
}
