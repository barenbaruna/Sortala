//
//  GuidedTutorialView.swift
//  Sortala
//

import SwiftUI

// MARK: - Tutorial Step

private enum TutorialStep: Int, CaseIterable {
    case swipeRight = 0
    case swipeLeft = 1
    case longPress = 2
    case done = 3
    
    var instruction: String {
        switch self {
        case .swipeRight: return "Geser pesanan ke kanan →\nuntuk memajukan status"
        case .swipeLeft: return "← Geser pesanan ke kiri\nuntuk menghapus"
        case .longPress: return "Tekan & tahan pesanan\nuntuk menu cepat"
        case .done: return "Kamu siap menggunakan Sortala!"
        }
    }
    
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

struct GuidedTutorialView: View {
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @State private var currentStep: TutorialStep = .swipeRight
    @State private var dummyStatus: String = "Baru"
    @State private var showDummyCard = true
    @State private var showContextMenuHint = false
    @State private var stepCompleted = false
    
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
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep.rawValue ? Color.teal : Color(.systemFill))
                    .frame(height: 4)
            }
        }
    }
    
    // MARK: - Instruction Card
    
    private var instructionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: currentStep.icon)
                .font(.system(size: 36))
                .foregroundStyle(.teal)
                .contentTransition(.symbolEffect(.replace))
            
            Text(currentStep.instruction)
                .font(.title3)
                .fontWeight(.semibold)
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
            Text("COBA DI SINI")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 36)
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
                Label("Berhasil!", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Dummy Order Row
    
    private var dummyOrderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
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
            }
            
            HStack(spacing: 4) {
                Image(systemName: "message.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("2x Brownies · 1x Kue Keju")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                Text("Hari ini · 14.00")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.teal)
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
                
                Button {} label: {
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
                .foregroundStyle(.teal)
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
                Button {
                    withAnimation { hasCompletedTutorial = true }
                } label: {
                    Text("Mulai")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                }
            } else {
                Button {
                    withAnimation { hasCompletedTutorial = true }
                } label: {
                    Text("Lewati")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Step Logic
    
    private var statusColor: Color {
        switch dummyStatus {
        case "Diproses": return .orange
        case "Selesai": return .green
        default: return .teal
        }
    }
    
    private func completeSwipeRight() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { dummyStatus = "Diproses" }
        markStepComplete {
            dummyStatus = "Baru"
            currentStep = .swipeLeft
        }
    }
    
    private func completeSwipeLeft() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { showDummyCard = false }
        markStepComplete {
            showDummyCard = true
            currentStep = .longPress
        }
    }
    
    private func completeLongPress() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        markStepComplete {
            currentStep = .done
        }
    }
    
    private func markStepComplete(then next: @escaping () -> Void) {
        withAnimation { stepCompleted = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
