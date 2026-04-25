//
//  AnimatedSplashView.swift
//  Sortala
//
//  App launch splash animation. Responsible ONLY for the animated logo reveal,
//  then hands off to `RootRouter` for navigation decisions.

import SwiftUI

/// Animated splash screen shown on every app launch.
///
/// Displays the Sortala logo with a spring animation, then transitions
/// to `RootRouter` which handles onboarding/tutorial/home routing.
/// This view contains NO routing logic — it is animation-only.
struct AnimatedSplashView: View {
    @State private var isAnimationFinished = false
    @State private var logoScale: CGFloat = 1.0
    @State private var textOpacity: Double = 0.0
    @State private var verticalOffset: CGFloat = 0.0

    /// Scales with Dynamic Type for accessibility.
    @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 100

    var body: some View {
        if isAnimationFinished {
            RootRouter()
        } else {
            splashAnimation
                .task { await runSplashAnimation() }
        }
    }

    // MARK: - Splash Animation

    private var splashAnimation: some View {
        VStack(spacing: 12) {
            Image("SplashScreen")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .scaleEffect(logoScale)

            Text("Sortala")
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .opacity(textOpacity)
        }
        .offset(y: verticalOffset)
    }

    /// Runs the two-step splash animation using modern Swift concurrency.
    private func runSplashAnimation() async {
        // Step 1: Reveal text and shift layout upward
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            textOpacity = 1.0
            logoScale = 0.95
            verticalOffset = -20
        }

        // Step 2: Transition to main content after delay
        try? await Task.sleep(for: .seconds(1.0))
        withAnimation(.snappy(duration: 0.3)) {
            isAnimationFinished = true
        }
    }
}

#Preview {
    AnimatedSplashView()
}
