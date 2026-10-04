//
//  ProfileViewModel.swift
//  Glyfica
//

import Combine
import Foundation
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var showEditProfile = false
    @Published var name = ""
    @Published var gender: UserGender = .preferNotToSay
    @Published var concern: LifeConcern = .selfDiscovery
    @Published var relationship: RelationshipStatus = .single
    @Published var birthDate = ProfileViewModel.defaultBirthDate
    @Published var includesTime = false
    @Published var birthTime = ProfileViewModel.defaultBirthDate
    @Published var city = ""
    @Published var editError: String?
    @Published var isSaving = false

    @Published var restoreMessage: String?
    @Published var showDeleteConfirm = false
    @Published var deleteError: String?
    @Published var isDeleting = false
    @Published var statusMessage: String?

    func beginEdit(from profile: BirthProfile?) {
        load(from: profile)
        editError = nil
        showEditProfile = true
    }

    func load(from profile: BirthProfile?) {
        guard let profile else { return }
        name = profile.name
        gender = profile.gender ?? .preferNotToSay
        concern = profile.concern ?? .selfDiscovery
        relationship = profile.relationship ?? .single
        birthDate = profile.birthDate
        includesTime = profile.birthTime != nil
        birthTime = profile.birthTime ?? profile.birthDate
        city = profile.city
    }

    func save(to store: ProfileStore) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            editError = "Add the name you want on the chart."
            return
        }
        isSaving = true
        editError = nil
        let profile = BirthProfile(
            name: trimmed,
            birthDate: birthDate,
            birthTime: includesTime ? birthTime : nil,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: gender,
            concern: concern,
            relationship: relationship
        )
        store.save(profile)
        isSaving = false
        showEditProfile = false
        statusMessage = "Saved"
    }

    func openPrivacyPolicy() {
        UIApplication.shared.open(Constants.privacyPolicyURL)
    }

    func openTermsOfUse() {
        UIApplication.shared.open(Constants.termsOfUseURL)
    }

    func restorePurchases() {
        restoreMessage = "No purchases to restore yet. Subscriptions will appear here after the paywall is live."
    }

    func requestDeleteAccount() {
        deleteError = nil
        showDeleteConfirm = true
    }

    func confirmDeleteAccount(
        session: SessionStore,
        quizStore: QuizStore,
        profileStore: ProfileStore,
        partnerStore: PartnerStore,
        subscriptionStore: SubscriptionStore,
        router: AppRouter
    ) {
        showDeleteConfirm = false
        isDeleting = true
        deleteError = nil
        Task {
            do {
                try await session.deleteAccountAndStartFresh()
                quizStore.reset()
                quizStore.attach(uid: session.uid)
                profileStore.clear()
                partnerStore.clear()
                await subscriptionStore.clearSubscription()
                await profileStore.attach(uid: session.uid)
                await partnerStore.attach(uid: session.uid)
                await subscriptionStore.attach(uid: session.uid)
                router.restartOnboarding()
            } catch {
                deleteError = error.localizedDescription
            }
            isDeleting = false
        }
    }

    var lifePath: Int? {
        HoroscopeService.lifePathNumber(from: birthDate)
    }

    private static var defaultBirthDate: Date {
        Calendar.current.date(from: DateComponents(year: 1998, month: 6, day: 15)) ?? .now
    }
}
