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
