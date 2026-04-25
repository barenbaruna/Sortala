//
//  OrderParser.swift
//  Sortala
//
//  On-device text parser that converts unstructured order messages into
//  a structured `ParsedOrder` for review before SwiftData persistence.
//
//  Architecture — three layers, applied in order of specificity:
//
//  1. **Swift Regex** — Extracts structured `Key : Value` fields from
//     template-formatted messages (e.g. `Nama : Baren Baruna`).
//  2. **Foundation** — `NSDataDetector` fills gaps for phone numbers
//     and dates that Layer 1 missed (handles all locales).
//  3. **NaturalLanguage** — `NLTagger` performs on-device ML-based
//     person-name extraction as a final fallback.
//
//  Thread safety: `NSDataDetector` instances are expensive to create
//  but thread-safe for concurrent reads. They are initialised once at
//  startup and reused for the lifetime of the singleton.

import Foundation
import NaturalLanguage

// MARK: - ParsedOrder

/// The result of parsing a raw text string.
///
/// All fields are optional — the user always reviews and confirms values
/// in the import sheet before anything is persisted to SwiftData.
///
/// `confidence` (0–1) reflects how many fields were successfully
/// extracted and drives the colour of the progress bar in the UI.
///
/// Conforms to `Identifiable` so `HomeView` can use `.sheet(item:)`
/// for atomic sheet presentation.
struct ParsedOrder: Identifiable {
    let id = UUID()

    var customerName: String?
    var whatsappNumber: String?
    var address: String?
    var items: [(productName: String, quantity: Int)]
    var deadline: Date?
    var orderSource: OrderSource
    var notes: String?
    var confidence: Double
    var detectedFields: Set<DetectedField>
    var rawText: String

    /// Fields that the parser successfully extracted from the input text.
    enum DetectedField: Hashable {
        case name, phone, address, deadline, items, notes, source
    }

    /// An empty result returned for blank or whitespace-only input.
    static var empty: ParsedOrder {
        ParsedOrder(
            customerName: nil, whatsappNumber: nil, address: nil,
            items: [], deadline: nil, orderSource: .lainnya,
            notes: nil, confidence: 0, detectedFields: [], rawText: ""
        )
    }
}

// MARK: - OrderParser

/// Singleton parser engine.
///
/// `NSDataDetector` instances are expensive to initialise and are thread-safe
/// for concurrent reads, so they are created once at startup and reused.
final class OrderParser: Sendable {
    static let shared = OrderParser()
    private init() {}

