//
//  GlyficaApp.swift
//  Glyfica
//

import SwiftUI

@main
struct GlyficaApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var session = SessionStore()
    @StateObject private var quizStore = QuizStore()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var partnerStore = PartnerStore()
    @StateObject private var subscriptionStore = SubscriptionStore()

    init() {
        FirebaseService.configureIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .environmentObject(session)
                .environmentObject(quizStore)
                .environmentObject(profileStore)
                .environmentObject(partnerStore)
                .environmentObject(subscriptionStore)
        }
    }
}
