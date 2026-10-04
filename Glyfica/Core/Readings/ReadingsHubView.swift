//
//  ReadingsHubView.swift
//  Glyfica
//
//  Hub for Match, Tarot, and Palm under one tab ("Oracle").
//

import SwiftUI

enum OracleDestination: String, Hashable, Identifiable, CaseIterable {
    case match
    case tarot
    case palm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .match: return "Match"
        case .tarot: return "Tarot"
        case .palm: return "Palm"
        }
    }

    var subtitle: String {
        switch self {
        case .match: return "Chemistry between two charts"
        case .tarot: return "Ask a question, then draw the cards"
        case .palm: return "Photograph your hand for a reading"
        }
    }

    var icon: String {
        switch self {
        case .match: return "heart.fill"
        case .tarot: return "rectangle.stack.fill"
        case .palm: return "hand.raised.fill"
        }
    }
}

struct ReadingsFlowContainerView: View {
    @State private var path: [OracleDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            ReadingsHubView(path: $path)
                .navigationDestination(for: OracleDestination.self) { destination in
                    OracleBackContainer {
                        switch destination {
                        case .match: CompatibilityView()
                        case .tarot: TarotView()
                        case .palm: PalmView()
                        }
                    }
                }
        }
    }
}

struct ReadingsHubView: View {
    @Binding var path: [OracleDestination]

    var body: some View {
        NightScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Oracle")
                            .font(GlyficaFont.rounded(34, weight: .bold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text("Choose how you want to look — through a match, the cards, or your palm.")
                            .font(GlyficaFont.rounded(16))
                            .foregroundStyle(GlyficaColor.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)

                    VStack(spacing: 12) {
                        ForEach(OracleDestination.allCases) { destination in
                            Button {
                                path.append(destination)
                            } label: {
                                destinationRow(destination)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private func destinationRow(_ destination: OracleDestination) -> some View {
        NightCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(GlyficaColor.gold.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: destination.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(GlyficaColor.gold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.title)
                        .font(GlyficaFont.rounded(20, weight: .bold))
                        .foregroundStyle(GlyficaColor.ink)
                    Text(destination.subtitle)
                        .font(GlyficaFont.rounded(14))
                        .foregroundStyle(GlyficaColor.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GlyficaColor.ink2)
            }
        }
    }
}

private struct OracleBackContainer<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            content

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GlyficaColor.ink)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 20)
            .padding(.top, 8)
            .zIndex(1)
        }
    }
}
