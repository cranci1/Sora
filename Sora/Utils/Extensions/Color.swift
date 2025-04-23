//
//  Color.swift
//  Sulfur
//
//  Created by Dominic on 24.04.25.
//

import SwiftUI

extension Color {

    /// Intitialize SwiftUI Color via HEX String
    ///
    /// - Parameters:
    ///   - hex: The hex color string. Dont include: "#" prefix or leading / trailing whitespaces ( " " )
    init(hex: String) {
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            .sRGB,
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0,
            opacity: 1.0
        )
    }
}
