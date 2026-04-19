//
//  AnimatedSplashView.swift
//  Sortala
//

import SwiftUI

struct AnimatedSplashView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    
    @State private var isAnimationFinished = false
    @State private var logoScale: CGFloat = 1.0
    @State private var textOpacity: Double = 0.0
    @State private var verticalOffset: CGFloat = 0.0
    
    var body: some View {
        Group {
            if isAnimationFinished {
                // Handoff Routing phase
                if hasSeenOnboarding && hasCompletedTutorial {
                    HomeView()
                } else if hasSeenOnboarding && !hasCompletedTutorial {
                    GuidedTutorialView()
                } else {
                    OnboardingView()
                }
            } else {
                // Splash Animation phase
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        Image("SplashScreen")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                            .scaleEffect(logoScale)
                        
                        Text("Sortala")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(.primary)
                            .opacity(textOpacity)
                    }
                    .offset(y: verticalOffset)
                }
                .onAppear {
                    runSplashAnimation()
                }
            }
        }
    }
    
    private func runSplashAnimation() {
        // Step 1: Reveal the Text and lightly organize the layout upward
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            textOpacity = 1.0
            logoScale = 0.95
            verticalOffset = -20
        }
        
        // Step 2: Final zoom / fade out wrapper
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.snappy(duration: 0.3)) {
                isAnimationFinished = true
            }
        }
    }
}

#Preview {
    AnimatedSplashView()
}
