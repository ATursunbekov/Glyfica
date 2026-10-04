//
//  DailyForecastViewModel.swift
//  Glyfica
//

import Combine
import Foundation

@MainActor
final class DailyForecastViewModel: ObservableObject {
    @Published private(set) var forecast: DailyForecast?
    @Published private(set) var isLoading = false

    private var loadedDateKey: String?

    func loadIfNeeded(profile: BirthProfile?, date: Date = .now) async {
        guard let profile else {
            forecast = nil
            loadedDateKey = nil
            return
        }

        let key = DailyForecastService.dateKey(for: date)
        if loadedDateKey == key, forecast != nil { return }

        isLoading = true
        defer { isLoading = false }

        forecast = await ReadingService.fetchDailyForecast(for: profile, on: date)
        loadedDateKey = key
    }

    func refresh(profile: BirthProfile?, date: Date = .now) async {
        guard let profile else { return }
        isLoading = true
        defer { isLoading = false }
        forecast = await ReadingService.fetchDailyForecast(for: profile, on: date, force: true)
        loadedDateKey = DailyForecastService.dateKey(for: date)
    }

    func greeting(for date: Date = .now, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }
}
