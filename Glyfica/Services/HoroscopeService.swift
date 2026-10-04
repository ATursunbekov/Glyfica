//
//  HoroscopeService.swift
//  Glyfica
//
//  Sun sign and life-path number are computed here. Full-section copy is
//  a local fallback when generateReading is unavailable.
//

import Foundation

enum HoroscopeService {
    static func reading(for profile: BirthProfile) -> HoroscopeReading {
        let sign = profile.sign
        let lifePath = lifePathNumber(from: profile.birthDate)
        return HoroscopeReading(
            profile: profile,
            sign: sign,
            lifePath: lifePath,
            lifePathText: lifePathCopy(lifePath)
        )
    }

    static func fullReading(for profile: BirthProfile) -> FullPersonalityReading {
        let sign = profile.sign
        let path = lifePathNumber(from: profile.birthDate)
        let focus = profile.concern?.title.lowercased() ?? "your next step"
        let relationship = profile.relationship?.title.lowercased() ?? "your relationships"

        return FullPersonalityReading(sections: [
            PersonalitySection(
                id: "core",
                title: "Core self",
                body: """
                As a \(sign.title), you move through the world with \(sign.element.title.lowercased()) instincts. People notice your presence before they can name it — not because you push, but because you hold a clear center.

                Your strength is consistency of character: once something matters, you do not treat it lightly. The shadow side is holding that same intensity too long, even when the room has already changed.

                You grow fastest when you let one soft contradiction exist next to your certainty — curiosity next to conviction.
                """
            ),
            PersonalitySection(
                id: "love",
                title: "Love & bonds",
                body: """
                In love, your current chapter reads as \(relationship). \(sign.title) bonds deepen when honesty arrives early, not after distance has already done the work.

                You give care through attention and loyalty more than through big speeches. What you need back is the same: someone who stays present when the mood shifts.

                The relationship improves when you name the need before it turns into withdrawal.
                """
            ),
            PersonalitySection(
                id: "work",
                title: "Work & decisions",
                body: """
                At work you prefer a clean line of responsibility. Vague plans drain you; a defined next move restores energy.

                Decisions get stuck when you wait for perfect certainty. \(sign.title) chooses better with a deadline and one trusted signal, not with endless options.

                Your edge is follow-through. Protect the hour where the important task happens before the noise of the day starts negotiating with you.
                """
            ),
            PersonalitySection(
                id: "path",
                title: "Life path",
                body: """
                \(lifePathCopy(path))

                With \(sign.title) as your sun sign, life path \(path) does not ask you to become someone else. It asks you to aim the temperament you already have — \(sign.element.title.lowercased()) nature — toward work and bonds that can actually hold it.
                """
            ),
            PersonalitySection(
                id: "now",
                title: "Right now",
                body: """
                1. Name the real priority around \(focus) in one sentence today.
                2. Make one smaller promise you can keep before evening.
                3. Leave space after conversations — your best read of people arrives a little late, and that is fine.
                """
            )
        ])
    }

    static func lifePathNumber(from date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        let digits = "\(year)\(month)\(day)".compactMap(\.wholeNumberValue)
        return reduce(digits.reduce(0, +))
    }

    private static func reduce(_ value: Int) -> Int {
        if value == 11 || value == 22 || value == 33 { return value }
        if value < 10 { return value }
        let next = String(value).compactMap(\.wholeNumberValue).reduce(0, +)
        return reduce(next)
    }

    private static func lifePathCopy(_ number: Int) -> String {
        switch number {
        case 1: return "Life path 1 starts things. You are steadier when the direction is yours."
        case 2: return "Life path 2 keeps the peace between people. You read a room before you enter it."
        case 3: return "Life path 3 needs expression. A day with no outlet starts to feel smaller."
        case 4: return "Life path 4 builds the frame. Reliability is the trait people count on."
        case 5: return "Life path 5 changes the plan. Freedom is not chaos for you, it is oxygen."
        case 6: return "Life path 6 takes care of the circle. Home and loyalty sit at the center."
        case 7: return "Life path 7 needs quiet to think. You trust what you have checked yourself."
        case 8: return "Life path 8 aims at results. Ambition works when it has a standard, not just a wish."
        case 9: return "Life path 9 looks past the personal. You feel responsible for the larger picture."
        case 11: return "Life path 11 is a master number. Intuition is loud, and so is the pressure to live up to it."
        case 22: return "Life path 22 is a master builder. Big plans only settle once they become something real."
        case 33: return "Life path 33 is a master teacher. You guide by how you treat people, not by a speech."
        default: return "Your life path number is a sketch of temperament, not a verdict."
        }
    }
}
