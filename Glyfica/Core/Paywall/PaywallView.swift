//
//  PaywallView.swift
//  Glyfica
//

import SwiftUI
import UIKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var isPurchasing = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if router.allowsPaywallSkip {
                        Button("Not now") {
                            router.skipPaywall()
                        }
                        .font(GlyficaFont.rounded(14, weight: .medium))
                        .foregroundStyle(GlyficaColor.ink2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 20) {
                        header
                        planList
                        GlassPrimaryButton(
                            title: isPurchasing ? "Unlocking..." : "Continue with \(selectedPlan.title.lowercased())"
                        ) {
                            Task { await purchase() }
                        }
                        .disabled(isPurchasing || subscriptionStore.isLoading)
                        .padding(.top, 4)

                        Text("Simulated purchase for testing. StoreKit will replace this later.")
                            .font(GlyficaFont.rounded(12))
                            .foregroundStyle(GlyficaColor.ink2)
                            .multilineTextAlignment(.center)

                        legal
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 14) {
            if let sign = profileStore.profile?.sign {
                SignGlyph(sign: sign, size: 88)
            } else {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
            }

            Text("Unlock your full reading")
                .font(GlyficaFont.rounded(28, weight: .bold))
                .foregroundStyle(GlyficaColor.ink)
                .multilineTextAlignment(.center)

            Text("Core self, love, decisions, life path, and guidance for right now — kept for your chart.")
                .font(GlyficaFont.rounded(15))
                .foregroundStyle(GlyficaColor.ink2)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                benefit("Full personality reading")
                benefit("Daily forecast for your sign")
                benefit("Compatibility insights")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var planList: some View {
        VStack(spacing: 10) {
            ForEach(SubscriptionPlan.allCases) { plan in
                Button {
                    selectedPlan = plan
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(plan.title)
                                    .font(GlyficaFont.rounded(17, weight: .bold))
                                    .foregroundStyle(GlyficaColor.ink)
                                if plan == .yearly {
                                    Text("BEST VALUE")
                                        .font(GlyficaFont.rounded(10, weight: .bold))
                                        .foregroundStyle(GlyficaColor.bg)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(GlyficaColor.gold, in: Capsule())
                                }
                            }
                            Text(plan.priceLabel)
                                .font(GlyficaFont.rounded(14, weight: .semibold))
                                .foregroundStyle(GlyficaColor.gold)
                            Text(plan.detail)
                                .font(GlyficaFont.rounded(12))
                                .foregroundStyle(GlyficaColor.ink2)
                        }
                        Spacer()
                        Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(selectedPlan == plan ? GlyficaColor.gold : GlyficaColor.ink2)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(GlyficaColor.surface.opacity(0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                selectedPlan == plan ? GlyficaColor.gold.opacity(0.75) : GlyficaColor.line,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.glyficaPlain)
            }
        }
    }

    private var legal: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button("Privacy") { UIApplication.shared.open(Constants.privacyPolicyURL) }
                Button("Terms") { UIApplication.shared.open(Constants.termsOfUseURL) }
            }
            .font(GlyficaFont.rounded(12, weight: .medium))
            .foregroundStyle(GlyficaColor.ink2)

            Text("For entertainment only. Not medical, financial, or legal advice.")
                .font(GlyficaFont.rounded(11))
                .foregroundStyle(GlyficaColor.ink2)
                .multilineTextAlignment(.center)
        }
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(GlyficaColor.gold)
            Text(text)
                .font(GlyficaFont.rounded(14))
                .foregroundStyle(GlyficaColor.ink)
        }
    }

    private func purchase() async {
        isPurchasing = true
        await subscriptionStore.simulatePurchase(selectedPlan)
        isPurchasing = false
        router.completePaywall()
    }
}
