//
//  RootRouter.swift
//  Sortala
//
//  Single routing authority for the app's first-launch flow.
//  Consolidates all navigation decisions into one place, following
//  Apple's pattern of a single root view that handles state transitions.

import SwiftUI

/// Single routing authority for the app's first-launch flow.
///
/// Reads `@AppStorage` flags and presents the appropriate screen.
/// This eliminates duplicate routing logic that was previously
/// scattered across `AnimatedSplashView` and `OnboardingView`.
struct RootRouter: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false

    @Binding private var deepLinkedOrderID: UUID?
    @Binding private var shouldPresentAddOrder: Bool

    init(
        deepLinkedOrderID: Binding<UUID?> = .constant(nil),
        shouldPresentAddOrder: Binding<Bool> = .constant(false)
    ) {
        _deepLinkedOrderID = deepLinkedOrderID
        _shouldPresentAddOrder = shouldPresentAddOrder
    }

    var body: some View {
        if hasSeenOnboarding && hasCompletedTutorial {
            HomeView(
                deepLinkedOrderID: $deepLinkedOrderID,
                shouldPresentAddOrder: $shouldPresentAddOrder
            )
        } else if hasSeenOnboarding {
            GuidedTutorialView()
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    RootRouter()
}
