//
//  RootTabView.swift
//  Glyfica
//
//  Five-tab shell: Horoscope, Today, Tarot, Oracle hub, Profile.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case horoscope
    case forecast
    case tarot
    case oracle
    case profile

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .horoscope: return "Horoscope"
        case .forecast: return "Today"
        case .tarot: return "Tarot"
        case .oracle: return "Oracle"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .horoscope: return "sparkles"
        case .forecast: return "sun.max"
        case .tarot: return "rectangle.stack.fill"
        case .oracle: return "moon.stars"
        case .profile: return "person.crop.circle"
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.icon, value: tab) {
                    screen(for: tab)
                }
            }
        }
        .tint(GlyficaColor.gold)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: router.selectedTab) { _, _ in
            Haptics.tap()
        }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .horoscope: HoroscopeFlowContainerView()
        case .forecast: DailyForecastFlowContainerView()
        case .tarot: TarotFlowContainerView()
        case .oracle: ReadingsFlowContainerView()
        case .profile: ProfileFlowContainerView()
        }
    }
}
