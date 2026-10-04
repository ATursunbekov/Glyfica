//
//  HoroscopeView.swift
//  Glyfica
//

import SwiftUI

struct HoroscopeFlowContainerView: View {
    var body: some View {
        NavigationStack {
            HoroscopeView()
        }
    }
}

struct HoroscopeView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = HoroscopeViewModel()

    var body: some View {
        NightScreen {
            if let reading = viewModel.reading(for: profileStore.profile) {
                chart(reading)
            } else {
                MissingProfilePrompt(
                    title: "Your chart starts with a birth date",
                    message: "Sun sign and life path number are calculated from the date you save in Profile."
                ) {
                    router.selectedTab = .profile
                }
            }
        }
        .task(id: "\(subscriptionStore.isPremium)-\(profileStore.profile?.name ?? "")") {
            await viewModel.loadFullReadingIfNeeded(
                profile: profileStore.profile,
                isPremium: subscriptionStore.isPremium
            )
        }
    }

    private func chart(_ reading: HoroscopeReading) -> some View {
        let isPremium = subscriptionStore.isPremium

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reading.profile.name)
                        .font(GlyficaFont.rounded(28, weight: .bold))
                        .foregroundStyle(GlyficaColor.ink)
                    Text(reading.profile.birthDate.formatted(date: .long, time: .omitted))
                        .font(GlyficaFont.rounded(14))
                        .foregroundStyle(GlyficaColor.ink2)
                }

                NightCard {
                    HStack(alignment: .center, spacing: 12) {
                        signColumn(label: "Sun sign", value: reading.sign.title)
                        Spacer()
                        SignGlyph(sign: reading.sign, size: 96)
                        Spacer()
                        signColumn(label: "Element", value: reading.sign.element.title)
                    }
                }

                NightCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Life path")
                            .font(GlyficaFont.rounded(13, weight: .medium))
                            .foregroundStyle(GlyficaColor.ink2)
                        Text("\(reading.lifePath)")
                            .font(GlyficaFont.rounded(40, weight: .bold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text(reading.lifePathText)
                            .font(GlyficaFont.rounded(15))
                            .foregroundStyle(GlyficaColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                NightCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reading.sign.title)
                            .font(GlyficaFont.rounded(18, weight: .bold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text(reading.sign.personality)
                            .font(GlyficaFont.rounded(15))
                            .foregroundStyle(GlyficaColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if isPremium {
                    if viewModel.isLoadingFull, viewModel.fullReading == nil {
                        NightCard {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(GlyficaColor.gold)
                                Text("Writing your full reading…")
                                    .font(GlyficaFont.rounded(15))
                                    .foregroundStyle(GlyficaColor.ink2)
                            }
                        }
                    } else if let full = viewModel.fullReading {
                        ForEach(full.sections) { section in
                            NightCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(section.title)
                                        .font(GlyficaFont.rounded(18, weight: .bold))
                                        .foregroundStyle(GlyficaColor.gold)
                                    Text(section.body)
                                        .font(GlyficaFont.rounded(15))
                                        .foregroundStyle(GlyficaColor.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        Text("For entertainment only. Not medical, financial, or legal advice.")
                            .font(GlyficaFont.rounded(11))
                            .foregroundStyle(GlyficaColor.ink2)
                    }
                } else {
                    lockedPreview
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private var lockedPreview: some View {
        NightCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Full reading")
                    .font(GlyficaFont.rounded(18, weight: .bold))
                    .foregroundStyle(GlyficaColor.ink)

                ZStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Core self")
                            .font(GlyficaFont.rounded(15, weight: .semibold))
                            .foregroundStyle(GlyficaColor.gold)
                        Text("Your full character map, love tone, decision style, life-path reading, and guidance for right now are ready.")
                            .font(GlyficaFont.rounded(15))
                            .foregroundStyle(GlyficaColor.ink2)
                        Text("Love & bonds · Work & decisions · Life path · Right now")
                            .font(GlyficaFont.rounded(14))
                            .foregroundStyle(GlyficaColor.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .blur(radius: 3.5)

                    LinearGradient(
                        colors: [.clear, GlyficaColor.surface.opacity(0.98)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 72)
                }

                GlassPrimaryButton(title: "Unlock full reading") {
                    router.openPaywall(allowSkip: true)
                }
            }
        }
    }

    private func signColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(GlyficaFont.rounded(12))
                .foregroundStyle(GlyficaColor.gold)
            Text(value)
                .font(GlyficaFont.rounded(16, weight: .semibold))
                .foregroundStyle(GlyficaColor.ink)
        }
        .frame(maxWidth: 90, alignment: .leading)
    }
}
