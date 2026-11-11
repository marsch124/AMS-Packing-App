import SwiftUI

// Redesign B, stage 3 (0.112 — Care, Your things, Templates, To do): the pieces those tabs share with the
// trip pages of 0.111 — a row of a grouped list with its chevron, Apple's segmented control in a part's
// colour, the search across the page, and the full-colour main button floating at the bottom right.

/// One row of a grouped inset list (`GroupedRows`): words at the left, a count, a chevron.
struct BRow: View {
    let title: String
    var detail: String? = nil
    var count: String? = nil
    var chevron = true
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(.body)).foregroundStyle(Theme.ink).lineLimit(1)
                if let detail, !detail.isEmpty {
                    Text(detail).font(.system(.footnote)).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let count {
                Text(count).font(.system(.body).monospacedDigit()).foregroundStyle(Theme.muted)
            }
            if chevron { BChevron() }
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .frame(minHeight: Metrics.row)
        .contentShape(Rectangle())
    }
}

/// The quiet › at the end of a row that opens a page.
struct BChevron: View {
    var body: some View {
        SVGPath.path("M9 6l6 6-6 6")
            .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
            .frame(width: 16, height: 16).foregroundStyle(Theme.muted.opacity(0.7))
            .accessibilityHidden(true)
    }
}

/// Apple's segmented control in this app's hand (as the trip's steps, 0.111): a grey track, the chosen
/// one filled in the part's colour with white words. Each option keeps the name the tests know it by.
struct BSegmented: View {
    let options: [(key: String, title: String, id: String)]
    let chosen: String
    let tint: Color
    let pick: (String) -> Void
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.key) { option in
                let on = option.key == chosen
                Button { pick(option.key) } label: {
                    Text(option.title)
                        .font(.system(.footnote, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(on ? Color.white : Theme.ink.opacity(0.75))
                        .frame(maxWidth: .infinity, minHeight: Metrics.loopPill - 4)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 7).fill(tint)
                                    .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier(option.id)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.line.opacity(scheme == .dark ? 0.9 : 0.6)))
    }
}

/// The search across the page (B, as on Home): a tap opens the search.
struct BSearchField: View {
    let prompt: String
    let id: String
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 6) {
                SVGPath.path("M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14ZM20 20l-4-4")
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .onGrid(Metrics.glyph)
                    .accessibilityHidden(true)
                Text(prompt).font(.system(.body))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: Metrics.tap)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.line.opacity(0.7)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityLabel(prompt)
    }
}

/// The page's main button, full colour, floating at the bottom right (B: "＋ New thing", "＋ New template").
struct BFloatingButton: View {
    let title: String
    let tint: Color
    let id: String
    let act: () -> Void
    var body: some View {
        Button(action: act) {
            HStack(spacing: 6) {
                SVGPath.path("M12 5v14M5 12h14")
                    .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .onGrid(Metrics.glyph * 0.85)
                    .accessibilityHidden(true)
                Text(title).font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16).frame(minHeight: Metrics.tap + 8)
            .background(Capsule().fill(tint))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityLabel(title)
        .padding(.trailing, 16).padding(.bottom, 12)
    }
}

/// A part's heading over its grouped card: its words in the part's colour, a count beside them.
struct BPartTitle: View {
    let title: String
    var count: Int? = nil
    let tint: Color
    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.headline).foregroundStyle(tint)
            if let count { Text("\(count)").font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted) }
        }
        .padding(.top, 10).padding(.bottom, 2).padding(.leading, 4)
    }
}

extension View {
    /// Rows in one rounded card of a grouped list (B): the card's corners clip the last row's hairline.
    func bCard() -> some View {
        self
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1).allowsHitTesting(false))
    }
}
