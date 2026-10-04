//
//  SessionStore.swift
//  Glyfica
//
//  First thing on launch: silent Firebase Anonymous Auth. No UI. The uid
//  keys Firestore writes for the quiz and later Apple account linking.
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var uid: String?
    @Published private(set) var isAnonymous = false
    @Published private(set) var isReady = false
    @Published private(set) var lastError: String?

    private var authListener: AuthStateDidChangeListenerHandle?

    /// Call once at launch. Restores an existing session or creates a new
    /// anonymous user, then marks the session ready.
    func start() async {
        guard !isReady else { return }

        guard FirebaseService.isConfigured else {
            lastError = "Firebase is not configured."
            isReady = true
            return
        }

        listenForAuthChanges()

        if let user = Auth.auth().currentUser {
            apply(user)
            await ensureUserDocument(uid: user.uid)
            isReady = true
            return
        }

        do {
            let result = try await Auth.auth().signInAnonymously()
            apply(result.user)
            await ensureUserDocument(uid: result.user.uid)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            print("[Firebase] Anonymous sign-in failed: \(error.localizedDescription)")
        }

        isReady = true
    }

    /// Splash / quiz wait here so Firestore writes always have a uid.
    func waitUntilReady() async {
        if isReady { return }
        await start()
        while !isReady {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    func retryAnonymousSignIn() async {
        isReady = false
        lastError = nil
        await start()
    }

    /// Deletes the Firebase Auth user (and any linked providers), then
    /// creates a fresh anonymous session for the next onboarding pass.
    func deleteAccountAndStartFresh() async throws {
        guard FirebaseService.isConfigured, let user = Auth.auth().currentUser else {
            uid = nil
            isAnonymous = false
            isReady = false
            await start()
            return
        }

        let oldUID = user.uid
        try await Firestore.firestore().collection("users").document(oldUID).delete()
        try await user.delete()

        uid = nil
        isAnonymous = false
        isReady = false
        lastError = nil
        await start()
    }

    private func listenForAuthChanges() {
        guard authListener == nil else { return }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                if let user {
                    self.apply(user)
                } else {
                    self.uid = nil
                    self.isAnonymous = false
                }
            }
        }
    }

    private func apply(_ user: User) {
        uid = user.uid
        isAnonymous = user.isAnonymous
    }

    /// Creates `users/{uid}` if missing so the anonymous user exists in
    /// Firestore before the quiz starts writing profile fields.
    private func ensureUserDocument(uid: String) async {
        guard FirebaseService.isConfigured else { return }
        let ref = Firestore.firestore().collection("users").document(uid)
        do {
            let snapshot = try await ref.getDocument()
            if snapshot.exists { return }
            try await ref.setData([
                "isAnonymous": true,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("[Firestore] Could not ensure user doc: \(error.localizedDescription)")
        }
    }
}
