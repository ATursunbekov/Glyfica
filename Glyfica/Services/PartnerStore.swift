//
//  PartnerStore.swift
//  Glyfica
//

import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class PartnerStore: ObservableObject {
    @Published private(set) var partner: PartnerProfile?

    private let defaults: UserDefaults
    private let key = "glyfica.partnerProfile"
    private var uid: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        partner = Self.load(from: defaults, key: key)
    }

    var name: String { partner?.name ?? "" }
    var sign: ZodiacSign { partner?.sign ?? .libra }

    func attach(uid: String?) async {
        guard let uid, uid != self.uid else { return }
        self.uid = uid
        if let partner {
            await push(partner)
        } else if let remote = await fetchRemote(uid: uid) {
            partner = remote
            persistLocally(remote)
        }
    }

    func save(_ partner: PartnerProfile) {
        self.partner = partner
        persistLocally(partner)
        Task { await push(partner) }
    }

    func clear() {
        partner = nil
        defaults.removeObject(forKey: key)
        Task { await pushCleared() }
    }

    private func persistLocally(_ partner: PartnerProfile) {
        if let data = try? JSONEncoder().encode(partner) {
            defaults.set(data, forKey: key)
        }
    }

    private func push(_ partner: PartnerProfile) async {
        guard FirebaseService.isConfigured, let uid else { return }
        let data: [String: Any] = [
            "partner": [
                "name": partner.name,
                "birthDate": Timestamp(date: partner.birthDate),
                "birthTime": partner.birthTime.map { Timestamp(date: $0) } ?? NSNull(),
                "city": partner.city,
                "sunSign": partner.sign.rawValue
            ],
            "updatedAt": FieldValue.serverTimestamp()
        ]
        do {
            try await Firestore.firestore().collection("users").document(uid).setData(data, merge: true)
        } catch {
            print("[Firestore] Partner save failed: \(error.localizedDescription)")
        }
    }

    private func pushCleared() async {
        guard FirebaseService.isConfigured, let uid else { return }
        do {
            try await Firestore.firestore().collection("users").document(uid).setData([
                "partner": NSNull(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("[Firestore] Partner clear failed: \(error.localizedDescription)")
        }
    }

    private func fetchRemote(uid: String) async -> PartnerProfile? {
        guard FirebaseService.isConfigured else { return nil }
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
            guard let data = snapshot.data(),
                  let partner = data["partner"] as? [String: Any],
                  let name = partner["name"] as? String,
                  let birthDate = (partner["birthDate"] as? Timestamp)?.dateValue()
            else { return nil }
            return PartnerProfile(
                name: name,
                birthDate: birthDate,
                birthTime: (partner["birthTime"] as? Timestamp)?.dateValue(),
                city: partner["city"] as? String ?? ""
            )
        } catch {
            print("[Firestore] Partner load failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func load(from defaults: UserDefaults, key: String) -> PartnerProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PartnerProfile.self, from: data)
    }
}