    private let phoneDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue
    )
    private let dateDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    // MARK: - Public API

    /// Parses a raw text string and returns a `ParsedOrder` with all
    /// detected fields populated and a confidence score.
    ///
    /// - Parameter rawText: The unstructured order message text.
    /// - Returns: A `ParsedOrder` with extracted fields and confidence.
    func parse(_ rawText: String) -> ParsedOrder {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .empty }

        var result = ParsedOrder(
            customerName: nil, whatsappNumber: nil, address: nil,
            items: [], deadline: nil, orderSource: .lainnya,
            notes: nil, confidence: 0, detectedFields: [], rawText: rawText
        )

        // Layer 1: structured template
        extractTemplateFields(from: text, into: &result)

        // Layer 2: fill gaps with Apple frameworks
        if result.customerName == nil { fillName(from: text, into: &result) }
        if result.whatsappNumber == nil { fillPhone(from: text, into: &result) }
        if result.deadline == nil { fillDeadline(from: text, into: &result) }
        if result.items.isEmpty { fillItemsFreeform(from: text, into: &result) }

        // Source detection (keyword-based only — no iOS API for clipboard source)
        if let detected = detectOrderSource(from: text) {
            result.orderSource = detected
            result.detectedFields.insert(.source)
        }
        // When source is NOT detected, orderSource stays `.lainnya` and
        // `.source` is NOT in detectedFields → UI prompts user to verify.

        result.confidence = calculateConfidence(result)
        return result
    }

    // MARK: - Layer 2 Bridges (private)

    private func fillName(from text: String, into result: inout ParsedOrder) {
        guard let name = extractNameNLTagger(from: text) else { return }
        result.customerName = name
        result.detectedFields.insert(.name)
    }

    private func fillPhone(from text: String, into result: inout ParsedOrder) {
        guard let phone = extractPhone(from: text) else { return }
        result.whatsappNumber = phone
        result.detectedFields.insert(.phone)
    }

    private func fillDeadline(from text: String, into result: inout ParsedOrder) {
        guard let date = extractDate(from: text) else { return }
        result.deadline = date
        result.detectedFields.insert(.deadline)
    }

    private func fillItemsFreeform(from text: String, into result: inout ParsedOrder) {
        let items = extractItemsFreeform(from: text)
        guard !items.isEmpty else { return }
        result.items = items
        result.detectedFields.insert(.items)
    }

    // MARK: - Confidence Score

    /// Weighted score reflecting how much of the order was auto-detected.
    ///
    /// Weight table (sums to 1.0):
    /// | Field    | Weight | Rationale                         |
    /// |----------|--------|-----------------------------------|
    /// | items    | 0.30   | Most critical for order meaning   |
    /// | name     | 0.25   | Required for customer ID          |
    /// | deadline | 0.15   | Needed for production scheduling  |
    /// | phone    | 0.10   | Needed for WhatsApp follow-up     |
    /// | address  | 0.10   | Delivery/pickup location          |
    /// | notes    | 0.05   | Optional extra context             |
    /// | source   | 0.05   | Always has a value (default/auto) |
    func calculateConfidence(_ order: ParsedOrder) -> Double {
        var score = 0.0
        if order.customerName != nil { score += 0.25 }
        if !order.items.isEmpty { score += 0.30 }
        if order.deadline != nil { score += 0.15 }
        if order.whatsappNumber != nil { score += 0.10 }
        if order.address != nil { score += 0.10 }
        if order.notes != nil { score += 0.05 }
        if order.detectedFields.contains(.source) { score += 0.05 }
        return min(score, 1.0)
    }

    // MARK: - Order Source Detection

    /// Infers `OrderSource` from explicit keywords in the text.
    ///
    /// Returns `nil` when no keywords match — the caller must then
    /// present a picker for the user to choose manually. This avoids
    /// silently mislabeling orders.
    ///
    /// > Important: There is **no public iOS API** to detect which app
    /// > wrote to the clipboard or triggered the Share Sheet. The system
    /// > banner ("Sortala pasted from WhatsApp") is displayed to the user
    /// > only and is not programmatically accessible.
    ///
    /// Detection priority:
    /// 1. WhatsApp keywords → `.whatsapp`
    /// 2. Instagram keywords → `.instagram`
    /// 3. Offline keywords → `.langsung`
    /// 4. No match → `nil`
    func detectOrderSource(from text: String) -> OrderSource? {
        let lower = text.lowercased()

        // WhatsApp — explicit labels only
        let waLabels = ["no. whatsapp", "no whatsapp", "nomor wa", "no. wa",
                        "no wa", "whatsapp", "wa:", "wa :"]
        if waLabels.contains(where: { lower.contains($0) }) { return .whatsapp }

        // Instagram — require word-boundary-aware patterns to avoid
        // false positives from email addresses containing "@".
        let igKeywords = ["instagram", "ig:", "direct message", "dm:"]
        if igKeywords.contains(where: { lower.contains($0) }) { return .instagram }

        // Offline / walk-in
        let offlineKeywords = ["langsung", "offline", "datang ke toko", "walk in", "drop off"]
        if offlineKeywords.contains(where: { lower.contains($0) }) { return .langsung }

        return nil
    }
}

// MARK: - Template Parsing (Layer 1)

