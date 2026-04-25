//
//  PrimaryCTAButtonStyle.swift
//  Sortala
//
//  Reusable full-width CTA button style used in onboarding and tutorial.
//  Extracted to eliminate duplicate inline styling and ensure consistency.

import SwiftUI

/// A full-width, tinted call-to-action button style.
///
/// Used for primary actions like "Mulai Pakai" in onboarding and
/// "Mulai" in the guided tutorial. Provides a pressed opacity effect.
///
/// Usage:
/// ```swift
/// Button("Mulai Pakai") { ... }
///     .buttonStyle(PrimaryCTAButtonStyle())
/// ```
struct PrimaryCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.tint, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        Button("Mulai Pakai") {}
            .buttonStyle(PrimaryCTAButtonStyle())
            .tint(.teal)

        Button("Mulai") {}
            .buttonStyle(PrimaryCTAButtonStyle())
    }
    .padding()
}
