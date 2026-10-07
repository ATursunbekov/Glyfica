//
//  GlyphPanels.swift
//  Glyfica
//
//  Asymmetric “cut” rectangles for labels and short text blocks.
//

import SwiftUI

/// Preset corner recipes — each corner can differ.
enum GlyphShapeKind: CaseIterable {
    /// Soft top-right / bottom-left, sharper opposite corners.
    case shard
    /// Ticket stub: round on the left, clipped on the right.
    case ticket
    /// Almost even, one sharp corner for a stamp feel.
    case stamp
    /// Soft bottom edge, tighter top — good for callouts.
    case ribbon
    /// Tall tag: sharp top-left, soft elsewhere.
    case notch

    var shape: UnevenRoundedRectangle {
        switch self {
        case .shard:
            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 8,
                topTrailingRadius: 20,
                style: .continuous
            )
        case .ticket:
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 5,
                topTrailingRadius: 5,
                style: .continuous
            )
        case .stamp:
            UnevenRoundedRectangle(
                topLeadingRadius: 14,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 14,
                topTrailingRadius: 4,
                style: .continuous
            )
        case .ribbon:
            UnevenRoundedRectangle(
                topLeadingRadius: 8,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24,
                topTrailingRadius: 8,
                style: .continuous
            )
        case .notch:
            UnevenRoundedRectangle(
                topLeadingRadius: 3,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16,
                style: .continuous
            )
        }
    }
}

/// Colored panel clipped to an uneven rectangle.
struct GlyphPanel<Content: View>: View {
    var kind: GlyphShapeKind = .shard
    var fill: Color = GlyficaColor.surface2.opacity(0.75)
    var stroke: Color = GlyficaColor.gold.opacity(0.35)
    var padding: EdgeInsets = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(fill, in: kind.shape)
            .overlay(
                kind.shape.stroke(stroke, lineWidth: 1)
            )
    }
}

/// Compact uppercase label in an uneven chip.
struct GlyphTag: View {
    let text: String
    var kind: GlyphShapeKind = .stamp
    var emphasized: Bool = false

    var body: some View {
        Text(text)
            .font(GlyficaFont.rounded(11, weight: .bold))
            .foregroundStyle(emphasized ? GlyficaColor.bg : GlyficaColor.gold)
            .textCase(.uppercase)
            .tracking(0.7)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                (emphasized ? GlyficaColor.gold : GlyficaColor.gold.opacity(0.14)),
                in: kind.shape
            )
            .overlay(
                kind.shape.stroke(
                    emphasized ? GlyficaColor.gold : GlyficaColor.gold.opacity(0.4),
                    lineWidth: 1
                )
            )
    }
}

/// Short supporting line or quote inside a cut rectangle.
struct GlyphCallout: View {
    let text: String
    var kind: GlyphShapeKind = .ribbon

    var body: some View {
        GlyphPanel(kind: kind, fill: GlyficaColor.surface.opacity(0.92), stroke: GlyficaColor.line) {
            Text(text)
                .font(GlyficaFont.rounded(14))
                .foregroundStyle(GlyficaColor.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Section eyebrow: uneven tag used above card content.
struct GlyphEyebrow: View {
    let text: String
    var kind: GlyphShapeKind = .notch

    var body: some View {
        GlyphTag(text: text, kind: kind, emphasized: false)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Named alias for text sitting on an uneven cut background.
struct TextBackgroundView<Content: View>: View {
    var kind: GlyphShapeKind = .shard
    var fill: Color = GlyficaColor.surface2.opacity(0.75)
    var stroke: Color = GlyficaColor.gold.opacity(0.35)
    var padding: EdgeInsets = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
    @ViewBuilder var content: Content

    var body: some View {
        GlyphPanel(kind: kind, fill: fill, stroke: stroke, padding: padding) {
            content
        }
    }
}

extension View {
    /// Wraps text (or any content) in an uneven-radius background.
    func textBackground(
        _ kind: GlyphShapeKind = .shard,
        fill: Color = GlyficaColor.surface2.opacity(0.75),
        stroke: Color = GlyficaColor.gold.opacity(0.35),
        padding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    ) -> some View {
        TextBackgroundView(kind: kind, fill: fill, stroke: stroke, padding: padding) {
            self
        }
    }
}
