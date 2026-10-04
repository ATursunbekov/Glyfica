//
//  GlyficaColor.swift
//  Glyfica
//
//  Night-sky navy + gold palette, matched to the starfield background.
//  Base colors live in Assets.xcassets; score colors stay in code.
//

import SwiftUI

enum GlyficaColor {
    static let bg = Color("GlyficaBG")
    static let surface = Color("GlyficaSurface")
    static let surface2 = Color("GlyficaSurface2")
    static let gold = Color("GlyficaGold")
    static let ink = Color("GlyficaInk")
    static let ink2 = Color("GlyficaInk").opacity(0.64)
    static let line = Color("GlyficaInk").opacity(0.10)
    static let danger = Color(hex: 0xE85A5A)
    static let scoreHigh = Color(hex: 0x3DDC84)
    static let scoreMid = Color(hex: 0xF5C518)
    static let scoreLow = Color(hex: 0xF05A4A)

    static func score(_ value: Int) -> Color {
        if value >= 75 { return scoreHigh }
        if value >= 55 { return scoreMid }
        return scoreLow
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
