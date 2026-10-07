//
//  ReadingsHubView.swift
//  Glyfica
//
//  Hub for Match, Palm, and Cup under one tab ("Oracle").
//  Tarot lives in its own tab.
//

import SwiftUI

enum OracleDestination: String, Hashable, Identifiable, CaseIterable {
    case match
    case palm
    case cup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .match: return "Match"
        case .palm: return "Palm"
        case .cup: return "Cup"
        }
    }

    var subtitle: String {
        switch self {
        case .match: return "Chemistry between two charts"
        case .palm: return "Photograph your hand for a reading"
        case .cup: return "Read the shapes in your coffee grounds"
        }
    }

    var icon: String {
        switch self {
        case .match: return "heart.fill"
        case .palm: return "hand.raised.fill"
        case .cup: return "cup.and.saucer.fill"
        }
    }
}

struct ReadingsFlowContainerView: View {
    @State private var path: [OracleDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            ReadingsHubView(path: $path)
                .navigationDestination(for: OracleDestination.self) { destination in
                    OracleDetailContainer(path: $path) {
                        switch destination {
                        case .match: CompatibilityView()
                        case .palm: PalmView()
                        case .cup: TasseographyView()
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
                        Text("Choose how you want to look — through a match, your palm, or the cup.")
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
                            .buttonStyle(.glyficaPlain)
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

/// Pushes content down so back never overlaps titles, pops via path, hides tab bar.
private struct OracleDetailContainer<Content: View>: View {
    @Binding var path: [OracleDestination]
    @ViewBuilder var content: Content

    var body: some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Button {
                        guard !path.isEmpty else { return }
                        path.removeLast()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(GlyficaColor.ink)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .glassEffect(.regular.interactive(), in: Circle())
                    }
                    .buttonStyle(.glyficaPlain)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 6)
            }
            .toolbar(.hidden, for: .tabBar)
    }
}
