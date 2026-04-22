//
//  StatusHelpers.swift
//  Sortala
//

import SwiftUI

// MARK: - OrderStatus UI

extension OrderStatus {
    var icon: String {
        switch self {
        case .baru: return "circle"
        case .diproses: return "arrow.triangle.2.circlepath"
        case .selesai: return "checkmark.circle"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .baru: return .teal
        case .diproses: return .orange
        case .selesai: return .green
        }
    }

    var backgroundColor: Color {
        switch self {
        case .baru: return .statusBaru
        case .diproses: return .statusDiproses
        case .selesai: return .statusSelesai
        }
    }

    /// Next status in the workflow, nil if already complete.
    var nextStatus: OrderStatus? {
        switch self {
        case .baru: return .diproses
        case .diproses: return .selesai
        case .selesai: return nil
        }
    }
}

// MARK: - OrderSource UI

extension OrderSource {
    /// Semantic SF Symbol representing the communication channel.
    var icon: String {
        switch self {
        case .whatsapp: return "bubble.left.fill"
        case .instagram: return "camera.fill"
        case .langsung: return "person.fill"
        case .lainnya: return "ellipsis.circle.fill"
        }
    }
}
