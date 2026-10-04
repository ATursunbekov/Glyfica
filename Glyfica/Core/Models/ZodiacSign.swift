//
//  ZodiacSign.swift
//  Glyfica
//

import Foundation

enum ZodiacElement: String, Codable {
    case fire, earth, air, water

    var title: String {
        switch self {
        case .fire: return "Fire"
        case .earth: return "Earth"
        case .air: return "Air"
        case .water: return "Water"
        }
    }
}

enum ZodiacSign: String, Codable, CaseIterable, Identifiable {
    case aries, taurus, gemini, cancer, leo, virgo
    case libra, scorpio, sagittarius, capricorn, aquarius, pisces

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aries: return "Aries"
        case .taurus: return "Taurus"
        case .gemini: return "Gemini"
        case .cancer: return "Cancer"
        case .leo: return "Leo"
        case .virgo: return "Virgo"
        case .libra: return "Libra"
        case .scorpio: return "Scorpio"
        case .sagittarius: return "Sagittarius"
        case .capricorn: return "Capricorn"
        case .aquarius: return "Aquarius"
        case .pisces: return "Pisces"
        }
    }

    var symbol: String {
        switch self {
        case .aries: return "♈"
        case .taurus: return "♉"
        case .gemini: return "♊"
        case .cancer: return "♋"
        case .leo: return "♌"
        case .virgo: return "♍"
        case .libra: return "♎"
        case .scorpio: return "♏"
        case .sagittarius: return "♐"
        case .capricorn: return "♑"
        case .aquarius: return "♒"
        case .pisces: return "♓"
        }
    }

    var element: ZodiacElement {
        switch self {
        case .aries, .leo, .sagittarius: return .fire
        case .taurus, .virgo, .capricorn: return .earth
        case .gemini, .libra, .aquarius: return .air
        case .cancer, .scorpio, .pisces: return .water
        }
    }

    var personality: String {
        switch self {
        case .aries: return "You move first and sort the feeling out after. Momentum is your native language."
        case .taurus: return "You trust what you can keep. Comfort, loyalty, and a slow yes matter more than a fast one."
        case .gemini: return "You think by talking. Two ideas at once is not a distraction, it is how you find the real one."
        case .cancer: return "You remember the room, not just the facts. Care is how you make a place feel like yours."
        case .leo: return "You warm up when someone is actually watching. Pride, for you, is a form of generosity."
        case .virgo: return "You notice the loose thread. Fixing it is how you show love, even when you never say so."
        case .libra: return "You look for the fair version of the story. Harmony is not avoidance, it is a choice you keep making."
        case .scorpio: return "You do not do halfway. Trust is rare, and once it is given you expect the same depth back."
        case .sagittarius: return "You need a horizon. A plan that cannot change feels smaller than the life you want."
        case .capricorn: return "You build in quiet. Respect arrives late, and you would rather earn it than borrow it."
        case .aquarius: return "You stand a little outside the circle so you can see it. Distance is how you stay honest."
        case .pisces: return "You absorb the mood before the words. Imagination is not an escape, it is how you understand people."
        }
    }

    /// Tropical sun sign. The year boundary for Capricorn is handled in January and December.
    static func sunSign(for date: Date, calendar: Calendar = .current) -> ZodiacSign {
        let parts = calendar.dateComponents([.month, .day], from: date)
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        switch month {
        case 1: return day <= 19 ? .capricorn : .aquarius
        case 2: return day <= 18 ? .aquarius : .pisces
        case 3: return day <= 20 ? .pisces : .aries
        case 4: return day <= 19 ? .aries : .taurus
        case 5: return day <= 20 ? .taurus : .gemini
        case 6: return day <= 20 ? .gemini : .cancer
        case 7: return day <= 22 ? .cancer : .leo
        case 8: return day <= 22 ? .leo : .virgo
        case 9: return day <= 22 ? .virgo : .libra
        case 10: return day <= 22 ? .libra : .scorpio
        case 11: return day <= 21 ? .scorpio : .sagittarius
        default: return day <= 21 ? .sagittarius : .capricorn
        }
    }

    var sortIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}
