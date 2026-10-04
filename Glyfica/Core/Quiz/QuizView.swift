//
//  QuizView.swift
//  Glyfica
//

import SwiftUI

struct QuizFlowView: View {
    @EnvironmentObject private var quizStore: QuizStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var partnerStore: PartnerStore
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        QuizRoot(
            quizStore: quizStore,
            profileStore: profileStore,
            partnerStore: partnerStore,
            onFinished: { router.completeQuiz() }
        )
    }
}

private struct QuizRoot: View {
    @StateObject private var viewModel: QuizViewModel
    let onFinished: () -> Void

    init(
        quizStore: QuizStore,
        profileStore: ProfileStore,
        partnerStore: PartnerStore,
        onFinished: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: QuizViewModel(
                quizStore: quizStore,
                profileStore: profileStore,
                partnerStore: partnerStore
            )
        )
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                if viewModel.showsProgress {
                    header
                }

                Group {
                    switch viewModel.step {
                    case .gender: genderStep
                    case .concern: concernStep
                    case .relationship: relationshipStep
                    case .partnerName: partnerNameStep
                    case .partnerBirthDate: partnerBirthDateStep
                    case .partnerTimeCity: partnerTimeCityStep
                    case .birthDate: birthDateStep
                    case .birthTime: birthTimeStep
                    case .birthCity: birthCityStep
                    case .microReveal: microRevealStep
                    case .name: nameStep
                    case .notifications: notificationsStep
                    case .analyzing: analyzingStep
                    case .preview: previewStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 20)
                .animation(.easeOut(duration: 0.22), value: viewModel.step)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                if viewModel.step != .gender {
                    Button {
                        viewModel.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(GlyficaColor.ink)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.interactive(), in: Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(GlyficaColor.surface2.opacity(0.55))
                    Capsule()
                        .fill(GlyficaColor.gold)
                        .frame(width: max(8, geo.size.width * viewModel.progress))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var genderStep: some View {
        QuizStepLayout(
            title: "How should we speak to you?",
            subtitle: "This only shapes the tone of your readings."
        ) {
            VStack(spacing: 12) {
                ForEach(UserGender.allCases) { gender in
                    QuizOptionButton(title: gender.title, isSelected: viewModel.answers.gender == gender) {
                        viewModel.selectGender(gender)
                    }
                }
            }
        }
    }

    private var concernStep: some View {
        QuizStepLayout(
            title: "What do you need clarity on?",
            subtitle: "We'll lead with this in your first reading."
        ) {
            VStack(spacing: 12) {
                ForEach(LifeConcern.allCases) { concern in
                    QuizOptionButton(
                        title: concern.title,
                        subtitle: concern.subtitle,
                        isSelected: viewModel.answers.concern == concern
                    ) {
                        viewModel.selectConcern(concern)
                    }
                }
            }
        }
    }

    private var relationshipStep: some View {
        QuizStepLayout(
            title: "Where are you in love right now?",
            subtitle: "This sets the tone for compatibility and advice."
        ) {
            VStack(spacing: 12) {
                ForEach(RelationshipStatus.allCases) { status in
                    QuizOptionButton(title: status.title, isSelected: viewModel.answers.relationship == status) {
                        viewModel.selectRelationship(status)
                    }
                }
            }
        }
    }

    private var partnerNameStep: some View {
        QuizStepLayout(
            title: "Who is on your mind?",
            subtitle: "A first name is enough for the match reading."
        ) {
            VStack(spacing: 16) {
                QuizTextField(
                    placeholder: "Their name",
                    text: Binding(
                        get: { viewModel.answers.partnerName },
                        set: viewModel.setPartnerName
                    )
                )
                GlassPrimaryButton(title: "Continue") { viewModel.advance() }
                Button("Skip for now") { viewModel.skipPartner() }
                    .font(GlyficaFont.rounded(14, weight: .medium))
                    .foregroundStyle(GlyficaColor.ink2)
            }
        }
    }

    private var partnerBirthDateStep: some View {
        QuizStepLayout(
            title: "When were they born?",
            subtitle: "Their sun sign comes from this date."
        ) {
            VStack(spacing: 16) {
                DatePicker(
                    "Partner birth date",
                    selection: Binding(
                        get: { viewModel.answers.partnerBirthDate ?? defaultAdultDate },
                        set: viewModel.setPartnerBirthDate
                    ),
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .frame(maxHeight: 180)

                GlassPrimaryButton(title: "Continue") {
                    if viewModel.answers.partnerBirthDate == nil {
                        viewModel.setPartnerBirthDate(defaultAdultDate)
                    }
                    viewModel.advance()
                }
                Button("Skip partner details") { viewModel.skipPartner() }
                    .font(GlyficaFont.rounded(14, weight: .medium))
                    .foregroundStyle(GlyficaColor.ink2)
            }
        }
    }

    private var partnerTimeCityStep: some View {
        QuizStepLayout(
            title: "Anything else you know?",
            subtitle: "Time and city can wait — both are optional."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Birth time")
                    .font(GlyficaFont.rounded(13))
                    .foregroundStyle(GlyficaColor.ink2)

                if viewModel.answers.partnerBirthTime == nil {
                    Button("Add exact time") {
                        viewModel.setPartnerBirthTime(defaultAdultDate)
                    }
                    .buttonStyle(QuizSecondaryButtonStyle())
                } else {
                    DatePicker(
                        "Partner birth time",
                        selection: Binding(
                            get: { viewModel.answers.partnerBirthTime ?? defaultAdultDate },
                            set: { viewModel.setPartnerBirthTime($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .colorScheme(.dark)

                    Button("Clear time") {
                        viewModel.setPartnerBirthTime(nil)
                    }
                    .font(GlyficaFont.rounded(13, weight: .medium))
                    .foregroundStyle(GlyficaColor.ink2)
                }

                Text("City")
                    .font(GlyficaFont.rounded(13))
                    .foregroundStyle(GlyficaColor.ink2)
                QuizTextField(
                    placeholder: "Birth city (optional)",
                    text: Binding(
                        get: { viewModel.answers.partnerCity },
                        set: viewModel.setPartnerCity
                    )
                )

                GlassPrimaryButton(title: "Continue") { viewModel.advance() }
            }
        }
    }

    private var birthDateStep: some View {
        QuizStepLayout(
            title: "When were you born?",
            subtitle: "Your sun sign and life-path number start here."
        ) {
            VStack(spacing: 16) {
                DatePicker(
                    "Birth date",
                    selection: Binding(
                        get: { viewModel.answers.birthDate ?? defaultAdultDate },
                        set: viewModel.setBirthDate
                    ),
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .frame(maxHeight: 180)

                privacyNote

                GlassPrimaryButton(title: "Continue") {
                    if viewModel.answers.birthDate == nil {
                        viewModel.setBirthDate(defaultAdultDate)
                    }
                    viewModel.advance()
                }
            }
        }
    }

    private var birthTimeStep: some View {
        QuizStepLayout(
            title: "Do you know your birth time?",
            subtitle: "Exact time unlocks rising sign and houses. An approximate time of day still helps."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                QuizOptionButton(
                    title: "Yes, I know the exact time",
                    isSelected: viewModel.answers.knowsBirthTime
                ) {
                    viewModel.setKnowsBirthTime(true)
                }
                QuizOptionButton(
                    title: "I don't know the exact time",
                    isSelected: !viewModel.answers.knowsBirthTime
                ) {
                    viewModel.setKnowsBirthTime(false)
                }

                if viewModel.answers.knowsBirthTime {
                    DatePicker(
                        "Birth time",
                        selection: Binding(
                            get: { viewModel.answers.birthTime ?? defaultAdultDate },
                            set: viewModel.setBirthTime
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxHeight: 160)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(BirthTimeOfDay.allCases) { slot in
                            QuizOptionButton(
                                title: slot.title,
                                isSelected: viewModel.answers.birthTimeOfDay == slot
                            ) {
                                viewModel.setBirthTimeOfDay(slot)
                            }
                        }
                    }
                }

                GlassPrimaryButton(title: "Continue") {
                    if viewModel.answers.knowsBirthTime, viewModel.answers.birthTime == nil {
                        viewModel.setBirthTime(defaultAdultDate)
                    }
                    viewModel.advance()
                }
                .opacity(viewModel.canContinue ? 1 : 0.45)
                .disabled(!viewModel.canContinue)
            }
        }
    }

    private var birthCityStep: some View {
        QuizStepLayout(
            title: "Where were you born?",
            subtitle: "City helps with timezone when we calculate a fuller chart."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                QuizTextField(
                    placeholder: "Birth city",
                    text: Binding(
                        get: { viewModel.answers.city },
                        set: viewModel.setCity
                    )
                )
                privacyNote
                GlassPrimaryButton(title: "Continue") { viewModel.advance() }
                Button("Skip for now") {
                    viewModel.setCity("")
                    viewModel.advance()
                }
                .font(GlyficaFont.rounded(14, weight: .medium))
                .foregroundStyle(GlyficaColor.ink2)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var microRevealStep: some View {
        VStack(spacing: 24) {
            Spacer()
            if let sign = viewModel.revealedSign {
                NightCard {
                    VStack(spacing: 16) {
                        Text("Your sun sign")
                            .font(GlyficaFont.rounded(14))
                            .foregroundStyle(GlyficaColor.gold)
                        SignGlyph(sign: sign, size: 72)
                        Text(sign.title)
                            .font(GlyficaFont.rounded(32, weight: .bold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text(sign.personality)
                            .font(GlyficaFont.rounded(16))
                            .foregroundStyle(GlyficaColor.ink2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            GlassPrimaryButton(title: "Continue") { viewModel.advance() }
            Spacer()
        }
        .padding(.bottom, 24)
    }

    private var nameStep: some View {
        QuizStepLayout(
            title: "What should we call you?",
            subtitle: "This is how your reading addresses you."
        ) {
            VStack(spacing: 16) {
                QuizTextField(
                    placeholder: "Your name or nickname",
                    text: Binding(
                        get: { viewModel.answers.name },
                        set: viewModel.setName
                    )
                )
                GlassPrimaryButton(title: "Continue") { viewModel.advance() }
                    .opacity(viewModel.canContinue ? 1 : 0.45)
                    .disabled(!viewModel.canContinue)
            }
        }
    }

    private var notificationsStep: some View {
        QuizStepLayout(
            title: "Want your forecast every morning?",
            subtitle: "A short daily note for your sign. You can change this later."
        ) {
            VStack(spacing: 12) {
                GlassPrimaryButton(title: "Yes, remind me") {
                    viewModel.chooseNotifications(true)
                }
                Button("Not now") {
                    viewModel.chooseNotifications(false)
                }
                .font(GlyficaFont.rounded(16, weight: .semibold))
                .foregroundStyle(GlyficaColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
        }
    }

    private var analyzingStep: some View {
        VStack(spacing: 28) {
            Spacer()
            ProgressView()
                .tint(GlyficaColor.gold)
                .scaleEffect(1.3)
            Text("Reading your chart...")
                .font(GlyficaFont.rounded(24, weight: .bold))
                .foregroundStyle(GlyficaColor.ink)
            Text(viewModel.analyzingFact)
                .font(GlyficaFont.rounded(15))
                .foregroundStyle(GlyficaColor.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .id(viewModel.analyzingFactIndex)
                .transition(.opacity)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var previewStep: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)
            if let sign = viewModel.revealedSign {
                NightCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            SignGlyph(sign: sign, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.answers.name.isEmpty ? "Your reading" : viewModel.answers.name)
                                    .font(GlyficaFont.rounded(20, weight: .bold))
                                    .foregroundStyle(GlyficaColor.ink)
                                Text(sign.title)
                                    .font(GlyficaFont.rounded(14))
                                    .foregroundStyle(GlyficaColor.gold)
                            }
                        }
                        Text(sign.personality)
                            .font(GlyficaFont.rounded(15))
                            .foregroundStyle(GlyficaColor.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        ZStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Life path, daily focus, and the match reading are ready.")
                                    .font(GlyficaFont.rounded(15))
                                    .foregroundStyle(GlyficaColor.ink2)
                                Text("Your full character breakdown, compatibility scores, and today's guidance unlock next.")
                                    .font(GlyficaFont.rounded(15))
                                    .foregroundStyle(GlyficaColor.ink2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .blur(radius: 4)

                            LinearGradient(
                                colors: [.clear, GlyficaColor.surface.opacity(0.95)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 70)
                        }
                    }
                }
            }

            Text("For entertainment only. Not medical, financial, or legal advice.")
                .font(GlyficaFont.rounded(11))
                .foregroundStyle(GlyficaColor.ink2)
                .multilineTextAlignment(.center)

            GlassPrimaryButton(
                title: viewModel.isFinishing ? "Saving..." : "See my full reading"
            ) {
                viewModel.finish(onComplete: onFinished)
            }
            .disabled(viewModel.isFinishing)
            Spacer(minLength: 8)
        }
    }

    private var privacyNote: some View {
        Text("Birth details are used to personalize your reading. See our Privacy Policy.")
            .font(GlyficaFont.rounded(12))
            .foregroundStyle(GlyficaColor.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var defaultAdultDate: Date {
        Calendar.current.date(from: DateComponents(year: 1998, month: 6, day: 15, hour: 12)) ?? .now
    }
}

struct QuizStepLayout<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(GlyficaFont.rounded(28, weight: .bold))
                        .foregroundStyle(GlyficaColor.ink)
                    Text(subtitle)
                        .font(GlyficaFont.rounded(15))
                        .foregroundStyle(GlyficaColor.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct QuizOptionButton: View {
    let title: String
    var subtitle: String?
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(GlyficaFont.rounded(17, weight: .semibold))
                        .foregroundStyle(GlyficaColor.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(GlyficaFont.rounded(13))
                            .foregroundStyle(GlyficaColor.ink2)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(GlyficaColor.gold)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? GlyficaColor.surface2.opacity(0.85) : GlyficaColor.surface.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? GlyficaColor.gold.opacity(0.7) : GlyficaColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct QuizTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(GlyficaFont.rounded(17, weight: .semibold))
            .foregroundStyle(GlyficaColor.ink)
            .padding(16)
            .background(GlyficaColor.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(GlyficaColor.line, lineWidth: 1)
            )
            .textInputAutocapitalization(.words)
    }
}

struct QuizSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GlyficaFont.rounded(14, weight: .semibold))
            .foregroundStyle(GlyficaColor.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(GlyficaColor.surface2.opacity(0.7), in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
