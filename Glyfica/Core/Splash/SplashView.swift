//
//  SplashView.swift
//  Glyfica
//

import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var quizStore: QuizStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var partnerStore: PartnerStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoVisible = false
    @State private var glowExpanded = false
    @State private var titleVisible = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [GlyficaColor.gold.opacity(0.55), GlyficaColor.gold.opacity(0)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .scaleEffect(glowExpanded ? 1.12 : 0.8)
                        .opacity(logoVisible ? 1 : 0)

                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .scaleEffect(logoVisible || reduceMotion ? 1 : 0.6)
                        .opacity(logoVisible ? 1 : 0)
                }

                Text("GLYFICA")
                    .font(GlyficaFont.rounded(26, weight: .semibold))
                    .tracking(titleVisible ? 8 : 2)
                    .foregroundStyle(GlyficaColor.ink)
                    .opacity(titleVisible ? 1 : 0)
            }
        }
        .task { await bootstrap() }
    }

    private func bootstrap() async {
        async let animation: Void = playAnimation()
        // Anonymous Auth is the first real work of the launch.
        await session.waitUntilReady()
        quizStore.attach(uid: session.uid)
        await profileStore.attach(uid: session.uid)
        await partnerStore.attach(uid: session.uid)
        await subscriptionStore.attach(uid: session.uid)
        await animation
        onFinished()
    }

    private func playAnimation() async {
        withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.8, dampingFraction: 0.7)) {
            logoVisible = true
        }
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                glowExpanded = true
            }
        }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeOut(duration: 0.7)) {
            titleVisible = true
        }
        try? await Task.sleep(for: .milliseconds(1_450))
    }
}
