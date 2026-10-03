import SwiftUI

/// The sizes that make a heading lead its block — his and Anna's field test (3 Oct
/// 2026, the thing and row editors): "adjust the headings so that they are dominant,
/// and the other buttons and pills are much smaller than the heading … throughout
/// the app". So: a block's heading 22 heavy, a heading inside a block 20 heavy, a
/// question inside a block 17 heavy — and the pills under them 15, lighter, closer
/// together (`Pills`). Nothing under 15, so it still reads without glasses.
enum HeadingSize {
    static let band: CGFloat = 22
    static let title: CGFloat = 20
    static let question: CGFloat = 17
}

/// A heading as a band in its own colour — his sketch (2026-09-27): "make the
/// headings pop and make it more visually pleasing". A soft strip of the colour
/// across the full width, a solid mark at its start, the words in the colour.
struct HeadingBand: View {
    let title: String
    var tint: Color = AppSection.care.color
    var id: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Capsule().fill(tint).frame(width: 5, height: 26)
            label
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.13)))
    }

    @ViewBuilder private var label: some View {
        let text = Text(title).font(.system(size: HeadingSize.band, weight: .heavy)).foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)      // a long one wraps, never cut
        if let id { text.accessibilityIdentifier(id) } else { text }
    }
}

/// A heading inside a block that already has one — a group of pills on Create new
/// trip, Trip settings, Only on some trips. The band's mark and colour without its
/// strip, a size down; still well above the pills under it.
struct HeadingTitle: View {
    let title: String
    var tint: Color = Theme.ink
    var id: String? = nil
    /// A question asked inside a block (Laundry nights, Context, the review): smaller
    /// again, in the words' own colour.
    var question = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if !question {
                Capsule().fill(tint).frame(width: 4, height: 18).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
            }
            label
        }
    }

    @ViewBuilder private var label: some View {
        let text = Text(title)
            .font(.system(size: question ? HeadingSize.question : HeadingSize.title, weight: .heavy))
            .foregroundStyle(question ? Theme.ink : tint)
            .fixedSize(horizontal: false, vertical: true)
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

