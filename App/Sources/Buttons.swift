import SwiftUI

// His words (test H.10, 2026-09-28): "make the Done and Share buttons visually
// pleasing all over the app". Until 0.40 they were bare coloured words in the
// corner of every sheet. Now each is a button you can see is a button: the one
// that finishes (Done, Save) is filled with the screen's colour, the others
// (Cancel, Share, Edit, Close) are outlined in it. Never grey — his rule for
// buttons.

struct HeaderButtonStyle: ButtonStyle {
    var tint: Color
    var filled = true
    /// Share the width of a card's row (Keep it · Take it off) instead of hugging the word.
    var stretch = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(filled ? Color.white : tint)
            .lineLimit(1)
            .fixedSize()                    // a button's word is never cut ("D…", 0.40's photos)
            .frame(maxWidth: stretch ? .infinity : nil)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(filled ? tint : tint.opacity(0.10)))
            .overlay(Capsule().stroke(tint, lineWidth: filled ? 0 : 1.4))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// The wide outlined button at the foot of a trip (Save as Excel, Share): a
/// drawn mark and a word, framed in the screen's colour.
struct WideButtonLabel<Mark: View>: View {
    let title: String
    let tint: Color
    @ViewBuilder var mark: () -> Mark

    var body: some View {
        HStack(spacing: 10) {
            mark().frame(width: 22, height: 22)
            Text(title).font(.system(size: 17, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1.4))
        .contentShape(Rectangle())
    }
}

/// A pen, drawn — for changing a trip. His words (tests C.3 and D.1): the gear
/// "should be a pen or something like that".
struct PenMark: View {
    var body: some View {
        SVGPath.path("M15.2 5.3L18.7 8.8L8.6 18.9L4.3 19.7L5.1 15.4ZM13 7.5L16.5 11M5.1 15.4L8.6 18.9")
            .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}

/// A box with an arrow going up out of it, drawn — for Share.
struct ShareMark: View {
    var body: some View {
        SVGPath.path("M12 15V4.5M8 8.5l4-4 4 4M6.5 11.5H5.5v8h13v-8h-1")
            .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}
