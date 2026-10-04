//
//  FirebaseService.swift
//  Glyfica
//

import FirebaseCore
import Foundation

enum FirebaseService {
    private(set) static var isConfigured = false

    /// `FirebaseApp.configure()` crashes without GoogleService-Info.plist,
    /// so the app keeps working local-only until the file is added.
    static func configureIfPossible() {
        guard !isConfigured else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("[Firebase] GoogleService-Info.plist is missing; running without Firebase.")
            return
        }
        FirebaseApp.configure()
        isConfigured = true
    }
}
