//
//  ReadingService.swift
//  Glyfica
//
//  Loads GPT readings: Firestore cache first, then generateReading callable.
//  Falls back to local copy if the function is down.
//

import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation

enum ReadingServiceError: LocalizedError {
    case notSignedIn
    case invalidResponse
    case remote(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in is required for a palm reading."
        case .invalidResponse:
            return "Couldn’t read that palm. Try a clearer photo."
        case .remote(let message):
            return message
        }
    }
}

enum ReadingService {
    private static var functions: Functions {
        Functions.functions(region: "us-central1")
    }

    static func fetchPersonalityReading(
        for profile: BirthProfile,
        force: Bool = false
    ) async -> FullPersonalityReading {
        if !force, let cached = await loadCachedPersonality() {
            return cached
        }

        if let remote = await generatePersonality(force: force) {
            return remote
        }

        if let cached = await loadCachedPersonality() {
            return cached
        }

        return HoroscopeService.fullReading(for: profile)
    }

    static func fetchDailyForecast(
        for profile: BirthProfile,
        on date: Date = .now,
        force: Bool = false
    ) async -> DailyForecast {
        let key = DailyForecastService.dateKey(for: date)

        if !force, let cached = await loadCachedDaily(dateKey: key, profile: profile, date: date) {
            return cached
        }

        if let remote = await generateDaily(dateKey: key, profile: profile, date: date, force: force) {
            return remote
        }

        if let cached = await loadCachedDaily(dateKey: key, profile: profile, date: date) {
            return cached
        }

        return DailyForecastService.forecast(for: profile, on: date)
    }

    static func fetchCompatibilityReading(
        user: BirthProfile,
        partner: PartnerProfile,
        force: Bool = false
    ) async -> CompatibilityReading {
        let cacheId = compatibilityDocId(for: partner)

        if !force, let cached = await loadCachedCompatibility(docId: cacheId, user: user, partner: partner) {
            return cached
        }

        if let remote = await generateCompatibility(user: user, partner: partner, force: force) {
            return remote
        }

        if let cached = await loadCachedCompatibility(docId: cacheId, user: user, partner: partner) {
            return cached
        }

        return CompatibilityService.reading(
            user: user.sign,
            partnerName: partner.name,
            partner: partner.sign
        )
    }

    static func fetchTarotReading(
        spread: TarotSpread,
        question: String,
        cards: [DrawnTarotCard],
        profile: BirthProfile?
    ) async throws -> TarotReading {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            throw ReadingServiceError.remote("Ask a question before reading the cards.")
        }

        guard FirebaseService.isConfigured,
              Auth.auth().currentUser != nil
        else {
            if profile != nil {
                return localTarotFallback(spread: spread, question: trimmedQuestion, cards: cards)
            }
            throw ReadingServiceError.notSignedIn
        }

        let payloadCards: [[String: Any]] = cards.map { drawn in
            [
                "id": drawn.card.id,
                "name": drawn.card.name,
                "position": drawn.position,
                "isReversed": drawn.isReversed,
                "suit": drawn.card.suit.rawValue
            ]
        }

