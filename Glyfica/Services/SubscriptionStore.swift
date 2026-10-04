//
//  SubscriptionStore.swift
//  Glyfica
//
//  Simulated subscriptions for now. Writes plan + expiry to Firestore so
//  the rest of the app can gate premium content. Replace simulatePurchase
//  with StoreKit 2 later without changing the read path.
//

import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var state: SubscriptionState = .inactive
    @Published private(set) var isLoading = false

    private let defaults: UserDefaults
    private let key = "glyfica.subscription"
    private var uid: String?

    var isPremium: Bool {
        guard state.isActive else { return false }
        if let expiresAt = state.expiresAt, expiresAt < Date() { return false }
        return true
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let stored = try? JSONDecoder().decode(SubscriptionState.self, from: data) {
            state = stored
        }
    }

    func attach(uid: String?) async {
        self.uid = uid
        guard let uid, FirebaseService.isConfigured else { return }
        await refreshFromRemote(uid: uid)
    }

    func simulatePurchase(_ plan: SubscriptionPlan) async {
        isLoading = true
        let now = Date()
        let expires = Calendar.current.date(byAdding: .day, value: plan.durationDays, to: now)
        let next = SubscriptionState(
            plan: plan,
            isActive: true,
            source: "simulated",
            activatedAt: now,
            expiresAt: expires
        )
        state = next
        persistLocally(next)
        await pushRemote(next)
        isLoading = false
    }

    func clearSubscription() async {
        isLoading = true
        state = .inactive
        persistLocally(.inactive)
        await pushRemote(.inactive)
        isLoading = false
    }

    private func persistLocally(_ state: SubscriptionState) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key)
        }
    }

    private func pushRemote(_ state: SubscriptionState) async {
        guard FirebaseService.isConfigured, let uid else { return }
        var data: [String: Any] = [
            "subscriptionActive": state.isActive,
            "subscriptionSource": state.source,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        data["subscriptionPlan"] = state.plan?.rawValue ?? NSNull()
        data["subscriptionActivatedAt"] = state.activatedAt.map { Timestamp(date: $0) } ?? NSNull()
        data["subscriptionExpiresAt"] = state.expiresAt.map { Timestamp(date: $0) } ?? NSNull()
        do {
            try await Firestore.firestore().collection("users").document(uid).setData(data, merge: true)
        } catch {
            print("[Firestore] Subscription save failed: \(error.localizedDescription)")
        }
    }

    private func refreshFromRemote(uid: String) async {
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
            guard let data = snapshot.data() else { return }
            let plan = (data["subscriptionPlan"] as? String).flatMap(SubscriptionPlan.init(rawValue:))
            let active = data["subscriptionActive"] as? Bool ?? false
            let activatedAt = (data["subscriptionActivatedAt"] as? Timestamp)?.dateValue()
            let expiresAt = (data["subscriptionExpiresAt"] as? Timestamp)?.dateValue()
            let source = data["subscriptionSource"] as? String ?? "none"
            let remote = SubscriptionState(
                plan: plan,
                isActive: active,
                source: source,
                activatedAt: activatedAt,
                expiresAt: expiresAt
            )
            state = remote
            persistLocally(remote)
        } catch {
            print("[Firestore] Subscription load failed: \(error.localizedDescription)")
        }
    }
}
