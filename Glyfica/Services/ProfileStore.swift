//
//  ProfileStore.swift
//  Glyfica
//
//  Birth profile. UserDefaults is the source for the UI; Firestore at
//  users/{uid} is the copy that survives a reinstall.
//

import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: BirthProfile?

    private let defaults: UserDefaults
    private let key = "glyfica.birthProfile"
    private var uid: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        profile = Self.load(from: defaults, key: key)
    }

    func save(_ profile: BirthProfile) {
        self.profile = profile
        persistLocally(profile)
        Task { await push(profile) }
    }

    func clear() {
        profile = nil
        defaults.removeObject(forKey: key)
    }

    func deleteRemote(uid: String) async {
        guard FirebaseService.isConfigured else { return }
        do {
            try await Firestore.firestore().collection("users").document(uid).delete()
        } catch {
            print("[Firestore] Profile delete failed: \(error.localizedDescription)")
        }
    }

    func attach(uid: String?) async {
        guard let uid, uid != self.uid else { return }
        self.uid = uid
        if let profile {
            await push(profile)
        } else if let remote = await fetchRemote(uid: uid) {
            profile = remote
            persistLocally(remote)
        }
    }

    private func persistLocally(_ profile: BirthProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: key)
        }
    }

    private func push(_ profile: BirthProfile) async {
        guard FirebaseService.isConfigured, let uid else { return }
        var data: [String: Any] = [
            "name": profile.name,
            "birthDate": Timestamp(date: profile.birthDate),
            "city": profile.city,
            "sunSign": profile.sign.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        data["birthTime"] = profile.birthTime.map { Timestamp(date: $0) } ?? NSNull()
        if let gender = profile.gender { data["gender"] = gender.rawValue }
        if let concern = profile.concern { data["concern"] = concern.rawValue }
        if let relationship = profile.relationship { data["relationship"] = relationship.rawValue }
        do {
            try await Firestore.firestore().collection("users").document(uid).setData(data, merge: true)
        } catch {
            print("[Firestore] Profile save failed: \(error.localizedDescription)")
        }
    }

    private func fetchRemote(uid: String) async -> BirthProfile? {
        guard FirebaseService.isConfigured else { return nil }
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
            guard let data = snapshot.data(),
                  let name = data["name"] as? String,
                  let birthDate = (data["birthDate"] as? Timestamp)?.dateValue()
            else { return nil }
            return BirthProfile(
                name: name,
                birthDate: birthDate,
                birthTime: (data["birthTime"] as? Timestamp)?.dateValue(),
                city: data["city"] as? String ?? "",
                gender: (data["gender"] as? String).flatMap(UserGender.init(rawValue:)),
                concern: (data["concern"] as? String).flatMap(LifeConcern.init(rawValue:)),
                relationship: (data["relationship"] as? String).flatMap(RelationshipStatus.init(rawValue:))
            )
        } catch {
            print("[Firestore] Profile load failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func load(from defaults: UserDefaults, key: String) -> BirthProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BirthProfile.self, from: data)
    }
}
