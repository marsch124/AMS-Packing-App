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

/// An ✕ at the end of a search field — his and Anna's field test (3 Oct 2026): "When
/// typing in the search field, please add an X so that it's quick to delete all typed
/// alphanumeric characters." It is there only while there is something to clear; one
/// tap empties the field and the keyboard stays, ready for the next word.
///
/// ONE modifier for every search field, so they all behave alike. It also names the
/// field (`id`) and its ✕ (`id-clear`): an id put on the whole row afterwards would
/// reach the ✕ as well, so the field is named here, on the field itself.
struct ClearButton: ViewModifier {
    @Binding var text: String
    let id: String

    func body(content: Content) -> some View {
        HStack(spacing: 4) {
            content.accessibilityIdentifier(id)
            if !text.isEmpty {
                Button { text = "" } label: {
                    ClearMark().frame(width: 24, height: 24)
                        .frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .padding(.trailing, -6)
                .accessibilityIdentifier("\(id)-clear")
                .accessibilityLabel("Clear the search")
            }
        }
    }
}

extension View {
    /// The ✕ that empties a search field (see `ClearButton`).
    func clearButton(_ text: Binding<String>, id: String) -> some View {
        modifier(ClearButton(text: text, id: id))
    }
}

/// A round ✕, drawn: a soft disc with the cross cut out of it.
struct ClearMark: View {
    var body: some View {
        ZStack {
            Circle().fill(Theme.muted)
            SVGPath.path("M8.5 8.5L15.5 15.5M15.5 8.5L8.5 15.5")
                .stroke(Theme.card, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}
