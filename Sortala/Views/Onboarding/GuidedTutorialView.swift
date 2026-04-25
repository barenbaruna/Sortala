//
//  GuidedTutorialView.swift
//  Sortala
//
//  Interactive tutorial teaching swipe-right, swipe-left, and long-press
//  gestures using a practice order row. Routing is handled by RootRouter.

import SwiftUI

// MARK: - Tutorial Step

/// Represents each stage of the interactive gesture tutorial.
private enum TutorialStep: Int, CaseIterable {
    case swipeRight = 0
    case swipeLeft = 1
    case longPress = 2
    case done = 3

    /// The instruction text displayed to the user.
    var instruction: String {
        switch self {
        case .swipeRight: return "Geser pesanan ke kanan →\nuntuk memajukan status"
        case .swipeLeft: return "← Geser pesanan ke kiri\nuntuk menghapus"
        case .longPress: return "Tekan & tahan pesanan\nuntuk menu cepat"
        case .done: return "Kamu siap menggunakan Sortala!"
        }
    }

    /// The SF Symbol name for the step's icon.
    var icon: String {
        switch self {
        case .swipeRight: return "hand.point.right.fill"
        case .swipeLeft: return "hand.point.left.fill"
        case .longPress: return "hand.tap.fill"
        case .done: return "checkmark.circle.fill"
        }
    }
}

// MARK: - GuidedTutorialView

/// Interactive tutorial that teaches swipe and context menu gestures.
///
/// Uses a practice `List` row with swipe actions and context menus
/// that mirror the real `HomeView` interactions, ensuring Gestalt
/// similarity between what the user learns and what they'll actually use.
struct GuidedTutorialView: View {
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false

    @State private var currentStep: TutorialStep = .swipeRight
    @State private var dummyStatus: String = "Baru"
    @State private var showDummyCard = true
    @State private var stepCompleted = false
    @State private var showSkipConfirm = false

    /// Single haptic generator instance — Apple recommends reusing, not recreating.
    private let haptic = UINotificationFeedbackGenerator()

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar
                .padding(.top, 16)
                .padding(.horizontal, 20)

            // Instruction area
            instructionCard
                .padding(.top, 32)
                .padding(.horizontal, 20)

            Spacer()

            // Practice area
            if currentStep != .done {
                practiceList
            } else {
                doneView
            }

            Spacer()

            // Skip / Continue
            bottomButton
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .animation(.snappy(duration: 0.35), value: currentStep)
        .animation(.snappy(duration: 0.3), value: stepCompleted)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< 3, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep.rawValue ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.systemFill)))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Instruction Card

    private var instructionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: currentStep.icon)
                .font(.system(size: 36))
                .foregroundStyle(.tint)
                .contentTransition(.symbolEffect(.replace))

            Text(currentStep.instruction)
                .font(.title3)
                .fontWeight(.bold)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())

            if currentStep != .done {
                Text("Langkah \(currentStep.rawValue + 1) dari 3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Practice List

    private var practiceList: some View {
        VStack(spacing: 0) {
            Text("SILAKAN COBA DI BAWAH INI")
                .font(.caption)
                .fontWeight(.bold)
                .kerning(1.0)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            List {
                if showDummyCard {
                    dummyOrderRow
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .listStyle(.insetGrouped)
            .scrollDisabled(true)
            .frame(height: 140)

            if stepCompleted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Berhasil!")
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.tint)
                .padding(.top, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
    }

    // MARK: - Dummy Order Row

    /// Practice order row that mirrors `OrderRowView`'s visual structure.
    ///
    /// Uses matching font sizes, spacing, and color semantics to maintain
    /// Gestalt similarity with the real order list.
    private var dummyOrderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: Customer name + status (matches OrderRowView)
            HStack {
                Text("Zahra Nur")
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(dummyStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 76, alignment: .leading)
            }

            // Row 2: Items summary (matches OrderRowView.itemsSummary)
            Text("2x Brownies · 1x Kue Keju")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Row 3: Deadline + source (matches OrderRowView.deadlineIndicator)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text("Hari ini · 14.00")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.teal)

                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                    Text("WhatsApp")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Spacer()
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if currentStep == .swipeRight {
                Button {
                    completeSwipeRight()
                } label: {
                    Label("Diproses", systemImage: "arrow.triangle.2.circlepath")
                }
                .tint(.orange)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if currentStep == .swipeLeft {
                Button(role: .destructive) {
                    completeSwipeLeft()
                } label: {
                    Label("Hapus", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            if currentStep == .longPress {
                Button {
                    completeLongPress()
                } label: {
                    Label("Diproses", systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    completeLongPress()
                } label: {
                    Label("WhatsApp", systemImage: "message.fill")
                }

                Divider()

                Button(role: .destructive) {
                    completeLongPress()
                } label: {
                    Label("Hapus", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Done View

    private var doneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, options: .repeating.repeat(3))

            Text("Sekarang coba buat pesanan pertamamu")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        Group {
            if currentStep == .done {
                Button("Mulai") {
                    withAnimation { hasCompletedTutorial = true }
                }
                .buttonStyle(PrimaryCTAButtonStyle())
            } else {
                Button("Lewati") {
                    showSkipConfirm = true
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .confirmationDialog("Lewati tutorial?", isPresented: $showSkipConfirm) {
                    Button("Lewati") {
                        withAnimation { hasCompletedTutorial = true }
                    }
                }
            }
        }
    }

    // MARK: - Step Logic

    /// Maps the dummy status string to a semantic color via `OrderStatus`.
    private var statusColor: Color {
        guard let status = OrderStatus(rawValue: dummyStatus) else { return .teal }
        return status.foregroundColor
    }

    private func completeSwipeRight() {
        haptic.notificationOccurred(.success)
        withAnimation { dummyStatus = "Diproses" }
        markStepComplete {
            dummyStatus = "Baru"
            currentStep = .swipeLeft
        }
    }

    private func completeSwipeLeft() {
        haptic.notificationOccurred(.success)
        withAnimation { showDummyCard = false }
        markStepComplete {
            showDummyCard = true
            currentStep = .longPress
        }
    }

    private func completeLongPress() {
        haptic.notificationOccurred(.success)
        markStepComplete {
            currentStep = .done
        }
    }

    /// Shows "Berhasil!" feedback, then advances to the next step.
    ///
    /// Uses `Task.sleep` instead of `DispatchQueue.main.asyncAfter`
    /// for proper cancellation support and modern concurrency.
    private func markStepComplete(then next: @escaping () -> Void) {
        withAnimation { stepCompleted = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation {
                stepCompleted = false
                next()
            }
        }
    }
}

#Preview {
    GuidedTutorialView()
}
