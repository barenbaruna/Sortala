//
//  Models.swift
//  Sortala
//

import Foundation
import SwiftData

// MARK: - OrderStatus

/// Workflow status: Baru → Diproses → Selesai
enum OrderStatus: String, CaseIterable, Codable {
    case baru = "Baru"
    case diproses = "Diproses"
    case selesai = "Selesai"
}

// MARK: - OrderSource

/// Channel asal pesanan masuk.
enum OrderSource: String, CaseIterable, Codable {
    case whatsapp = "WhatsApp"
    case instagram = "Instagram"
    case langsung = "Langsung"
}

// MARK: - OrderItem

@Model
final class OrderItem {
    var id: UUID
    var productName: String
    var quantity: Int

    init(productName: String = "", quantity: Int = 1) {
        self.id = UUID()
        self.productName = productName
        self.quantity = quantity
    }
}

// MARK: - Order

@Model
final class Order {
    var id: UUID
    var createdAt: Date
    var customerName: String
    var whatsappNumber: String
    var address: String

    @Relationship(deleteRule: .cascade)
    var items: [OrderItem]

    var deadline: Date
    var orderSource: OrderSource
    var notes: String
    var status: OrderStatus

    var isDueToday: Bool {
        Calendar.current.isDateInToday(deadline)
    }

    var isOverdue: Bool {
        deadline < Date() && status != .selesai
    }

    /// Format: "2x Brownies · 1x Kue Keju"
    var itemsSummary: String {
        if items.isEmpty { return "Belum ada produk" }
        return items.map { "\($0.quantity)x \($0.productName)" }
            .joined(separator: " · ")
    }

    init(
        customerName: String = "",
        whatsappNumber: String = "",
        address: String = "",
        items: [OrderItem] = [],
        deadline: Date = Date().addingTimeInterval(86400),
        orderSource: OrderSource = .whatsapp,
        notes: String = "",
        status: OrderStatus = .baru
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.customerName = customerName
        self.whatsappNumber = whatsappNumber
        self.address = address
        self.items = items
        self.deadline = deadline
        self.orderSource = orderSource
        self.notes = notes
        self.status = status
    }
}