extension OrderParser {
    /// Extracts fields from structured `Key : Value` lines.
    ///
    /// Address fields support continuation lines: if the next line after
    /// `Alamat:` has no key separator, it is appended to the address
    /// (handles multi-line street addresses common in Indonesian format).
    func extractTemplateFields(from text: String, into result: inout ParsedOrder) {
        let lines = text.components(separatedBy: .newlines)
        var collectingAddress = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Continuation of a multi-line address
            if collectingAddress {
                if splitKeyValue(trimmed) == nil, !trimmed.isEmpty, !isListBullet(trimmed) {
                    result.address = (result.address ?? "") + " " + trimmed
                    continue
                } else {
                    collectingAddress = false
                }
            }

            guard let (key, value) = splitKeyValue(trimmed), !value.isEmpty else { continue }
            let k = key.lowercased()

            if matchesKey(k, ["nama", "customer", "pelanggan", "pembeli", "pemesan", "atas nama", "a.n"]) {
                result.customerName = value
                result.detectedFields.insert(.name)

            } else if matchesKey(k, ["no. whatsapp", "no whatsapp", "whatsapp", "wa", "hp",
                                     "no. hp", "no hp", "telp", "telepon", "handphone", "contact"])
            {
                result.whatsappNumber = sanitizePhone(value)
                result.detectedFields.insert(.phone)

            } else if matchesKey(k, ["alamat", "address", "lokasi", "kirim ke", "domisili"]) {
                result.address = value
                result.detectedFields.insert(.address)
                collectingAddress = true // next non-key lines are address continuation

            } else if matchesKey(k, ["deadline", "paket po", "tgl", "tanggal", "batas",
                                     "antar", "selesai", "order untuk", "minta tgl", "minta tanggal"])
            {
                if let date = extractDate(from: value) {
                    result.deadline = date
                    result.detectedFields.insert(.deadline)
                }

            } else if matchesKey(k, ["catatan", "notes", "note", "keterangan",
                                     "info tambahan", "pesan tambahan", "tambahan"])
            {
                result.notes = value
                result.detectedFields.insert(.notes)

            } else if matchesKey(k, ["produk", "pesanan", "order", "barang", "item"]) {
                let parsed = parseInlineItems(value)
                if !parsed.isEmpty {
                    result.items = parsed
                    result.detectedFields.insert(.items)
                }
            }
        }

        // Bullet-list items take precedence over inline items
        let bulletItems = extractBulletItems(from: text)
        if !bulletItems.isEmpty {
            result.items = bulletItems
            result.detectedFields.insert(.items)
        }
    }

    /// Returns true when `line` looks like a bullet list entry (not an address continuation).
    private func isListBullet(_ line: String) -> Bool {
        line.hasPrefix("-") || line.hasPrefix("•") || line.hasPrefix("*") ||
            line.first?.unicodeScalars.first.map { $0.properties.isEmoji } == true ||
            line.wholeMatch(of: /^\d+[.)\s]/) != nil
    }

    /// Splits `"Key : Value"` or `"Key - Value"` into `(key, value)`.
    ///
    /// The key is limited to 2–30 characters and must not contain `:` or `-`.
    /// This prevents matching on phone numbers or other inline values.
    private func splitKeyValue(_ line: String) -> (String, String)? {
        let pattern = /^([^:\-]{2,30})\s*[:\-]\s*(.+)$/
        guard let match = line.wholeMatch(of: pattern) else { return nil }
        return (String(match.1).trimmingCharacters(in: .whitespaces),
                String(match.2).trimmingCharacters(in: .whitespaces))
    }

    /// Case-insensitive substring match against a list of known key patterns.
    private func matchesKey(_ key: String, _ patterns: [String]) -> Bool {
        patterns.contains { key.contains($0) }
    }
}

// MARK: - Item Parsing

extension OrderParser {
    /// Extracts product lines from bullet, numbered, or emoji-prefixed lists.
    ///
    /// Supported bullet prefixes: `-`, `•`, `*`, emoji (e.g. `🔹`), `1.`, `2)`, etc.
    func extractBulletItems(from text: String) -> [(productName: String, quantity: Int)] {
        text.components(separatedBy: .newlines).compactMap { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            let content: String

            if t.hasPrefix("-") || t.hasPrefix("•") || t.hasPrefix("*") {
                content = String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else if let m = t.wholeMatch(of: /^\d+[.)\s]\s*(.+)$/) {
                content = String(m.1).trimmingCharacters(in: .whitespaces)
            } else if let firstScalar = t.unicodeScalars.first, firstScalar.properties.isEmoji {
                // Strip leading emoji character(s) used as a custom bullet
                let stripped = t.drop(while: { $0.unicodeScalars.first?.properties.isEmoji == true
                        || $0 == " "
                })
                content = String(stripped).trimmingCharacters(in: .whitespaces)
            } else {
                return nil
            }

            return content.isEmpty ? nil : parseItemLine(content)
        }
    }

