//
//  ImportSharedViews.swift
//  Sortala
//
//  Reusable UI components shared between ClipboardImportView and ShareImportView.
//  Extracted to eliminate duplication and ensure visual consistency across
//  both import flows (clipboard paste and iOS Share Sheet).

import SwiftUI

// MARK: - ConfidenceBar

/// A horizontally filling progress capsule for the parser confidence score.
///
/// Uses `GeometryReader` to fill proportionally based on `value` (0–1).
/// Animates smoothly when the user fills or clears form fields.
struct ConfidenceBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemFill))
                    .frame(height: 6)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * value), height: 6)
                    .animation(.easeOut(duration: 0.35), value: value)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - DetectedBadge

/// Teal checkmark badge indicating a field was auto-populated by the parser.
///
/// Displayed inline next to fields where the parser successfully extracted
/// a value from the raw text, providing confidence signal to the user.
struct DetectedBadge: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.teal)
            .font(.caption)
            .accessibilityLabel("Terdeteksi otomatis")
    }
}
