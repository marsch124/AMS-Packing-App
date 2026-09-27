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
