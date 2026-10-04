//
//  RootTabView.swift
//  Glyfica
//
//  Four-tab shell on the system TabView, so the bar is Liquid Glass and
//  collapses while a screen scrolls down.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case horoscope
    case forecast
    case compatibility
    case profile

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .horoscope: return "Horoscope"
        case .forecast: return "Today"
        case .compatibility: return "Match"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .horoscope: return "sparkles"
        case .forecast: return "sun.max"
        case .compatibility: return "heart"
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
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .horoscope: HoroscopeFlowContainerView()
        case .forecast: DailyForecastFlowContainerView()
        case .compatibility: CompatibilityFlowContainerView()
        case .profile: ProfileFlowContainerView()
        }
    }
}
