//
//  CompatibilityView.swift
//  Glyfica
//

import SwiftUI

struct CompatibilityFlowContainerView: View {
    var body: some View {
        NavigationStack {
            CompatibilityView()
        }
    }
}

struct CompatibilityView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var partnerStore: PartnerStore
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = CompatibilityViewModel()

    @State private var showPartnerEditor = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NightScreen {
            if profileStore.profile == nil {
                MissingProfilePrompt(
                    title: "Add your sign before a match",
                    message: "Compatibility compares your chart with someone else’s."
                ) {
                    router.selectedTab = .profile
                }
            } else if partnerStore.partner == nil {
                emptyPartner
            } else if viewModel.isLoading {
                analyzingState
            } else if let reading = viewModel.reading {
                resultContent(reading)
            } else if let partner = partnerStore.partner {
                readyToAnalyze(partner)
            }
        }
        .navigationDestination(isPresented: $showPartnerEditor) {
            PartnerEditorView(existing: partnerStore.partner)
        }
        .onChange(of: partnerStore.partner) { _, newValue in
            viewModel.resetIfPartnerChanged(newValue)
        }
        .onAppear {
            viewModel.resetIfPartnerChanged(partnerStore.partner)
        }
    }

    // MARK: - Empty

    private var emptyPartner: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerTitle

                NightCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Who do you want to match with?")
                            .font(GlyficaFont.rounded(20, weight: .bold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text("Add their name and birth date. Then come back here and tap Analyze chemistry.")
                            .font(GlyficaFont.rounded(15))
                            .foregroundStyle(GlyficaColor.ink2)
                            .fixedSize(horizontal: false, vertical: true)

                        GlassPrimaryButton(title: "Add someone") {
                            showPartnerEditor = true
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Ready

    private func readyToAnalyze(_ partner: PartnerProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerTitle

                pairCard(
                    userName: profileStore.profile?.name ?? "You",
                    userSign: profileStore.profile?.sign ?? .libra,
                    partner: partner,
                    overall: nil
                )

                NightCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ready when you are")
                            .font(GlyficaFont.rounded(18, weight: .bold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text("We’ll compare your charts and write a chemistry reading for the two of you.")
                            .font(GlyficaFont.rounded(15))
                            .foregroundStyle(GlyficaColor.ink2)
                            .fixedSize(horizontal: false, vertical: true)

                        GlassPrimaryButton(title: "Analyze chemistry") {
                            Task {
                                await viewModel.analyze(
                                    user: profileStore.profile,
                                    partner: partner
                                )
                            }
                        }

                        Button("Change person") {
                            showPartnerEditor = true
                        }
                        .font(GlyficaFont.rounded(15, weight: .semibold))
                        .foregroundStyle(GlyficaColor.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Loading

    private var analyzingState: some View {
        VStack(spacing: 16) {
            Spacer()
            NightCard {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(GlyficaColor.gold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reading your chemistry…")
                            .font(GlyficaFont.rounded(16, weight: .semibold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text("Comparing signs, elements, and the vibe between you.")
                            .font(GlyficaFont.rounded(14))
                            .foregroundStyle(GlyficaColor.ink2)
                    }
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
    }

    // MARK: - Result

    private func resultContent(_ reading: CompatibilityReading) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerTitle

                if let partner = partnerStore.partner {
                    pairCard(
                        userName: profileStore.profile?.name ?? "You",
                        userSign: reading.userSign,
                        partner: partner,
                        overall: reading.overall
                    )
                }

                NightCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(reading.headline)
                            .font(GlyficaFont.rounded(20, weight: .bold))
                            .foregroundStyle(GlyficaColor.gold)
                        Text(reading.summary)
                            .font(GlyficaFont.rounded(15))
                            .foregroundStyle(GlyficaColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(reading.areas) { area in
                        NightCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(area.score)")
                                    .font(GlyficaFont.rounded(26, weight: .bold))
                                    .foregroundStyle(GlyficaColor.score(area.score))
                                Text(area.title)
                                    .font(GlyficaFont.rounded(13, weight: .bold))
                                    .foregroundStyle(GlyficaColor.ink2)
                                    .textCase(.uppercase)
                                    .tracking(0.6)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(GlyficaColor.line)
                                        Capsule()
                                            .fill(GlyficaColor.score(area.score))
                                            .frame(width: geo.size.width * CGFloat(area.score) / 100)
                                    }
                                }
                                .frame(height: 5)
                            }
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                        }
                    }
                }

                if !reading.tip.isEmpty {
                    NightCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Try this")
                                .font(GlyficaFont.rounded(13, weight: .semibold))
                                .foregroundStyle(GlyficaColor.gold)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Text(reading.tip)
                                .font(GlyficaFont.rounded(15))
                                .foregroundStyle(GlyficaColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(spacing: 10) {
                    Button("Change person") {
                        viewModel.clearReading()
                        showPartnerEditor = true
                    }
                    .font(GlyficaFont.rounded(15, weight: .semibold))
                    .foregroundStyle(GlyficaColor.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(GlyficaColor.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GlyficaColor.line, lineWidth: 1)
                    )

                    Button("Analyze again") {
                        Task {
                            await viewModel.analyze(
                                user: profileStore.profile,
                                partner: partnerStore.partner,
                                force: true
                            )
                        }
                    }
                    .font(GlyficaFont.rounded(15, weight: .semibold))
                    .foregroundStyle(GlyficaColor.ink2)
                    .frame(maxWidth: .infinity)
                }

                Text("For entertainment only. Not medical, financial, or legal advice.")
                    .font(GlyficaFont.rounded(11))
                    .foregroundStyle(GlyficaColor.ink2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Shared

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Match")
                .font(GlyficaFont.rounded(28, weight: .bold))
                .foregroundStyle(GlyficaColor.ink)
            Text("See how two charts meet.")
                .font(GlyficaFont.rounded(14))
                .foregroundStyle(GlyficaColor.ink2)
        }
    }

    private func pairCard(
        userName: String,
        userSign: ZodiacSign,
        partner: PartnerProfile,
        overall: Int?
    ) -> some View {
        NightCard {
            VStack(spacing: 14) {
                HStack {
                    personColumn(name: userName, sign: userSign)
                    Spacer()
                    if let overall {
                        Text("\(overall)%")
                            .font(GlyficaFont.rounded(28, weight: .bold))
                            .foregroundStyle(GlyficaColor.bg)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(GlyficaColor.score(overall), in: Capsule())
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(GlyficaColor.gold)
                    }
                    Spacer()
                    personColumn(name: partner.name, sign: partner.sign)
                }
            }
        }
    }

    private func personColumn(name: String, sign: ZodiacSign) -> some View {
        VStack(spacing: 6) {
            SignGlyph(sign: sign, size: 36)
            Text(name)
                .font(GlyficaFont.rounded(14, weight: .semibold))
                .foregroundStyle(GlyficaColor.ink)
                .lineLimit(1)
            Text(sign.title)
                .font(GlyficaFont.rounded(12))
                .foregroundStyle(GlyficaColor.ink2)
        }
        .frame(maxWidth: 110)
    }
}
