//
//  GlyficaFont.swift
//  Glyfica
//

import SwiftUI

enum GlyficaFont {
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
