//
//  HoroscopeViewModel.swift
//  Glyfica
//

import Combine
import Foundation

@MainActor
final class HoroscopeViewModel: ObservableObject {
    @Published private(set) var fullReading: FullPersonalityReading?
    @Published private(set) var isLoadingFull = false

    private var loadedForPremium = false

    func reading(for profile: BirthProfile?) -> HoroscopeReading? {
        profile.map(HoroscopeService.reading(for:))
    }

    func loadFullReadingIfNeeded(profile: BirthProfile?, isPremium: Bool) async {
        guard isPremium, let profile else {
            fullReading = nil
            loadedForPremium = false
            return
        }

        if loadedForPremium, fullReading != nil { return }

        isLoadingFull = true
        defer { isLoadingFull = false }

        fullReading = await ReadingService.fetchPersonalityReading(for: profile)
        loadedForPremium = true
    }

    func refreshFullReading(profile: BirthProfile?) async {
        guard let profile else { return }
        isLoadingFull = true
        defer { isLoadingFull = false }
        fullReading = await ReadingService.fetchPersonalityReading(for: profile, force: true)
        loadedForPremium = true
    }
}
