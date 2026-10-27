import SwiftUI
import PackingLibrary

// Keyboard shortcuts in How it works (0.103) — his ask of 27 Oct 2026: "make the list visually pleasing
// and easy to read for a human."
//
// A line at the top, then one card for each kind of key (`KeyGuide.cards`, written from the code in
// Core/Sources/PackingLibrary/KeyGuide.swift): the action on the left, the keys on the right drawn as small
// key caps (⌘ S, Esc, ⌘ 1). Apple's text styles, the app's tokens (day and night), the iPhone and the Mac.
// VoiceOver reads a row as one thing — "Save, or Done", "Command S" — never the symbols.
//
// Ids: `guide-keys` (the heading card, with `guide-keys-title`), `guide-keys-card-<n>` (a card, n = its place),
// `guide-keys-<n>-<m>` (a row: its label the action, its value the keys in words).

/// One key, drawn as a key cap: a rounded face, a firmer edge under it, the key's name in ink.
struct KeyCap: View {
    let key: KeyGuide.Key

    var body: some View {
        Text(key.cap)
            .font(.system(.callout, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .lineLimit(1).fixedSize()
            .padding(.horizontal, 7)
            .frame(minWidth: Metrics.compact, minHeight: Metrics.compact)
            .background {
                ZStack {
                    // The edge a key stands on, a hair below its face.
                    RoundedRectangle(cornerRadius: 7).fill(Theme.faint.opacity(0.55)).offset(y: 2)
                    RoundedRectangle(cornerRadius: 7).fill(Theme.bg)
                    RoundedRectangle(cornerRadius: 7).stroke(Theme.faint.opacity(0.55), lineWidth: 1)
                }
            }
            .padding(.bottom, 2)
    }
}

/// The keys of a row: each way to press them, caps side by side, "or" between two ways.
private struct KeyChords: View {
    let chords: [KeyGuide.Chord]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(chords.enumerated()), id: \.offset) { n, chord in
                if n > 0 {
                    Text("or").font(.system(.footnote)).foregroundStyle(Theme.muted)
                }
                HStack(spacing: 3) {
                    ForEach(Array(chord.keys.enumerated()), id: \.offset) { _, key in KeyCap(key: key) }
                }
            }
        }
        .fixedSize()
    }
}

/// One row: the action (and its note) on the left, the keys on the right; at the largest text sizes the
/// keys go under the action instead.
private struct KeyRow: View {
    let row: KeyGuide.Row
    let id: String
    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        let words = VStack(alignment: .leading, spacing: 2) {
            Text(row.action).font(.system(.callout)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let note = row.note {
                Text(note).font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        Group {
            if size.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { words; KeyChords(chords: row.chords) }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    words
                    Spacer(minLength: 8)
                    KeyChords(chords: row.chords)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.action)
        .accessibilityValue(row.spoken)
        .accessibilityHint(row.note ?? "")
        .accessibilityIdentifier(id)
    }
}

/// The topic: the heading card with the line at the top, then a card for each kind of key.
struct KeysGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "command")
                        .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.settings.color)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                    Text(KeyGuide.title).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("guide-keys-title")
                }
                Text(KeyGuide.intro).font(.system(.callout)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("guide-keys")
            .id(KeysGuide.scrollId)

            ForEach(Array(KeyGuide.cards.enumerated()), id: \.offset) { n, card in
                VStack(alignment: .leading, spacing: 0) {
                    Text(card.title).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(card.reach.words).font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .padding(.top, 1)
                    if let line = card.line {
                        Text(line).font(.system(.footnote)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(card.rows.enumerated()), id: \.offset) { m, row in
                            if m > 0 { Theme.line.frame(height: 1) }
                            KeyRow(row: row, id: "guide-keys-\(n)-\(m)")
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("guide-keys-card-\(n)")
            }
        }
    }

    /// Where Help ▸ Keyboard Shortcuts scrolls to.
    static let scrollId = "guide-keys-top"
}
