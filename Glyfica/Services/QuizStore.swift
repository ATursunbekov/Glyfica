//
//  QuizStore.swift
//  Glyfica
//
//  Owns quiz completion and draft answers. Local first; Firestore gets the
//  finished payload when the quiz completes.
//

import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class QuizStore: ObservableObject {
    @Published private(set) var answers: QuizAnswers
    @Published private(set) var isCompleted: Bool

    private let defaults: UserDefaults
    private let answersKey = "glyfica.quizAnswers"
    private let completedKey = "glyfica.quizCompleted"
    private var uid: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        answers = Self.loadAnswers(from: defaults, key: answersKey) ?? QuizAnswers()
        isCompleted = defaults.bool(forKey: completedKey)
    }

    func attach(uid: String?) {
        self.uid = uid
    }

    func reset() {
        answers = QuizAnswers()
        isCompleted = false
        defaults.removeObject(forKey: answersKey)
        defaults.set(false, forKey: completedKey)
    }

    func update(_ transform: (inout QuizAnswers) -> Void) {
        transform(&answers)
        persistDraft()
    }

    func complete(
        profileStore: ProfileStore,
        partnerStore: PartnerStore
    ) async {
        guard let profile = answers.makeBirthProfile() else { return }
        profileStore.save(profile)

        if let partner = answers.makePartnerProfile() {
            partnerStore.save(partner)
        } else {
            partnerStore.clear()
        }

        isCompleted = true
        defaults.set(true, forKey: completedKey)
        persistDraft()
        await pushRemote()
    }

    private func persistDraft() {
        if let data = try? JSONEncoder().encode(answers) {
            defaults.set(data, forKey: answersKey)
        }
    }

    private func pushRemote() async {
        guard FirebaseService.isConfigured, let uid else { return }
        var data: [String: Any] = [
            "quizCompleted": true,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let gender = answers.gender { data["gender"] = gender.rawValue }
        if let concern = answers.concern { data["concern"] = concern.rawValue }
        if let relationship = answers.relationship { data["relationship"] = relationship.rawValue }
        if let wants = answers.wantsNotifications { data["wantsNotifications"] = wants }
        if let birthDate = answers.birthDate {
            data["birthDate"] = Timestamp(date: birthDate)
            data["sunSign"] = ZodiacSign.sunSign(for: birthDate).rawValue
        }
        data["name"] = answers.name.trimmingCharacters(in: .whitespacesAndNewlines)
        data["city"] = answers.city.trimmingCharacters(in: .whitespacesAndNewlines)
        data["birthTime"] = answers.resolvedBirthTime.map { Timestamp(date: $0) } ?? NSNull()

        if let partner = answers.makePartnerProfile() {
            data["partner"] = [
                "name": partner.name,
                "birthDate": Timestamp(date: partner.birthDate),
                "birthTime": partner.birthTime.map { Timestamp(date: $0) } ?? NSNull(),
                "city": partner.city,
                "sunSign": partner.sign.rawValue
            ]
        } else {
            data["partner"] = NSNull()
        }

        do {
            try await Firestore.firestore().collection("users").document(uid).setData(data, merge: true)
        } catch {
            print("[Firestore] Quiz save failed: \(error.localizedDescription)")
        }
    }

    private static func loadAnswers(from defaults: UserDefaults, key: String) -> QuizAnswers? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(QuizAnswers.self, from: data)
    }
}
