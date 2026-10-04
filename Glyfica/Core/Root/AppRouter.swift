//
//  AppRouter.swift
//  Glyfica
//
//  Splash → quiz → paywall (if needed) → main tabs.
//

import Combine
import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    enum Stage: Equatable {
        case splash
        case quiz
        case paywall
        case mainApp
    }

    @Published var stage: Stage = .splash
    @Published var selectedTab: AppTab = .horoscope
    /// When true, paywall shows "Not now" (opened from inside the app).
    @Published var allowsPaywallSkip = false

    func completeSplash(quizCompleted: Bool, isPremium: Bool) {
        if !quizCompleted {
            stage = .quiz
        } else if !isPremium {
            allowsPaywallSkip = true
            stage = .paywall
        } else {
            stage = .mainApp
        }
    }

    func completeQuiz() {
        allowsPaywallSkip = false
        stage = .paywall
    }

    func completePaywall() {
        allowsPaywallSkip = false
        stage = .mainApp
    }

    func skipPaywall() {
        allowsPaywallSkip = false
        stage = .mainApp
    }

    func openPaywall(allowSkip: Bool = true) {
        allowsPaywallSkip = allowSkip
        stage = .paywall
    }

    func restartOnboarding() {
        selectedTab = .horoscope
        allowsPaywallSkip = false
        stage = .quiz
    }
}
