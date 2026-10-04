//
//  BirthProfile.swift
//  Glyfica
//

import Foundation

struct BirthProfile: Codable, Equatable {
    var name: String
    var birthDate: Date
    var birthTime: Date?
    var city: String
    var gender: UserGender?
    var concern: LifeConcern?
    var relationship: RelationshipStatus?

    var sign: ZodiacSign {
        ZodiacSign.sunSign(for: birthDate)
    }
}

struct PartnerProfile: Codable, Equatable {
    var name: String
    var birthDate: Date
    var birthTime: Date?
    var city: String

    var sign: ZodiacSign {
        ZodiacSign.sunSign(for: birthDate)
    }
}

struct HoroscopeReading: Equatable {
    let profile: BirthProfile
    let sign: ZodiacSign
    let lifePath: Int
    let lifePathText: String
}

struct DailyForecast: Equatable {
    let date: Date
    let dateKey: String
    let sign: ZodiacSign
    let headline: String
    let focus: String
    let summary: String
    let loveTip: String
    let workTip: String
    let doToday: String
    let avoidToday: String
    let love: Int
    let energy: Int
    let mood: Int
    let luck: Int
}

struct CompatibilityArea: Equatable, Identifiable {
    let title: String
    let score: Int
    var id: String { title }
}

struct CompatibilityReading: Equatable {
    let userSign: ZodiacSign
    let partnerName: String
    let partnerSign: ZodiacSign
    let overall: Int
    let headline: String
    let summary: String
    let tip: String
    let areas: [CompatibilityArea]
}

struct PalmScore: Equatable, Identifiable {
    let id: String
    let title: String
    let value: Int
}

struct PalmReading: Equatable, Identifiable {
    let id: String
    let headline: String
    let overview: String
    let lifeLine: String
    let heartLine: String
    let headLine: String
    let fateLine: String
    let nearFuture: String
    let advice: String
    let vitality: Int
    let emotion: Int
    let mind: Int
    let destiny: Int
    let outlook: Int

    var scores: [PalmScore] {
        [
            PalmScore(id: "vitality", title: "Vitality", value: vitality),
            PalmScore(id: "emotion", title: "Emotion", value: emotion),
            PalmScore(id: "mind", title: "Mind", value: mind),
            PalmScore(id: "destiny", title: "Destiny", value: destiny),
            PalmScore(id: "outlook", title: "Outlook", value: outlook)
        ]
    }

    var overall: Int {
        let values = [vitality, emotion, mind, destiny, outlook]
        return values.reduce(0, +) / max(values.count, 1)
    }

    var sections: [(title: String, body: String)] {
        [
            ("Life line", lifeLine),
            ("Heart line", heartLine),
            ("Head line", headLine),
            ("Fate line", fateLine),
            ("Near future", nearFuture),
            ("Advice", advice)
        ]
    }
}
