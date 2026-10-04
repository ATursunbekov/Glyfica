//
//  QuizAnswers.swift
//  Glyfica
//

import Foundation

enum UserGender: String, Codable, CaseIterable, Identifiable {
    case female
    case male
    case preferNotToSay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum LifeConcern: String, Codable, CaseIterable, Identifiable {
    case love
    case career
    case decision
    case selfDiscovery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .love: return "Love"
        case .career: return "Career"
        case .decision: return "A decision"
        case .selfDiscovery: return "Self-discovery"
        }
    }

    var subtitle: String {
        switch self {
        case .love: return "Relationships and connection"
        case .career: return "Work and direction"
        case .decision: return "Something you need to choose"
        case .selfDiscovery: return "Who you are becoming"
        }
    }
}

enum RelationshipStatus: String, Codable, CaseIterable, Identifiable {
    case single
    case talking
    case inRelationship
    case complicated
    case married

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: return "Single"
        case .talking: return "Talking to someone"
        case .inRelationship: return "In a relationship"
        case .complicated: return "It's complicated"
        case .married: return "Married"
        }
    }

    var asksForPartner: Bool {
        switch self {
        case .single: return false
        case .talking, .inRelationship, .complicated, .married: return true
        }
    }
}

enum BirthTimeOfDay: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    /// Rough clock time used until the user adds an exact birth time later.
    var approximateDateComponents: DateComponents {
        switch self {
        case .morning: return DateComponents(hour: 9, minute: 0)
        case .afternoon: return DateComponents(hour: 14, minute: 0)
        case .evening: return DateComponents(hour: 19, minute: 0)
        case .night: return DateComponents(hour: 0, minute: 0)
        }
    }
}

struct QuizAnswers: Codable, Equatable {
    var gender: UserGender?
    var concern: LifeConcern?
    var relationship: RelationshipStatus?

    var partnerName: String = ""
    var partnerBirthDate: Date?
    var partnerBirthTime: Date?
    var partnerBirthTimeOfDay: BirthTimeOfDay?
    var partnerCity: String = ""
    var skippedPartner = false

    var birthDate: Date?
    var birthTime: Date?
    var birthTimeOfDay: BirthTimeOfDay?
    var knowsBirthTime = true
    var city: String = ""

    var name: String = ""
    var wantsNotifications: Bool?

    var isComplete: Bool {
        gender != nil
            && concern != nil
            && relationship != nil
            && birthDate != nil
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && wantsNotifications != nil
    }

    var resolvedBirthTime: Date? {
        if knowsBirthTime { return birthTime }
        guard let birthDate, let birthTimeOfDay else { return nil }
        return Calendar.current.date(
            bySettingHour: birthTimeOfDay.approximateDateComponents.hour ?? 12,
            minute: birthTimeOfDay.approximateDateComponents.minute ?? 0,
            second: 0,
            of: birthDate
        )
    }

    var partnerSign: ZodiacSign? {
        partnerBirthDate.map { ZodiacSign.sunSign(for: $0) }
    }

    func makeBirthProfile() -> BirthProfile? {
        guard let birthDate else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return BirthProfile(
            name: trimmed,
            birthDate: birthDate,
            birthTime: resolvedBirthTime,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: gender,
            concern: concern,
            relationship: relationship
        )
    }

    func makePartnerProfile() -> PartnerProfile? {
        guard relationship?.asksForPartner == true,
              !skippedPartner,
              let partnerBirthDate
        else { return nil }
        let trimmed = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return PartnerProfile(
            name: trimmed.isEmpty ? "Them" : trimmed,
            birthDate: partnerBirthDate,
            birthTime: resolvedPartnerBirthTime,
            city: partnerCity.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var resolvedPartnerBirthTime: Date? {
        if let partnerBirthTime { return partnerBirthTime }
        guard let partnerBirthDate, let partnerBirthTimeOfDay else { return nil }
        return Calendar.current.date(
            bySettingHour: partnerBirthTimeOfDay.approximateDateComponents.hour ?? 12,
            minute: partnerBirthTimeOfDay.approximateDateComponents.minute ?? 0,
            second: 0,
            of: partnerBirthDate
        )
    }
}
