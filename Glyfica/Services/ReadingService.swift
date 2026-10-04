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
