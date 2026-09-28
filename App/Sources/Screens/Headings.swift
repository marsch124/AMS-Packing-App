import SwiftUI

/// A heading as a band in its own colour — his sketch (2026-09-27): "make the
/// headings pop and make it more visually pleasing". A soft strip of the colour
/// across the full width, a solid mark at its start, the words in the colour.
struct HeadingBand: View {
    let title: String
    var tint: Color = AppSection.care.color
    var id: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Capsule().fill(tint).frame(width: 4, height: 22)
            label
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.13)))
    }

    @ViewBuilder private var label: some View {
        let text = Text(title).font(.system(size: 19, weight: .heavy)).foregroundStyle(tint)
        if let id { text.accessibilityIdentifier(id) } else { text }
    }
}

/// A heading that starts a part of a screen — in CAPITALS, larger, in full-strength
/// words, with room above it. His words (2026-09-28): the Care headings were grey
/// and row-sized, so "The heavy end" read like one more row — "should be larger or
/// in capitals, as should all headings on the Care tab"; and on the templates:
/// "Much larger headings, please" (test H.13).
struct SectionTitle: View {
    let title: String
    var tint: Color = Theme.ink
    var id: String? = nil

    var body: some View {
        let text = Text(title.uppercased())
            .font(.system(size: 18, weight: .heavy))
            .kerning(0.8)
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 16)
        if let id { text.accessibilityIdentifier(id) } else { text }
    }
}

