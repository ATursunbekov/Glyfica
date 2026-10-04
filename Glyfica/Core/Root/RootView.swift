//
//  RootView.swift
//  Glyfica
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var quizStore: QuizStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    var body: some View {
        ZStack {
            switch router.stage {
            case .splash:
                SplashView {
                    router.completeSplash(
                        quizCompleted: quizStore.isCompleted,
                        isPremium: subscriptionStore.isPremium
                    )
                }
                .transition(.opacity)
            case .quiz:
                QuizFlowView()
                    .transition(.opacity)
            case .paywall:
                PaywallView()
                    .transition(.opacity)
            case .mainApp:
                RootTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: router.stage)
        .preferredColorScheme(.dark)
    }
}
