//
//  Haptics.swift
//  Glyfica
//

import SwiftUI
import UIKit

enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)

    /// Medium tap used for buttons and tab switches across the app.
    static func tap() {
        impact.prepare()
        impact.impactOccurred(intensity: 1.0)
    }

    static func wrap(_ action: @escaping () -> Void) -> () -> Void {
        {
            tap()
            action()
        }
    }
}

/// Plain look with a light tap haptic on press.
struct GlyficaPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap() }
            }
    }
}

extension ButtonStyle where Self == GlyficaPlainButtonStyle {
    static var glyficaPlain: GlyficaPlainButtonStyle { GlyficaPlainButtonStyle() }
}

/// Default style for unstyled buttons — keeps them tappable with a soft press + haptic.
struct GlyficaDefaultButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap() }
            }
    }
}
