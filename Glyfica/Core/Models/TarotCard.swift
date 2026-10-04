//
//  TarotCard.swift
//  Glyfica
//
//  Rider–Waite style deck names. Image assets can later match `assetName`.
//

import Foundation

enum TarotSuit: String, Codable, CaseIterable {
    case major
    case wands
    case cups
    case swords
    case pentacles

    var title: String {
        switch self {
        case .major: return "Major Arcana"
        case .wands: return "Wands"
        case .cups: return "Cups"
        case .swords: return "Swords"
        case .pentacles: return "Pentacles"
        }
    }
}

struct TarotCard: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let name: String
    let suit: TarotSuit
    let number: Int

    /// Asset catalog name, e.g. `tarot_major_00`.
    var assetName: String { "tarot_\(id)" }
}

enum TarotSpread: String, CaseIterable, Identifiable {
    case single
    case threeCard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: return "One card"
        case .threeCard: return "Past · Present · Future"
        }
    }

    var subtitle: String {
        switch self {
        case .single: return "A clear message for right now"
        case .threeCard: return "Where you’ve been, where you are, what’s next"
        }
    }

    var cardCount: Int {
        switch self {
        case .single: return 1
        case .threeCard: return 3
        }
    }

    var positions: [String] {
        switch self {
        case .single: return ["Now"]
        case .threeCard: return ["Past", "Present", "Future"]
        }
    }
}

struct DrawnTarotCard: Equatable, Identifiable {
    let id: String
    let card: TarotCard
    let position: String
    let isReversed: Bool

    var displayName: String {
        isReversed ? "\(card.name) (Reversed)" : card.name
    }
}

struct TarotCardMeaning: Equatable, Identifiable {
    let id: String
    let name: String
    let position: String
    let isReversed: Bool
    let meaning: String
    let assetName: String

    var displayName: String {
        isReversed ? "\(name) (Reversed)" : name
    }
}

enum TarotTopic: String, CaseIterable, Identifiable {
    case love
    case career
    case decision
    case selfGrowth
    case general
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .love: return "Love"
        case .career: return "Career"
        case .decision: return "A decision"
        case .selfGrowth: return "Self-growth"
        case .general: return "General guidance"
        case .custom: return "My own question"
        }
    }

    var prompt: String {
        switch self {
        case .love: return "What do I need to understand about love and connection right now?"
        case .career: return "What should I know about my work and direction right now?"
        case .decision: return "What should I consider before making this decision?"
        case .selfGrowth: return "What am I being asked to grow into right now?"
        case .general: return "What do I most need to hear right now?"
        case .custom: return ""
        }
    }
}

struct TarotReading: Equatable, Identifiable {
    let id: String
    let spread: TarotSpread
    let question: String
    let headline: String
    let overview: String
    let advice: String
    let cards: [TarotCardMeaning]
}

enum TarotDeck {
    static let all: [TarotCard] = major + wands + cups + swords + pentacles

    static func card(id: String) -> TarotCard? {
        all.first { $0.id == id }
    }

    static func draw(spread: TarotSpread, rng: inout some RandomNumberGenerator) -> [DrawnTarotCard] {
        let picked = Array(all.shuffled(using: &rng).prefix(spread.cardCount))
        return zip(picked, spread.positions).map { card, position in
            DrawnTarotCard(
                id: "\(card.id)-\(position)",
                card: card,
                position: position,
                isReversed: Bool.random(using: &rng)
            )
        }
    }

    private static let majorNames = [
        "The Fool", "The Magician", "The High Priestess", "The Empress", "The Emperor",
        "The Hierophant", "The Lovers", "The Chariot", "Strength", "The Hermit",
        "Wheel of Fortune", "Justice", "The Hanged Man", "Death", "Temperance",
        "The Devil", "The Tower", "The Star", "The Moon", "The Sun",
        "Judgement", "The World"
    ]

    private static let minorRanks = [
        "Ace", "Two", "Three", "Four", "Five", "Six", "Seven",
        "Eight", "Nine", "Ten", "Page", "Knight", "Queen", "King"
    ]

    private static var major: [TarotCard] {
        majorNames.enumerated().map { index, name in
            TarotCard(
                id: String(format: "major_%02d", index),
                name: name,
                suit: .major,
                number: index
            )
        }
    }

    private static func minor(suit: TarotSuit, label: String) -> [TarotCard] {
        minorRanks.enumerated().map { index, rank in
            TarotCard(
                id: String(format: "%@_%02d", suit.rawValue, index + 1),
                name: "\(rank) of \(label)",
                suit: suit,
                number: index + 1
            )
        }
    }

    private static var wands: [TarotCard] { minor(suit: .wands, label: "Wands") }
    private static var cups: [TarotCard] { minor(suit: .cups, label: "Cups") }
    private static var swords: [TarotCard] { minor(suit: .swords, label: "Swords") }
    private static var pentacles: [TarotCard] { minor(suit: .pentacles, label: "Pentacles") }
}
