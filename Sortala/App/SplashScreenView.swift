//
//  SplashScreenView.swift
//  Sortala
//

import SwiftUI

struct SplashScreenView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var featureIconSize: CGFloat = 22

    var body: some View {
        if hasSeenOnboarding && hasCompletedTutorial {
            HomeView()
        } else if hasSeenOnboarding && !hasCompletedTutorial {
            GuidedTutorialView()
        } else {
            onboardingContent
        }
    }

    // MARK: - Onboarding

    private var onboardingContent: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: logoSize, weight: .medium))
                        .foregroundStyle(.tint)
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

                Button {
                    withAnimation { hasSeenOnboarding = true }
                } label: {
                    Text("Mulai Pakai")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .opacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.3)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: featureIconSize))
                .foregroundStyle(.tint)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
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
    SplashScreenView()
}
