//
//  TarotView.swift
//  Glyfica
//

import SwiftUI

struct TarotFlowContainerView: View {
    var body: some View {
        NavigationStack {
            TarotView()
        }
    }
}

struct TarotView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @StateObject private var viewModel = TarotViewModel()

    var body: some View {
        NightScreen {
            Group {
                if viewModel.isLoading {
                    loadingState
                } else if let reading = viewModel.reading {
                    resultContent(reading)
                } else {
                    setupContent
                }
            }
        }
    }

    // MARK: - Setup

    private var setupContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                questionSection

                NightCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a spread")
                            .font(GlyficaFont.rounded(13, weight: .semibold))
                            .foregroundStyle(GlyficaColor.gold)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        ForEach(TarotSpread.allCases) { spread in
                            spreadRow(spread)
                        }
                    }
                }

                if viewModel.hasDraw {
                    if viewModel.hasQuestion {
                        NightCard(padding: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Your question")
                                    .font(GlyficaFont.rounded(12, weight: .semibold))
                                    .foregroundStyle(GlyficaColor.gold)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                Text(viewModel.resolvedQuestion)
                                    .font(GlyficaFont.rounded(15))
                                    .foregroundStyle(GlyficaColor.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    drawnCardsSection

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(GlyficaFont.rounded(14))
                            .foregroundStyle(GlyficaColor.danger)
                    }

                    GlassPrimaryButton(title: "Read the cards") {
                        Task { await viewModel.readCards(profile: profileStore.profile) }
                    }
                    .disabled(!viewModel.canRead)
                    .opacity(viewModel.canRead ? 1 : 0.5)

                    Button("Draw again") {
                        viewModel.drawCards()
                    }
                    .font(GlyficaFont.rounded(15, weight: .semibold))
                    .foregroundStyle(GlyficaColor.gold)
                    .frame(maxWidth: .infinity)
                } else {
                    NightCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ready when you are")
                                .font(GlyficaFont.rounded(18, weight: .bold))
                                .foregroundStyle(GlyficaColor.ink)
                            Text("Hold your question in mind. We’ll shuffle the deck, draw the cards, then read them for that question.")
                                .font(GlyficaFont.rounded(15))
                                .foregroundStyle(GlyficaColor.ink2)
                                .fixedSize(horizontal: false, vertical: true)

                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(GlyficaFont.rounded(14))
                                    .foregroundStyle(GlyficaColor.danger)
                            }

                            GlassPrimaryButton(title: "Draw cards") {
                                viewModel.drawCards()
                            }
                            .disabled(!viewModel.canDraw)
                            .opacity(viewModel.canDraw ? 1 : 0.5)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    private var questionSection: some View {
        NightCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("What do you want to know?")
                    .font(GlyficaFont.rounded(13, weight: .semibold))
                    .foregroundStyle(GlyficaColor.gold)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text("Ask first, then draw. The reading will answer this question.")
                    .font(GlyficaFont.rounded(14))
                    .foregroundStyle(GlyficaColor.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                FlowTopicGrid(topics: TarotTopic.allCases, selected: viewModel.topic) { topic in
                    viewModel.selectTopic(topic)
                }

                if viewModel.topic == .custom {
                    TextField("Type your question…", text: $viewModel.customQuestion, axis: .vertical)
                        .font(GlyficaFont.rounded(16))
                        .foregroundStyle(GlyficaColor.ink)
                        .lineLimit(3...5)
                        .padding(12)
                        .background(
                            GlyficaColor.surface2.opacity(0.7),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .onChange(of: viewModel.customQuestion) { _, _ in
                            viewModel.questionEdited()
                        }
                } else {
                    Text(viewModel.resolvedQuestion)
                        .font(GlyficaFont.rounded(15))
                        .foregroundStyle(GlyficaColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func spreadRow(_ spread: TarotSpread) -> some View {
        let selected = viewModel.spread == spread
        return Button {
            viewModel.changeSpread(spread)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(spread.title)
                        .font(GlyficaFont.rounded(16, weight: .semibold))
                        .foregroundStyle(GlyficaColor.ink)
                    Text(spread.subtitle)
                        .font(GlyficaFont.rounded(13))
                        .foregroundStyle(GlyficaColor.ink2)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? GlyficaColor.gold : GlyficaColor.ink2)
            }
            .padding(14)
            .background(
                (selected ? GlyficaColor.gold.opacity(0.12) : GlyficaColor.surface2.opacity(0.55)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? GlyficaColor.gold.opacity(0.45) : GlyficaColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(.glyficaPlain)
    }

    private var drawnCardsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your draw")
                .font(GlyficaFont.rounded(13, weight: .semibold))
                .foregroundStyle(GlyficaColor.gold)
                .textCase(.uppercase)
                .tracking(0.5)

            NightCard(padding: 16) {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(viewModel.drawnCards) { card in
                            VStack(spacing: 10) {
                                Text(card.position.uppercased())
                                    .font(GlyficaFont.rounded(11, weight: .bold))
                                    .foregroundStyle(GlyficaColor.gold)
                                    .tracking(0.5)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                TarotCardArt(
                                    assetName: card.card.assetName,
                                    isReversed: card.isReversed,
                                    width: viewModel.drawnCards.count == 1 ? 148 : 104
                                )

                                Text(card.card.name)
                                    .font(GlyficaFont.rounded(13, weight: .semibold))
                                    .foregroundStyle(GlyficaColor.ink)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)

                                if card.isReversed {
                                    Text("Reversed")
                                        .font(GlyficaFont.rounded(11, weight: .semibold))
                                        .foregroundStyle(GlyficaColor.ink2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            NightCard {
                VStack(alignment: .leading, spacing: 14) {
                    if !viewModel.drawnCards.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(viewModel.drawnCards) { card in
                                TarotCardArt(
                                    assetName: card.card.assetName,
                                    isReversed: card.isReversed,
                                    width: viewModel.drawnCards.count == 1 ? 88 : 64
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(GlyficaColor.gold)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reading the cards…")
                                .font(GlyficaFont.rounded(16, weight: .semibold))
                                .foregroundStyle(GlyficaColor.ink)
                            Text("Answering your question through this spread.")
                                .font(GlyficaFont.rounded(14))
                                .foregroundStyle(GlyficaColor.ink2)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
    }

    // MARK: - Result

    private func resultContent(_ reading: TarotReading) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                NightCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your question")
                            .font(GlyficaFont.rounded(12, weight: .semibold))
                            .foregroundStyle(GlyficaColor.gold)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Text(reading.question)
                            .font(GlyficaFont.rounded(16, weight: .semibold))
                            .foregroundStyle(GlyficaColor.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider().overlay(GlyficaColor.line)

                        Text(reading.spread.title)
                            .font(GlyficaFont.rounded(13, weight: .semibold))
                            .foregroundStyle(GlyficaColor.gold)
                        Text(reading.headline)
                            .font(GlyficaFont.rounded(22, weight: .bold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text(reading.overview)
                            .font(GlyficaFont.rounded(16))
                            .foregroundStyle(GlyficaColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }
                }

                // Spread overview strip
                NightCard(padding: 14) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(reading.cards) { card in
                            VStack(spacing: 8) {
                                Text(card.position.uppercased())
                                    .font(GlyficaFont.rounded(10, weight: .bold))
                                    .foregroundStyle(GlyficaColor.gold)
                                    .tracking(0.4)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                TarotCardArt(
                                    assetName: card.assetName,
                                    isReversed: card.isReversed,
                                    width: reading.cards.count == 1 ? 120 : 92
                                )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                ForEach(reading.cards) { card in
                    NightCard {
                        HStack(alignment: .top, spacing: 14) {
                            TarotCardArt(
                                assetName: card.assetName,
                                isReversed: card.isReversed,
                                width: 92
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text(card.position.uppercased())
                                    .font(GlyficaFont.rounded(11, weight: .bold))
                                    .foregroundStyle(GlyficaColor.gold)
                                    .tracking(0.6)
                                Text(card.displayName)
                                    .font(GlyficaFont.rounded(18, weight: .bold))
                                    .foregroundStyle(GlyficaColor.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(card.meaning)
                                    .font(GlyficaFont.rounded(15))
                                    .foregroundStyle(GlyficaColor.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(2)
                            }
                        }
                    }
                }

                if !reading.advice.isEmpty {
                    NightCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Advice")
                                .font(GlyficaFont.rounded(13, weight: .semibold))
                                .foregroundStyle(GlyficaColor.gold)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Text(reading.advice)
                                .font(GlyficaFont.rounded(15))
                                .foregroundStyle(GlyficaColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                GlassPrimaryButton(title: "New reading") {
                    viewModel.reset()
                }

                Text("For entertainment only. Not medical, financial, or legal advice.")
                    .font(GlyficaFont.rounded(11))
                    .foregroundStyle(GlyficaColor.ink2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Shared

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tarot")
                .font(GlyficaFont.rounded(28, weight: .bold))
                .foregroundStyle(GlyficaColor.ink)
            Text("Ask first. Then draw.")
                .font(GlyficaFont.rounded(14))
                .foregroundStyle(GlyficaColor.ink2)
        }
    }
}

// MARK: - Card art

struct TarotCardArt: View {
    let assetName: String
    var isReversed: Bool = false
    var width: CGFloat = 104

    private var height: CGFloat { width * 1.72 }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(GlyficaColor.gold.opacity(0.4), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if isReversed {
                    Text("REV")
                        .font(GlyficaFont.rounded(max(9, width * 0.1), weight: .bold))
                        .foregroundStyle(GlyficaColor.bg)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(GlyficaColor.gold, in: Capsule())
                        .padding(6)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            // Keep art upright — reversed is shown via badge/label, not by flipping the image.
            .accessibilityLabel(isReversed ? "\(assetName), reversed" : assetName)
    }
}

private struct FlowTopicGrid: View {
    let topics: [TarotTopic]
    let selected: TarotTopic
    let onSelect: (TarotTopic) -> Void

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(topics) { topic in
                let isOn = selected == topic
                Button {
                    onSelect(topic)
                } label: {
                    Text(topic.title)
                        .font(GlyficaFont.rounded(14, weight: .semibold))
                        .foregroundStyle(isOn ? GlyficaColor.bg : GlyficaColor.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            isOn ? GlyficaColor.gold : GlyficaColor.surface2.opacity(0.7),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(.glyficaPlain)
            }
        }
    }
}
