//
//  NightCard.swift
//  Glyfica
//

import SwiftUI

struct NightCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlyficaColor.surface.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(GlyficaColor.line, lineWidth: 1)
            )
    }
}

struct AppBackground: View {
    var body: some View {
        GlyficaColor.bg
            .overlay {
                Image("background")
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .ignoresSafeArea()
    }
}

struct SignGlyph: View {
    let sign: ZodiacSign
    var size: CGFloat = 44

    var body: some View {
        Image(sign.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(sign.title)
    }
}

struct ScoreBadge: View {
    let value: Int

    var body: some View {
        Text("\(value)%")
            .font(GlyficaFont.rounded(13, weight: .bold))
            .foregroundStyle(GlyficaColor.bg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(GlyficaColor.score(value), in: Capsule())
    }
}

struct NightScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AppBackground()
            content
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct MissingProfilePrompt: View {
    let title: String
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            NightCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(GlyficaFont.rounded(22, weight: .bold))
                        .foregroundStyle(GlyficaColor.ink)
                    Text(message)
                        .font(GlyficaFont.rounded(15))
                        .foregroundStyle(GlyficaColor.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    GlassPrimaryButton(title: "Set up profile", action: action)
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
    }
}

struct GlassPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GlyficaFont.rounded(16, weight: .bold))
                .foregroundStyle(GlyficaColor.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(GlyficaColor.gold)
        .controlSize(.large)
    }
}
