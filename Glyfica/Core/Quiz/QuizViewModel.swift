//
//  QuizViewModel.swift
//  Glyfica
//

import Combine
import Foundation
import UserNotifications

enum QuizStep: Int, CaseIterable, Equatable {
    case gender
    case concern
    case relationship
    case partnerName
    case partnerBirthDate
    case partnerTimeCity
    case birthDate
    case birthTime
    case birthCity
    case microReveal
    case name
    case notifications
    case analyzing
    case preview
}

@MainActor
final class QuizViewModel: ObservableObject {
    @Published var step: QuizStep = .gender
    @Published var analyzingFactIndex = 0
    @Published private(set) var isFinishing = false

    let quizStore: QuizStore
    private let profileStore: ProfileStore
    private let partnerStore: PartnerStore

    private let facts = [
        "Mercury goes retrograde 3–4 times a year.",
        "Your rising sign needs both birth time and place.",
        "A sun sign is only the first layer of a chart.",
        "Compatibility is more than two sun signs meeting.",
        "Life-path numbers come from the full birth date."
    ]

    init(quizStore: QuizStore, profileStore: ProfileStore, partnerStore: PartnerStore) {
        self.quizStore = quizStore
        self.profileStore = profileStore
        self.partnerStore = partnerStore
    }

    var answers: QuizAnswers { quizStore.answers }

    var visibleSteps: [QuizStep] {
        var steps: [QuizStep] = [.gender, .concern, .relationship]
        if answers.relationship?.asksForPartner == true, !answers.skippedPartner {
            steps += [.partnerName, .partnerBirthDate, .partnerTimeCity]
        }
        steps += [
            .birthDate, .birthTime, .birthCity, .microReveal,
            .name, .notifications, .analyzing, .preview
        ]
        return steps
    }

    var progress: Double {
        let steps = visibleSteps.filter { $0 != .analyzing && $0 != .preview }
        guard let index = steps.firstIndex(of: step) else {
            return step == .preview || step == .analyzing ? 1 : 0
        }
        return Double(index + 1) / Double(steps.count)
    }

    var showsProgress: Bool {
        step != .analyzing && step != .preview && step != .microReveal
    }

    var canContinue: Bool {
        switch step {
        case .gender: return answers.gender != nil
        case .concern: return answers.concern != nil
        case .relationship: return answers.relationship != nil
        case .partnerName: return true
        case .partnerBirthDate: return answers.partnerBirthDate != nil || answers.skippedPartner
        case .partnerTimeCity: return true
        case .birthDate: return answers.birthDate != nil
        case .birthTime:
            if answers.knowsBirthTime { return answers.birthTime != nil }
            return answers.birthTimeOfDay != nil
        case .birthCity: return true
        case .microReveal: return true
        case .name: return !answers.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .notifications: return answers.wantsNotifications != nil
        case .analyzing, .preview: return false
        }
    }

    var revealedSign: ZodiacSign? {
        answers.birthDate.map { ZodiacSign.sunSign(for: $0) }
    }

    var analyzingFact: String {
        facts[analyzingFactIndex % facts.count]
    }

    func selectGender(_ value: UserGender) {
        mutate { $0.gender = value }
        advance()
    }

    func selectConcern(_ value: LifeConcern) {
        mutate { $0.concern = value }
        advance()
    }

    func selectRelationship(_ value: RelationshipStatus) {
        mutate {
            $0.relationship = value
            if !value.asksForPartner {
                $0.skippedPartner = true
                $0.partnerName = ""
                $0.partnerBirthDate = nil
                $0.partnerBirthTime = nil
                $0.partnerBirthTimeOfDay = nil
                $0.partnerCity = ""
            } else {
                $0.skippedPartner = false
            }
        }
        advance()
    }

    func skipPartner() {
        mutate {
            $0.skippedPartner = true
            $0.partnerName = ""
            $0.partnerBirthDate = nil
            $0.partnerBirthTime = nil
            $0.partnerBirthTimeOfDay = nil
            $0.partnerCity = ""
        }
        jump(to: .birthDate)
    }

    func setPartnerName(_ value: String) {
        mutate { $0.partnerName = value }
    }

    func setPartnerBirthDate(_ value: Date) {
        mutate { $0.partnerBirthDate = value }
    }

    func setPartnerBirthTime(_ value: Date?) {
        mutate {
            $0.partnerBirthTime = value
            if value != nil { $0.partnerBirthTimeOfDay = nil }
        }
    }

    func setPartnerTimeOfDay(_ value: BirthTimeOfDay?) {
        mutate {
            $0.partnerBirthTimeOfDay = value
            if value != nil { $0.partnerBirthTime = nil }
        }
    }

    func setPartnerCity(_ value: String) {
        mutate { $0.partnerCity = value }
    }

    func setBirthDate(_ value: Date) {
        mutate { $0.birthDate = value }
    }

    func setKnowsBirthTime(_ value: Bool) {
        mutate {
            $0.knowsBirthTime = value
            if value {
                $0.birthTimeOfDay = nil
            } else {
                $0.birthTime = nil
            }
        }
    }

    func setBirthTime(_ value: Date) {
        mutate { $0.birthTime = value }
    }

    func setBirthTimeOfDay(_ value: BirthTimeOfDay) {
        mutate { $0.birthTimeOfDay = value }
    }

    func setCity(_ value: String) {
        mutate { $0.city = value }
    }

    func setName(_ value: String) {
        mutate { $0.name = value }
    }

    func chooseNotifications(_ wants: Bool) {
        mutate { $0.wantsNotifications = wants }
        if wants {
            Task { await requestNotificationPermission() }
        }
        advance()
    }

    private func mutate(_ transform: (inout QuizAnswers) -> Void) {
        quizStore.update(transform)
        objectWillChange.send()
    }

    func advance() {
        guard canContinue || step == .microReveal else { return }
        guard let index = visibleSteps.firstIndex(of: step) else { return }
        let nextIndex = index + 1
        guard nextIndex < visibleSteps.count else { return }
        let next = visibleSteps[nextIndex]
        withStepAnimation { step = next }
        if next == .analyzing {
            Task { await runAnalyzing() }
        }
    }

    func goBack() {
        guard let index = visibleSteps.firstIndex(of: step), index > 0 else { return }
        let previous = visibleSteps[index - 1]
        if previous == .analyzing { return }
        withStepAnimation { step = previous }
    }

    func finish(onComplete: @escaping () -> Void) {
        guard !isFinishing else { return }
        isFinishing = true
        Task {
            await quizStore.complete(profileStore: profileStore, partnerStore: partnerStore)
            isFinishing = false
            onComplete()
        }
    }

    private func jump(to target: QuizStep) {
        withStepAnimation { step = target }
    }

    private func withStepAnimation(_ updates: () -> Void) {
        updates()
    }

    private func runAnalyzing() async {
        analyzingFactIndex = 0
        for index in 0..<facts.count {
            analyzingFactIndex = index
            try? await Task.sleep(for: .milliseconds(1_100))
        }
        try? await Task.sleep(for: .milliseconds(700))
        withStepAnimation { step = .preview }
    }

    private func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
    }
}