    /// Parses a single product description into `(name, quantity)`.
    ///
    /// Pattern priority (most specific → least specific):
    ///
    /// | Pattern | Example                      | Result              |
    /// |---------|------------------------------|---------------------|
    /// | A       | `"Brownies x2"`, `"Kue X 3"` | `("Brownies", 2)`  |
    /// | B       | `"2x Brownies"`, `"2 Kue"`   | `("Brownies", 2)`  |
    /// | C       | `"Hampers 1 Pcs"`            | `("Hampers", 1)`   |
    /// | D       | `"Brownies"` (no qty)        | `("Brownies", 1)`  |
    ///
    /// Trailing unit keywords are stripped: pcs, buah, box, kotak, loyang, ls, set.
    func parseItemLine(_ text: String) -> (productName: String, quantity: Int)? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }

        // Pattern A: Name × Qty — "Brownies x2", "Kue Lapis X 3"
        if let m = t.wholeMatch(of: /^(.+?)\s*[xX×]\s*(\d+)$/) {
            let name = String(m.1).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return (name, Int(m.2) ?? 1) }
        }

        // Pattern B: Qty × Name — "2x Brownies", "2 Brownies"
        if let m = t.wholeMatch(of: /^(\d+)\s*[xX×]?\s+(.+)$/) {
            let name = stripUnit(String(m.2).trimmingCharacters(in: .whitespaces))
            if !name.isEmpty { return (name, Int(m.1) ?? 1) }
        }

        // Pattern C: Name Qty [Unit] — "Hampers 1 Pcs", "Give card 2 pcs"
        if let m = t.wholeMatch(of: /^(.+)\s+(\d+)\s*(?i:pcs?|buah|box|kotak|loyang|ls|set)?\s*$/) {
            let name = String(m.1).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty, name.contains(where: { $0.isLetter }) {
                return (name, Int(m.2) ?? 1)
            }
        }

        // Pattern D: Name only (no quantity) — "Brownies", "Kue Keju"
        // Fallback: treat as a single item with quantity 1.
        // Only matches if the text contains at least one letter (filters
        // out stray numbers or emoji-only lines).
        if t.contains(where: { $0.isLetter }) {
            let name = stripUnit(t)
            if !name.isEmpty { return (name, 1) }
        }

        return nil
    }

    /// Parses comma-separated items: `"Brownies 2, Kue Keju 1"`.
    func parseInlineItems(_ text: String) -> [(productName: String, quantity: Int)] {
        text.components(separatedBy: ",")
            .compactMap { parseItemLine($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Layer 2 fallback: scans every non-key line for parseable product patterns.
    func extractItemsFreeform(from text: String) -> [(productName: String, quantity: Int)] {
        text.components(separatedBy: .newlines).compactMap { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return t.contains(":") ? nil : parseItemLine(t)
        }
    }

    /// Strips trailing unit keywords (pcs, buah, box…) from a product name.
    private func stripUnit(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"(?i)\s+(pcs?|buah|box|kotak|loyang|ls|set)$"#,
            with: "", options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Phone Detection & Sanitisation (Layer 2)

extension OrderParser {
    /// Extracts and sanitises the first Indonesian phone number found in `text`.
    ///
    /// Uses `NSDataDetector` (Foundation) for locale-aware phone detection,
    /// then strips all non-digit characters to produce a clean numeric string.
    func extractPhone(from text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = phoneDetector?.firstMatch(in: text, options: [], range: range),
              let phone = match.phoneNumber else { return nil }
        let sanitized = sanitizePhone(phone)
        // Validate: must be 10–15 digits for Indonesian numbers
        guard sanitized.count >= 10, sanitized.count <= 15 else { return nil }
        return sanitized
    }

    /// Strips ALL non-digit characters and normalises to the `08xx` local format.
    ///
    /// Handles edge cases like:
    /// - `"0812-3456-7890"` → `"081234567890"`
    /// - `"0812198219amamam"` → `"0812198219"` (trailing letters stripped)
    /// - `"+62812-3456-7890"` → `"081234567890"`
    /// - `"62812345678"` → `"0812345678"` (auto-add leading zero)
    func sanitizePhone(_ raw: String) -> String {
        // Step 1: Keep only digits
        var digits = raw.filter { $0.isNumber }

        // Step 2: Normalise country code to local format
        if digits.hasPrefix("+62") { digits = "0" + digits.dropFirst(3) }
        else if digits.hasPrefix("62") && digits.count > 10 { digits = "0" + digits.dropFirst(2) }

        return String(digits)
    }
}

// MARK: - Date Detection (Layer 2)

extension OrderParser {
    /// Extracts a deadline date from `text`, normalised to a business-appropriate hour.
    ///
    /// Detection priority:
    /// 1. `H+N` pattern  — `"H+3"`, `"h +7"`
    /// 2. Indonesian relative keywords — `"besok"`, `"lusa"`, `"minggu depan"`
    /// 3. `NSDataDetector` — `"25 April 2026"`, `"25/04/2026"` (after month normalisation)
    ///
    /// All returned dates are normalised via `businessHour(_:)`:
    /// - Same-day → 18:00 (gives preparation time)
    /// - Future   → 12:00 noon (standard pre-order pickup time)
    func extractDate(from text: String) -> Date? {
        if let d = extractHPlusDate(from: text) { return businessHour(d) }
        if let d = extractRelativeDate(from: text) { return businessHour(d) }

        let normalized = normalizeIndonesianMonths(in: text)
        let range = NSRange(normalized.startIndex..., in: normalized)
        if let match = dateDetector?.firstMatch(in: normalized, options: [], range: range),
           let date = match.date
        {
            let valid = date >= Calendar.current.startOfDay(for: Date())
                ? date
                : futureDate(from: date)
            return businessHour(valid)
        }
        return nil
    }

    /// Parses `H+N` patterns: `"H+3"`, `"H +7"`, `"h+1"`.
    private func extractHPlusDate(from text: String) -> Date? {
        guard let match = text.firstMatch(of: /(?i)h\s*\+\s*(\d+)/),
              let days = Int(match.1) else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: Date())
    }

    /// Parses Indonesian relative date words.
    private func extractRelativeDate(from text: String) -> Date? {
        let lower = text.lowercased()
        let cal = Calendar.current
        let today = Date()
        if lower.contains("besok") { return cal.date(byAdding: .day, value: 1, to: today) }
        if lower.contains("lusa") { return cal.date(byAdding: .day, value: 2, to: today) }
        if lower.contains("minggu depan") || lower.contains("pekan depan") {
            return cal.date(byAdding: .weekOfYear, value: 1, to: today)
        }
        return nil
    }

    /// Normalises a parsed date to a business-appropriate hour:
    /// - **Same day** → 18:00 (allow preparation time)
    /// - **Future**   → 12:00 noon (standard pre-order delivery/pickup)
    private func businessHour(_ date: Date) -> Date {
        let cal = Calendar.current
        let hour = cal.isDateInToday(date) ? 18 : 12
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
    }

    /// Replaces Indonesian month names with English equivalents for `NSDataDetector`.
    private func normalizeIndonesianMonths(in text: String) -> String {
        let map: [(String, String)] = [
            ("januari", "january"), ("februari", "february"), ("maret", "march"),
            ("april", "april"), ("mei", "may"), ("juni", "june"),
            ("juli", "july"), ("agustus", "august"), ("september", "september"),
            ("oktober", "october"), ("november", "november"), ("desember", "december"),
            ("jan", "jan"), ("feb", "feb"), ("mar", "mar"), ("apr", "apr"),
            ("agu", "aug"), ("okt", "oct"), ("des", "dec"),
        ]
        var result = text.lowercased()
        for (id, en) in map {
            result = result.replacingOccurrences(of: id, with: en)
        }
        return result
    }

    /// If a parsed date falls in the past (e.g. `"25 April"` without a year),
    /// bumps it forward one year.
    private func futureDate(from date: Date) -> Date {
        Calendar.current.date(byAdding: .year, value: 1, to: date) ?? date
    }
}

// MARK: - Name Extraction (Layer 3 — NLTagger)

extension OrderParser {
    /// Extracts the first personal name found in `text` using Apple's on-device ML.
    ///
    /// Used as a Layer 3 fallback when no `"Nama:"` label is detected in Layer 1.
    /// - Note: `NLTagger` works best with full sentences; short single-word inputs may not match.
    func extractNameNLTagger(from text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var found: String?
        tagger.enumerateTags(
            in: text.startIndex ..< text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, range in
            if tag == .personalName { found = String(text[range]); return false }
            return true
        }
        return found
    }
}
