//
//  ItemRowEditor.swift
//  Sortala
//

import SwiftUI

// MARK: - DraftItem

/// Transient model for form editing before persisting to SwiftData.
struct DraftItem: Identifiable {
    let id = UUID()
    var productName: String = ""
    var quantity: Int = 1

    init(from orderItem: OrderItem) {
        self.productName = orderItem.productName
        self.quantity = orderItem.quantity
    }

    init(productName: String = "", quantity: Int = 1) {
        self.productName = productName
        self.quantity = quantity
    }
}

// MARK: - ItemRowEditor

struct ItemRowEditor: View {
    @Binding var item: DraftItem

    var body: some View {
        TextField("Nama produk", text: $item.productName)
        Stepper("\(item.quantity) pcs", value: $item.quantity, in: 1 ... 99)
            .monospacedDigit()
    }
}
