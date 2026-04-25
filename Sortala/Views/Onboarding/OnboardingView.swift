//
//  OnboardingView.swift
//  Sortala
//
//  Feature highlights shown on first launch. Presents the app's value
//  proposition with animated entry. Routing is handled by RootRouter.

import SwiftUI

/// First-launch feature highlights screen.
///
/// Presents the Sortala logo and three key features with a spring entrance
/// animation. Tapping "Mulai Pakai" sets `hasSeenOnboarding` which causes
/// `RootRouter` to advance to the next step.
struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0

    /// Scales with Dynamic Type for accessibility.
    @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var featureIconSize: CGFloat = 22

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App identity
            VStack(spacing: 16) {
                Image("SplashScreen")
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSize * 1.5, height: logoSize * 1.5)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text("Sortala")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)

                    Text("Kelola pre-order, tanpa ribet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(logoOpacity)
            }

            Spacer()

            // Feature highlights
            VStack(spacing: 0) {
                featureRow(
                    icon: "plus.circle.fill",
                    title: "Catat Pesanan Cepat",
                    subtitle: "Input order dari WhatsApp, Instagram, atau langsung"
                )
                Divider().padding(.leading, 52)
                featureRow(
                    icon: "list.bullet.clipboard.fill",
                    title: "Semua di Satu Tempat",
                    subtitle: "Lihat semua pesanan, urutkan by deadline"
                )
                Divider().padding(.leading, 52)
                featureRow(
                    icon: "bell.badge.fill",
                    title: "Tidak Ada yang Terlewat",
                    subtitle: "Tahu mana yang deadline hari ini"
                )
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            .opacity(logoOpacity)

            Spacer()

            // CTA
            Button("Mulai Pakai") {
                withAnimation { hasSeenOnboarding = true }
            }
            .buttonStyle(PrimaryCTAButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .opacity(logoOpacity)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.3)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: featureIconSize))
                .foregroundStyle(.tint)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    OnboardingView()
}
