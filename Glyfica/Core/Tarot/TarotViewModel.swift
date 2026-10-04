//
//  TarotViewModel.swift
//  Glyfica
//

import Combine
import Foundation

@MainActor
final class TarotViewModel: ObservableObject {
    @Published var topic: TarotTopic = .general
    @Published var customQuestion: String = ""
    @Published var spread: TarotSpread = .threeCard
    @Published private(set) var drawnCards: [DrawnTarotCard] = []
    @Published private(set) var reading: TarotReading?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    var resolvedQuestion: String {
        if topic == .custom {
            return customQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return topic.prompt
    }

    var hasQuestion: Bool {
        !resolvedQuestion.isEmpty
    }

    var hasDraw: Bool { !drawnCards.isEmpty }

    var canDraw: Bool {
        hasQuestion && !isLoading
    }

    var canRead: Bool {
        hasQuestion && hasDraw && !isLoading
    }

    func selectTopic(_ next: TarotTopic) {
        topic = next
        clearDraw()
    }

    func questionEdited() {
        clearDraw()
    }

    private func clearDraw() {
        drawnCards = []
        reading = nil
        errorMessage = nil
    }

    func drawCards() {
        guard canDraw else {
            errorMessage = "Ask a question first."
            return
        }
        var rng = SystemRandomNumberGenerator()
        drawnCards = TarotDeck.draw(spread: spread, rng: &rng)
        reading = nil
        errorMessage = nil
    }

    func changeSpread(_ next: TarotSpread) {
        spread = next
        drawnCards = []
        reading = nil
        errorMessage = nil
    }

    func reset() {
        drawnCards = []
        reading = nil
        errorMessage = nil
        // Keep topic/question so they can draw again on the same theme.
    }

    func readCards(profile: BirthProfile?) async {
        guard canRead else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            reading = try await ReadingService.fetchTarotReading(
                spread: spread,
                question: resolvedQuestion,
                cards: drawnCards,
                profile: profile
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
