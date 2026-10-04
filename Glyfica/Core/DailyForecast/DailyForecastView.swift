//
//  DailyForecastView.swift
//  Glyfica
//

import SwiftUI

struct DailyForecastFlowContainerView: View {
    var body: some View {
        NavigationStack {
            DailyForecastView()
        }
    }
}

struct DailyForecastView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = DailyForecastViewModel()

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NightScreen {
            if profileStore.profile == nil {
                MissingProfilePrompt(
                    title: "Today needs your birth details",
                    message: "Add your name and birth date so we can write a forecast that fits your chart."
                ) {
                    router.selectedTab = .profile
                }
            } else if let forecast = viewModel.forecast {
                content(forecast)
            } else {
                loadingState
            }
        }
        .task(id: profileStore.profile?.name) {
            await viewModel.loadIfNeeded(profile: profileStore.profile)
        }
        .refreshable {
            await viewModel.refresh(profile: profileStore.profile)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            NightCard {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(GlyficaColor.gold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Writing today’s forecast…")
                            .font(GlyficaFont.rounded(16, weight: .semibold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text("Personalizing for your sign and focus.")
                            .font(GlyficaFont.rounded(14))
                            .foregroundStyle(GlyficaColor.ink2)
                    }
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
    }

    private func content(_ forecast: DailyForecast) -> some View {
        let name = profileStore.profile?.name ?? ""

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(name: name, date: forecast.date)

                NightCard {
                    HStack(spacing: 14) {
                        SignGlyph(sign: forecast.sign, size: 72)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(forecast.sign.title)
                                .font(GlyficaFont.rounded(13, weight: .semibold))
                                .foregroundStyle(GlyficaColor.gold)
                            Text(forecast.headline)
                                .font(GlyficaFont.rounded(22, weight: .bold))
                                .foregroundStyle(GlyficaColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                NightCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focus of the day")
                            .font(GlyficaFont.rounded(12, weight: .semibold))
                            .foregroundStyle(GlyficaColor.gold)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Text(forecast.focus)
                            .font(GlyficaFont.rounded(17, weight: .semibold))
                            .foregroundStyle(GlyficaColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                NightCard {
                    Text(forecast.summary)
                        .font(GlyficaFont.rounded(16))
                        .foregroundStyle(GlyficaColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    moodTile("Love", forecast.love)
                    moodTile("Energy", forecast.energy)
                    moodTile("Mood", forecast.mood)
                    moodTile("Luck", forecast.luck)
                }

                if !forecast.doToday.isEmpty || !forecast.avoidToday.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        tipCard(
                            title: "Do today",
                            body: forecast.doToday,
                            tint: GlyficaColor.scoreHigh
                        )
                        tipCard(
                            title: "Go easy on",
                            body: forecast.avoidToday,
                            tint: GlyficaColor.gold
                        )
                    }
                }

                if !forecast.loveTip.isEmpty {
                    NightCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Love", systemImage: "heart.fill")
                                .font(GlyficaFont.rounded(13, weight: .semibold))
                                .foregroundStyle(GlyficaColor.gold)
                            Text(forecast.loveTip)
                                .font(GlyficaFont.rounded(15))
                                .foregroundStyle(GlyficaColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if !forecast.workTip.isEmpty {
                    NightCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Work & decisions", systemImage: "briefcase.fill")
                                .font(GlyficaFont.rounded(13, weight: .semibold))
                                .foregroundStyle(GlyficaColor.gold)
                            Text(forecast.workTip)
                                .font(GlyficaFont.rounded(15))
                                .foregroundStyle(GlyficaColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text("For entertainment only. Not medical, financial, or legal advice.")
                    .font(GlyficaFont.rounded(11))
                    .foregroundStyle(GlyficaColor.ink2)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    private func header(name: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.greeting())
                .font(GlyficaFont.rounded(14, weight: .medium))
                .foregroundStyle(GlyficaColor.gold)

            if name.isEmpty {
                Text("Today")
                    .font(GlyficaFont.rounded(30, weight: .bold))
                    .foregroundStyle(GlyficaColor.ink)
            } else {
                Text("\(name)’s day")
                    .font(GlyficaFont.rounded(30, weight: .bold))
                    .foregroundStyle(GlyficaColor.ink)
            }

            Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(GlyficaFont.rounded(15))
                .foregroundStyle(GlyficaColor.ink2)
        }
    }

    private func moodTile(_ title: String, _ value: Int) -> some View {
        NightCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(GlyficaFont.rounded(12, weight: .semibold))
                    .foregroundStyle(GlyficaColor.ink2)

                Text("\(value)")
                    .font(GlyficaFont.rounded(28, weight: .bold))
                    .foregroundStyle(GlyficaColor.score(value))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(GlyficaColor.line)
                        Capsule()
                            .fill(GlyficaColor.score(value))
                            .frame(width: geo.size.width * CGFloat(value) / 100)
                    }
                }
                .frame(height: 5)
            }
        }
    }

    private func tipCard(title: String, body: String, tint: Color) -> some View {
        NightCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(GlyficaFont.rounded(12, weight: .bold))
                    .foregroundStyle(tint)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(body)
                    .font(GlyficaFont.rounded(14))
                    .foregroundStyle(GlyficaColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
