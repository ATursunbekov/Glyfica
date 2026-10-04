//
//  ProfileView.swift
//  Glyfica
//

import SwiftUI

struct ProfileFlowContainerView: View {
    var body: some View {
        NavigationStack {
            ProfileView()
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var partnerStore: PartnerStore
    @EnvironmentObject private var quizStore: QuizStore
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NightScreen {
            ScrollView {
                VStack(spacing: 18) {
                    Text("Profile")
                        .font(GlyficaFont.rounded(28, weight: .bold))
                        .foregroundStyle(GlyficaColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    heroCard

                    if let profile = profileStore.profile {
                        summaryCard(profile)
                    }

                    subscriptionCard

                    settingsCard

                    Text("For entertainment only. Glyfica does not give medical, financial, or legal advice.")
                        .font(GlyficaFont.rounded(12))
                        .foregroundStyle(GlyficaColor.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .onAppear { viewModel.load(from: profileStore.profile) }
        .sheet(isPresented: $viewModel.showEditProfile) {
            EditProfileSheet(viewModel: viewModel, profileStore: profileStore)
        }
        .alert("Restore purchases", isPresented: Binding(
            get: { viewModel.restoreMessage != nil },
            set: { if !$0 { viewModel.restoreMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.restoreMessage = nil }
        } message: {
            Text(viewModel.restoreMessage ?? "")
        }
        .alert("Delete account?", isPresented: $viewModel.showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.confirmDeleteAccount(
                    session: session,
                    quizStore: quizStore,
                    profileStore: profileStore,
                    partnerStore: partnerStore,
                    subscriptionStore: subscriptionStore,
                    router: router
                )
            }
        } message: {
            Text("This removes your chart data and starts Glyfica fresh on this device.")
        }
        .alert("Couldn't delete account", isPresented: Binding(
            get: { viewModel.deleteError != nil },
            set: { if !$0 { viewModel.deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.deleteError = nil }
        } message: {
            Text(viewModel.deleteError ?? "")
        }
    }

    private var heroCard: some View {
        NightCard {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [GlyficaColor.gold.opacity(0.35), GlyficaColor.surface2.opacity(0.2)],
                                center: .center,
                                startRadius: 4,
                                endRadius: 54
                            )
                        )
                        .frame(width: 96, height: 96)

                    Circle()
                        .stroke(GlyficaColor.gold.opacity(0.55), lineWidth: 1.5)
                        .frame(width: 96, height: 96)

                    if let sign = profileStore.profile?.sign {
                        SignGlyph(sign: sign, size: 42)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(GlyficaColor.gold)
                    }
                }

                Text(profileStore.profile?.name ?? "Your profile")
                    .font(GlyficaFont.rounded(22, weight: .bold))
                    .foregroundStyle(GlyficaColor.ink)
                    .multilineTextAlignment(.center)

                if let profile = profileStore.profile {
                    HStack(spacing: 8) {
                        ProfileChip(text: profile.sign.title)
                        ProfileChip(text: "Path \(HoroscopeService.lifePathNumber(from: profile.birthDate))")
                    }
                } else {
                    Text("Complete the quiz to unlock your chart")
                        .font(GlyficaFont.rounded(13))
                        .foregroundStyle(GlyficaColor.ink2)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryCard(_ profile: BirthProfile) -> some View {
        NightCard(padding: 0) {
            VStack(spacing: 0) {
                summaryRow("Gender", profile.gender?.title ?? "—")
                divider
                summaryRow("Focus", profile.concern?.title ?? "—")
                divider
                summaryRow("Relationship", profile.relationship?.title ?? "—")
                divider
                summaryRow("Birth date", profile.birthDate.formatted(date: .abbreviated, time: .omitted))
                divider
                summaryRow(
                    "Birth time",
                    profile.birthTime?.formatted(date: .omitted, time: .shortened) ?? "Not set"
                )
                divider
                summaryRow("City", profile.city.isEmpty ? "Not set" : profile.city)
            }
        }
    }

    private var subscriptionCard: some View {
        NightCard {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription")
                        .font(GlyficaFont.rounded(13))
                        .foregroundStyle(GlyficaColor.ink2)
                    if subscriptionStore.isPremium, let plan = subscriptionStore.state.plan {
                        Text(plan.title)
                            .font(GlyficaFont.rounded(20, weight: .bold))
                            .foregroundStyle(GlyficaColor.ink)
                        if let expires = subscriptionStore.state.expiresAt {
                            Text("Active until \(expires.formatted(date: .abbreviated, time: .omitted))")
                                .font(GlyficaFont.rounded(12))
                                .foregroundStyle(GlyficaColor.gold)
                        }
                    } else {
                        Text("Free")
                            .font(GlyficaFont.rounded(20, weight: .bold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text("Unlock the full chart")
                            .font(GlyficaFont.rounded(12))
                            .foregroundStyle(GlyficaColor.ink2)
                    }
                }
                Spacer()
                Button(subscriptionStore.isPremium ? "Remove test plan" : "Upgrade") {
                    if subscriptionStore.isPremium {
                        Task { await subscriptionStore.clearSubscription() }
                    } else {
                        router.openPaywall(allowSkip: true)
                    }
                }
                .font(GlyficaFont.rounded(13, weight: .bold))
                .foregroundStyle(GlyficaColor.bg)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(GlyficaColor.gold, in: Capsule())
            }
        }
    }

    private var settingsCard: some View {
        NightCard(padding: 0) {
            VStack(spacing: 0) {
                settingsRow("Edit profile", showChevron: true) {
                    viewModel.beginEdit(from: profileStore.profile)
                }
                divider
                settingsRow("Restore purchases", showChevron: true) {
                    viewModel.restorePurchases()
                }
                divider
                settingsRow("Privacy policy", showChevron: true) {
                    viewModel.openPrivacyPolicy()
                }
                divider
                settingsRow("Terms of use", showChevron: true) {
                    viewModel.openTermsOfUse()
                }
                divider
                Button {
                    viewModel.requestDeleteAccount()
                } label: {
                    HStack {
                        if viewModel.isDeleting {
                            ProgressView().tint(GlyficaColor.ink)
                        } else {
                            Text("Delete account")
                                .font(GlyficaFont.rounded(15))
                                .foregroundStyle(GlyficaColor.ink)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isDeleting)
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(GlyficaFont.rounded(14))
                .foregroundStyle(GlyficaColor.ink2)
            Spacer()
            Text(value)
                .font(GlyficaFont.rounded(14, weight: .medium))
                .foregroundStyle(GlyficaColor.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func settingsRow(_ title: String, showChevron: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(GlyficaFont.rounded(15))
                    .foregroundStyle(GlyficaColor.ink)
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GlyficaColor.ink2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(GlyficaColor.line)
            .frame(height: 1)
            .padding(.leading, 18)
    }
}

private struct ProfileChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(GlyficaFont.rounded(12, weight: .semibold))
            .foregroundStyle(GlyficaColor.bg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(GlyficaColor.gold, in: Capsule())
    }
}

private struct EditProfileSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    let profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                GlyficaColor.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Update the details used in your chart and match readings.")
                            .font(GlyficaFont.rounded(14))
                            .foregroundStyle(GlyficaColor.ink2)

                        fieldBlock("Name") {
                            TextField("Your name", text: $viewModel.name)
                                .font(GlyficaFont.rounded(16, weight: .semibold))
                                .foregroundStyle(GlyficaColor.ink)
                                .textInputAutocapitalization(.words)
                        }

                        fieldBlock("Gender") {
                            Picker("Gender", selection: $viewModel.gender) {
                                ForEach(UserGender.allCases) { item in
                                    Text(item.title).tag(item)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        fieldBlock("Focus") {
                            Menu {
                                ForEach(LifeConcern.allCases) { item in
                                    Button(item.title) { viewModel.concern = item }
                                }
                            } label: {
                                menuLabel(viewModel.concern.title)
                            }
                        }

                        fieldBlock("Relationship") {
                            Menu {
                                ForEach(RelationshipStatus.allCases) { item in
                                    Button(item.title) { viewModel.relationship = item }
                                }
                            } label: {
                                menuLabel(viewModel.relationship.title)
                            }
                        }

                        fieldBlock("Birth date") {
                            DatePicker(
                                "Birth date",
                                selection: $viewModel.birthDate,
                                in: ...Date.now,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .colorScheme(.dark)
                        }

                        Toggle(isOn: $viewModel.includesTime) {
                            Text("I know my birth time")
                                .font(GlyficaFont.rounded(15))
                                .foregroundStyle(GlyficaColor.ink)
                        }
                        .tint(GlyficaColor.gold)

                        if viewModel.includesTime {
                            fieldBlock("Birth time") {
                                DatePicker(
                                    "Birth time",
                                    selection: $viewModel.birthTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .colorScheme(.dark)
                            }
                        }

                        fieldBlock("City") {
                            TextField("Birth city", text: $viewModel.city)
                                .font(GlyficaFont.rounded(16, weight: .semibold))
                                .foregroundStyle(GlyficaColor.ink)
                                .textInputAutocapitalization(.words)
                        }

                        if let editError = viewModel.editError {
                            Text(editError)
                                .font(GlyficaFont.rounded(13))
                                .foregroundStyle(GlyficaColor.danger)
                        }

                        GlassPrimaryButton(title: viewModel.isSaving ? "Saving..." : "Save") {
                            viewModel.save(to: profileStore)
                        }
                        .disabled(viewModel.isSaving)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(GlyficaColor.ink)
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    private func fieldBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(GlyficaFont.rounded(12))
                .foregroundStyle(GlyficaColor.ink2)
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GlyficaColor.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GlyficaColor.line, lineWidth: 1)
                )
        }
    }

    private func menuLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(GlyficaFont.rounded(16, weight: .semibold))
                .foregroundStyle(GlyficaColor.ink)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(GlyficaColor.gold)
        }
    }
}
