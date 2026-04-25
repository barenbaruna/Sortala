//
//  AdaptiveColors.swift
//  Sortala
//

import SwiftUI

// MARK: - Adaptive Colors (Light/Dark Mode)

extension Color {
    /// Overdue row background — subtle red tint that remains visible in both modes.
    static let overdueRowBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemRed.withAlphaComponent(0.12)
            : UIColor.systemRed.withAlphaComponent(0.05)
    })
    
    /// Today row background — subtle teal tint.
    static let todayRowBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemTeal.withAlphaComponent(0.10)
            : UIColor.systemTeal.withAlphaComponent(0.05)
    })
    
    /// Status capsule backgrounds — adaptive for contrast in both modes.
    static let statusBaru = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemTeal.withAlphaComponent(0.25)
            : UIColor.systemTeal.withAlphaComponent(0.12)
    })
    
    static let statusDiproses = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemOrange.withAlphaComponent(0.25)
            : UIColor.systemOrange.withAlphaComponent(0.12)
    })
    
    static let statusSelesai = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemGreen.withAlphaComponent(0.25)
            : UIColor.systemGreen.withAlphaComponent(0.12)
    })
    
    /// Preset button selected background.
    static let presetSelected = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemTeal.withAlphaComponent(0.25)
            : UIColor.systemTeal.withAlphaComponent(0.12)
    })
}
