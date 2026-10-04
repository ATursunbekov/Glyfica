//
//  CompatibilityService.swift
//  Glyfica
//
//  Local fallback when generateReading(type: compatibility) is offline.
//

import Foundation

enum CompatibilityService {
    static func reading(user: ZodiacSign, partnerName: String, partner: ZodiacSign) -> CompatibilityReading {
        let overall = overallScore(user, partner)
        let titles = ["Love", "Passion", "Trust", "Values", "Emotions", "Marriage"]
        let areas = titles.enumerated().map { index, title in
            let shift = (overall + index * 7 + user.sortIndex + partner.sortIndex * 2) % 17 - 8
            let score = min(99, max(34, overall + shift))
            return CompatibilityArea(title: title, score: score)
        }
        let displayName = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = displayName.isEmpty ? "Them" : displayName
        return CompatibilityReading(
            userSign: user,
            partnerName: name,
            partnerSign: partner,
            overall: overall,
            headline: headline(user, partner, overall: overall),
            summary: summary(user, partner, overall: overall),
            tip: tip(user, partner),
            areas: areas
        )
    }

    private static func overallScore(_ user: ZodiacSign, _ partner: ZodiacSign) -> Int {
        let base: Int
        if user == partner {
            base = 90
        } else {
            switch (user.element, partner.element) {
            case let (lhs, rhs) where lhs == rhs:
                base = 86
            case (.fire, .air), (.air, .fire), (.earth, .water), (.water, .earth):
                base = 78
            default:
                base = 62
            }
        }
        let wobble = (user.sortIndex * 5 + partner.sortIndex * 3) % 9 - 4
        return min(96, max(46, base + wobble))
    }

    private static func headline(_ user: ZodiacSign, _ partner: ZodiacSign, overall: Int) -> String {
        if user == partner { return "Same sign, shared tempo" }
        if user.element == partner.element { return "Familiar chemistry" }
        if overall >= 75 { return "A match that can grow" }
        return "Different rhythms, real potential"
    }

    private static func summary(_ user: ZodiacSign, _ partner: ZodiacSign, overall: Int) -> String {
        if user.element == partner.element {
            return "\(user.title) and \(partner.title) share an element. The match feels familiar fast, and the work is not to assume you already understand each other.\n\nStay curious about the small differences — those are usually where the relationship gets interesting."
        }
        if overall >= 75 {
            return "\(user.title) and \(partner.title) pull in directions that can feed each other. The match stays good when neither person has to shrink.\n\nName needs early. Attraction is easier than clarity, and clarity is what keeps this warm."
        }
        return "\(user.title) and \(partner.title) do not read the room the same way. The match needs plain language more than it needs a grand gesture.\n\nIf you slow the pace on hard days, the connection has room to breathe."
    }

    private static func tip(_ user: ZodiacSign, _ partner: ZodiacSign) -> String {
        "Between \(user.title) and \(partner.title), one honest check-in beats three silent assumptions."
    }
}