        do {
            let result = try await functions
                .httpsCallable("generateReading")
                .call([
                    "type": "tarot",
                    "spread": spread.rawValue,
                    "question": trimmedQuestion,
                    "cards": payloadCards
                ])

            guard let data = result.data as? [String: Any],
                  let reading = parseTarot(
                    data,
                    spread: spread,
                    question: trimmedQuestion,
                    drawn: cards
                  )
            else { throw ReadingServiceError.invalidResponse }

            return reading
        } catch let error as ReadingServiceError {
            throw error
        } catch {
            throw ReadingServiceError.remote(error.localizedDescription)
        }
    }

    static func fetchPalmReading(
        imageBase64: String,
        mimeType: String,
        profile: BirthProfile?
    ) async throws -> PalmReading {
        guard FirebaseService.isConfigured,
              Auth.auth().currentUser != nil
        else {
            if let profile { return localPalmFallback(for: profile) }
            throw ReadingServiceError.notSignedIn
        }

        do {
            let result = try await functions
                .httpsCallable("generateReading")
                .call([
                    "type": "palm",
                    "imageBase64": imageBase64,
                    "mimeType": mimeType
                ])

            guard let data = result.data as? [String: Any],
                  let reading = parsePalm(data)
            else { throw ReadingServiceError.invalidResponse }

            return reading
        } catch let error as ReadingServiceError {
            throw error
        } catch {
            throw ReadingServiceError.remote(error.localizedDescription)
        }
    }

    // MARK: - Personality

    private static func loadCachedPersonality() async -> FullPersonalityReading? {
        guard FirebaseService.isConfigured,
              let uid = Auth.auth().currentUser?.uid
        else { return nil }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("readings")
                .document("personality")
                .getDocument()

            guard let data = snapshot.data(),
                  let sectionsData = data["sections"] as? [[String: Any]]
            else { return nil }

            let sections = sectionsData.compactMap(parseSection)
            guard sections.count == 5 else { return nil }
            return FullPersonalityReading(sections: sections)
        } catch {
            print("[Reading] Personality cache load failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func generatePersonality(force: Bool) async -> FullPersonalityReading? {
        guard FirebaseService.isConfigured,
              Auth.auth().currentUser != nil
        else { return nil }

        do {
            let result = try await functions
                .httpsCallable("generateReading")
                .call([
                    "type": "personality",
                    "force": force,
                ])

            guard let data = result.data as? [String: Any],
                  let sectionsData = data["sections"] as? [[String: Any]]
            else { return nil }

            let sections = sectionsData.compactMap { dict -> PersonalitySection? in
                guard let id = dict["id"] as? String,
                      let body = dict["body"] as? String,
                      !body.isEmpty
                else { return nil }
                let title = (dict["title"] as? String) ?? defaultTitle(for: id)
                return PersonalitySection(id: id, title: title, body: body)
            }

            guard sections.count == 5 else { return nil }
            return FullPersonalityReading(sections: sections)
        } catch {
            print("[Reading] generateReading personality failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Daily

    private static func loadCachedDaily(
        dateKey: String,
        profile: BirthProfile,
        date: Date
    ) async -> DailyForecast? {
        guard FirebaseService.isConfigured,
              let uid = Auth.auth().currentUser?.uid
        else { return nil }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("readings")
                .document("daily_\(dateKey)")
                .getDocument()

            guard let data = snapshot.data() else { return nil }
            return parseDaily(data, profile: profile, date: date, dateKey: dateKey)
        } catch {
            print("[Reading] Daily cache load failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func generateDaily(
        dateKey: String,
        profile: BirthProfile,
        date: Date,
        force: Bool
    ) async -> DailyForecast? {
        guard FirebaseService.isConfigured,
              Auth.auth().currentUser != nil
        else { return nil }

        do {
            let result = try await functions
                .httpsCallable("generateReading")
                .call([
                    "type": "daily",
                    "dateKey": dateKey,
                    "force": force,
                ])

            guard let data = result.data as? [String: Any] else { return nil }
            return parseDaily(data, profile: profile, date: date, dateKey: dateKey)
        } catch {
            print("[Reading] generateReading daily failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Compatibility

    private static func compatibilityDocId(for partner: PartnerProfile) -> String {
        let key = DailyForecastService.dateKey(for: partner.birthDate)
        let raw = "\(partner.name.lowercased())_\(key)_\(partner.sign.rawValue)"
        let safe = raw
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        return "compatibility_\(safe)"
    }

    private static func loadCachedCompatibility(
        docId: String,
        user: BirthProfile,
        partner: PartnerProfile
    ) async -> CompatibilityReading? {
        guard FirebaseService.isConfigured,
              let uid = Auth.auth().currentUser?.uid
        else { return nil }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("readings")
                .document(docId)
                .getDocument()
            guard let data = snapshot.data() else { return nil }
            return parseCompatibility(data, user: user, partner: partner)
        } catch {
            print("[Reading] Compatibility cache load failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func generateCompatibility(
        user: BirthProfile,
        partner: PartnerProfile,
        force: Bool
    ) async -> CompatibilityReading? {
        guard FirebaseService.isConfigured,
              Auth.auth().currentUser != nil
        else { return nil }

        do {
            var partnerPayload: [String: Any] = [
                "name": partner.name,
                "birthDate": DailyForecastService.dateKey(for: partner.birthDate),
                "city": partner.city,
                "sunSign": partner.sign.rawValue
            ]
            if let birthTime = partner.birthTime {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "HH:mm"
                partnerPayload["birthTime"] = formatter.string(from: birthTime)
            }

            let result = try await functions
                .httpsCallable("generateReading")
                .call([
                    "type": "compatibility",
                    "force": force,
                    "partner": partnerPayload
                ])

            guard let data = result.data as? [String: Any] else { return nil }
            return parseCompatibility(data, user: user, partner: partner)
        } catch {
            print("[Reading] generateReading compatibility failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func parseCompatibility(
        _ data: [String: Any],
        user: BirthProfile,
        partner: PartnerProfile
    ) -> CompatibilityReading? {
        guard let summary = data["summary"] as? String, !summary.isEmpty else { return nil }

        let areasData = data["areas"] as? [[String: Any]] ?? []
        let areas = areasData.compactMap { row -> CompatibilityArea? in
            guard let title = row["title"] as? String else { return nil }
            return CompatibilityArea(title: title, score: intScore(row["score"]))
        }

        let fallback = CompatibilityService.reading(
            user: user.sign,
            partnerName: partner.name,
            partner: partner.sign
        )

        return CompatibilityReading(
            userSign: user.sign,
            partnerName: (data["partnerName"] as? String) ?? partner.name,
            partnerSign: partner.sign,
            overall: intScore(data["overall"]),
            headline: (data["headline"] as? String) ?? fallback.headline,
            summary: summary,
            tip: (data["tip"] as? String) ?? fallback.tip,
            areas: areas.count == 6 ? areas : fallback.areas
        )
    }

    private static func parseDaily(
        _ data: [String: Any],
        profile: BirthProfile,
        date: Date,
        dateKey: String
    ) -> DailyForecast? {
        guard let focus = data["focus"] as? String, !focus.isEmpty,
              let summary = data["summary"] as? String, !summary.isEmpty
        else { return nil }

        let headline = (data["headline"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return DailyForecast(
            date: date,
            dateKey: (data["dateKey"] as? String) ?? dateKey,
            sign: profile.sign,
            headline: (headline?.isEmpty == false ? headline! : "Your day, in focus"),
            focus: focus,
            summary: summary,
            loveTip: (data["loveTip"] as? String) ?? "",
            workTip: (data["workTip"] as? String) ?? "",
            doToday: (data["doToday"] as? String) ?? "",
            avoidToday: (data["avoidToday"] as? String) ?? "",
            love: intScore(data["love"]),
            energy: intScore(data["energy"]),
            mood: intScore(data["mood"]),
            luck: intScore(data["luck"])
        )
    }

    private static func parseTarot(
        _ data: [String: Any],
        spread: TarotSpread,
        question: String,
        drawn: [DrawnTarotCard]
    ) -> TarotReading? {
        guard let overview = data["overview"] as? String, !overview.isEmpty else { return nil }

        let cardsData = data["cards"] as? [[String: Any]] ?? []
        var meanings: [TarotCardMeaning] = cardsData.compactMap { row in
            guard let name = row["name"] as? String,
                  let position = row["position"] as? String,
                  let meaning = row["meaning"] as? String,
                  !meaning.isEmpty
            else { return nil }
            return TarotCardMeaning(
                id: (row["id"] as? String) ?? "\(position)-\(name)",
                name: name,
                position: position,
                isReversed: row["isReversed"] as? Bool ?? false,
                meaning: meaning
            )
        }

        if meanings.count != drawn.count {
            meanings = drawn.map { card in
                TarotCardMeaning(
                    id: card.id,
                    name: card.card.name,
                    position: card.position,
                    isReversed: card.isReversed,
                    meaning: "This card asks you to notice what feels unfinished and name the next honest step."
                )
            }
        }

        return TarotReading(
            id: (data["id"] as? String) ?? UUID().uuidString,
            spread: spread,
            question: (data["question"] as? String) ?? question,
            headline: (data["headline"] as? String) ?? "Your cards have a message",
            overview: overview,
            advice: (data["advice"] as? String) ?? "",
            cards: meanings
        )
    }

    private static func localTarotFallback(
        spread: TarotSpread,
        question: String,
        cards: [DrawnTarotCard]
    ) -> TarotReading {
        TarotReading(
            id: UUID().uuidString,
            spread: spread,
            question: question,
            headline: "A quiet pull from the deck",
            overview: "The cards answer your question through timing and honesty. Something already forming wants a clearer yes or a cleaner no.",
            advice: "Take one grounded action today that matches the card in the Present or Now position.",
            cards: cards.map { card in
                TarotCardMeaning(
                    id: card.id,
                    name: card.card.name,
                    position: card.position,
                    isReversed: card.isReversed,
                    meaning: card.isReversed
                        ? "Reversed, \(card.card.name) asks you to pause a habit that has been draining the moment around your question."
                        : "\(card.card.name) highlights a theme of clarity and follow-through in the \(card.position.lowercased()) for this question."
                )
            }
        )
    }

    private static func parsePalm(_ data: [String: Any]) -> PalmReading? {
        guard let overview = data["overview"] as? String, !overview.isEmpty else { return nil }
        return PalmReading(
            id: (data["id"] as? String) ?? UUID().uuidString,
            headline: (data["headline"] as? String) ?? "Your palm story",
            overview: overview,
            lifeLine: (data["lifeLine"] as? String) ?? "",
            heartLine: (data["heartLine"] as? String) ?? "",
            headLine: (data["headLine"] as? String) ?? "",
            fateLine: (data["fateLine"] as? String) ?? "",
            nearFuture: (data["nearFuture"] as? String) ?? "",
            advice: (data["advice"] as? String) ?? "",
            vitality: intScore(data["vitality"]),
            emotion: intScore(data["emotion"]),
            mind: intScore(data["mind"]),
            destiny: intScore(data["destiny"]),
            outlook: intScore(data["outlook"])
        )
    }

    private static func localPalmFallback(for profile: BirthProfile) -> PalmReading {
        PalmReading(
            id: UUID().uuidString,
            headline: "A quiet map in your hand",
            overview: "Even without a live reading, \(profile.sign.title) palms often point to steady instinct and a need for honest timing. Use this as a soft sketch until the full analysis comes back.",
            lifeLine: "Your life line suggests recovery through rhythm — rest counts as part of momentum.",
            heartLine: "The heart line leans toward loyalty. You feel safest when affection is named plainly.",
            headLine: "The head line favors clear plans over endless options. One decision at a time keeps you sharp.",
            fateLine: "Fate shows up as chosen work, not coincidence. Direction improves when you protect one priority.",
            nearFuture: "The next stretch favors a small promise kept over a big speech delayed.",
            advice: "Photograph your palm again in soft light when you want a fuller reading.",
            vitality: 68,
            emotion: 72,
            mind: 70,
            destiny: 64,
            outlook: 66
        )
    }

    private static func parseSection(_ dict: [String: Any]) -> PersonalitySection? {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let body = dict["body"] as? String,
              !body.isEmpty
        else { return nil }
        return PersonalitySection(id: id, title: title, body: body)
    }

    private static func intScore(_ value: Any?) -> Int {
        if let n = value as? Int { return min(99, max(1, n)) }
        if let n = value as? NSNumber { return min(99, max(1, n.intValue)) }
        return 50
    }

    private static func defaultTitle(for id: String) -> String {
        switch id {
        case "core": return "Core self"
        case "love": return "Love & bonds"
        case "work": return "Work & decisions"
        case "path": return "Life path"
        case "now": return "Right now"
        default: return id.capitalized
        }
    }
}
