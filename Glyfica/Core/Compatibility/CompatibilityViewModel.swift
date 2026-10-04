//
//  CompatibilityViewModel.swift
//  Glyfica
//

import Combine
import Foundation

@MainActor
final class CompatibilityViewModel: ObservableObject {
    @Published private(set) var reading: CompatibilityReading?
    @Published private(set) var isLoading = false
    @Published private(set) var analyzedPartnerKey: String?

    func partnerKey(for partner: PartnerProfile?) -> String? {
        guard let partner else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(partner.name.lowercased())|\(formatter.string(from: partner.birthDate))|\(partner.sign.rawValue)"
    }

    func resetIfPartnerChanged(_ partner: PartnerProfile?) {
        let key = partnerKey(for: partner)
        if key != analyzedPartnerKey {
            reading = nil
            analyzedPartnerKey = nil
        }
    }

    func analyze(user: BirthProfile?, partner: PartnerProfile?, force: Bool = false) async {
        guard let user, let partner else { return }
        isLoading = true
        defer { isLoading = false }

        let result = await ReadingService.fetchCompatibilityReading(
            user: user,
            partner: partner,
            force: force
        )
        reading = result
        analyzedPartnerKey = partnerKey(for: partner)
    }

    func clearReading() {
        reading = nil
        analyzedPartnerKey = nil
    }
}
