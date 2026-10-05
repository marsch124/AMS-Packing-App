import SwiftUI

/// Headings use Apple's text styles — his word (5 Oct 2026): "efficient, fluid, and
/// Apple-standard". A block's heading is a Headline in its colour; a heading inside
/// a block a Subheadline; a question inside a block the same, in the words' colour.

/// A heading that opens a block (Name, Notes, Kept at home …), in the block's colour.
struct HeadingBand: View {
    let title: String
    var tint: Color = AppSection.care.color
    var id: String? = nil

    var body: some View {
        let text = Text(title).font(.headline).foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)      // a long one wraps, never cut
            .frame(maxWidth: .infinity, alignment: .leading)
        if let id { text.accessibilityIdentifier(id) } else { text }
    }
}

/// A heading inside a block that already has one — a group of pills on Create new
/// trip, Trip settings, Only on some trips.
struct HeadingTitle: View {
    let title: String
    var tint: Color = Theme.ink
    var id: String? = nil
    /// A question asked inside a block (Laundry nights, Context, the review): in the
    /// words' own colour.
    var question = false

    var body: some View {
        let text = Text(title)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(question ? Theme.ink : tint)
            .fixedSize(horizontal: false, vertical: true)
        if let id { text.accessibilityIdentifier(id) } else { text }
    }
}

/// A heading that starts a part of a screen (the Care parts, a template's sections).
struct SectionTitle: View {
    let title: String
    var tint: Color = Theme.ink
    var id: String? = nil

    var body: some View {
        let text = Text(title)
            .font(.headline)
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
        if let id { text.accessibilityIdentifier(id) } else { text }
    }
}
