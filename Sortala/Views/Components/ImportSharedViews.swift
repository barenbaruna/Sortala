//
//  ImportSharedViews.swift
//  Sortala
//
//  Reusable UI components shared between ClipboardImportView and ShareImportView.
//  Extracted to eliminate duplication and ensure visual consistency across
//  both import flows (clipboard paste and iOS Share Sheet).
//
//  Pattern Reference: Apple's CustomProgressBar.swift from Wishlist sample.

import SwiftUI

// MARK: - ConfidenceBar

/// A horizontally filling progress bar for the parser confidence score.
///
/// Uses `@Animatable` on a custom `Shape` so SwiftUI interpolates the
/// bar width smoothly between values, instead of snapping. The track
/// uses `.ultraThinMaterial` for iOS 26 Liquid Glass compatibility.
struct ConfidenceBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // Track — material for glassmorphism
                Capsule()
                    .fill(value > 0 ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(color.opacity(0.2)))

                // Fill — @Animatable shape for smooth interpolation
                BarShape(value: value)
                    .fill(color)
            }
        }
        .frame(height: 6)
        .animation(.snappy, value: value)
    }
}

/// A shape that represents the filled portion of the confidence bar.
///
/// Using `@Animatable` allows SwiftUI to smoothly interpolate `value`
/// between states, producing a fluid slide effect instead of a jump.
@Animatable
private struct BarShape: Shape {
    /// The progress value, ranging from `0.0` (empty) to `1.0` (full).
    var value: Double

    /// Creates a path for the bar shape within the given rectangle.
    ///
    /// - Parameter rect: The rectangle in which to draw the bar.
    /// - Returns: A path representing the filled portion as a rounded rectangle.
    func path(in rect: CGRect) -> Path {
        let radius = rect.height / 2
        let fillWidth = max(rect.height, rect.width * value)
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height),
            cornerSize: CGSize(width: radius, height: radius),
            style: .circular
        )
        return path
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

