//
//  Subscription.swift
//  Glyfica
//

import Foundation

enum SubscriptionPlan: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    var priceLabel: String {
        switch self {
        case .weekly: return "$4.99 / week"
        case .monthly: return "$9.99 / month"
        case .yearly: return "$39.99 / year"
        }
    }

    var detail: String {
        switch self {
        case .weekly: return "Flexible. Cancel anytime."
        case .monthly: return "Best for trying the full chart."
        case .yearly: return "Best value. 3 months free."
        }
    }

    var durationDays: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        case .yearly: return 365
        }
    }
}

struct SubscriptionState: Codable, Equatable {
    var plan: SubscriptionPlan?
    var isActive: Bool
    var source: String
    var activatedAt: Date?
    var expiresAt: Date?

    static let inactive = SubscriptionState(
        plan: nil,
        isActive: false,
        source: "none",
        activatedAt: nil,
        expiresAt: nil
    )
}

struct PersonalitySection: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
}

struct FullPersonalityReading: Equatable {
    let sections: [PersonalitySection]
}
