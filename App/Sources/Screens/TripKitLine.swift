import SwiftUI
import PackingCore
import PackingLibrary

// A kit on a trip (spec 07, part 9; spec 03, "A kit's line"): ONE line — "Camp pouch
// · 3 inside" — with a fold arrow beside its ⊘ that shows what is inside, muted and not
// ticked; with Check before each trip, small ticks instead (open until the kit is
// packed), and the kit counts as packed only when every one is ticked. Under the line,
// always: "1 missing: Lighter" while something is taken out, and what is worth saying
// about what is inside ("Plasters runs out in 10 days").

/// The arrow beside a kit's ⊘ that opens what is inside it.
struct KitFoldButton: View {
    let open: Bool
    let name: String
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SVGPath.path("M9 6l6 6-6 6")
                .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .onGrid(Metrics.glyph)
                .rotationEffect(.degrees(open ? 90 : 0))
                .foregroundStyle(Theme.muted)
                .frame(width: Metrics.lineButton - 10, height: Metrics.line).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityLabel(open ? "Fold what is in \(name)" : "Show what is in \(name)")
        .accessibilityValue(open ? "open" : "folded")
    }
}

/// What shows under a kit's line.
struct KitLineParts: View {
    let kit: KitOnLine
    let line: Item
    /// The line's number on the trip (`trip-line-N`).
    let n: Int
    let open: Bool
    /// What is worth saying about what is inside, for this trip.
    let warnings: [String]
    let tint: Color
    /// A thing inside ticked or unticked (Check before each trip).
    let tick: (String, Bool) -> Void
    /// A thing inside taken out, or put back.
    let takeOut: (String, Bool) -> Void

    var body: some View {
        let aside = isSetAside(line)
        VStack(alignment: .leading, spacing: 2) {
            if !kit.missingWords.isEmpty {
                Text(kit.missingWords)
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("trip-line-\(n)-kit-missing")
            }
            if !aside && !line.checked && !kit.toTickWords.isEmpty {
                Text(kit.toTickWords)
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.events.color)
                    .accessibilityIdentifier("trip-line-\(n)-kit-togo")
            }
            ForEach(Array(warnings.enumerated()), id: \.offset) { k, words in
                Text(words)
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("trip-line-\(n)-kit-warning-\(k)")
            }
            if open {
                ForEach(Array(kit.contents.enumerated()), id: \.element.thing.id) { k, c in
                    content(c, k: k, aside: aside)
                }
            }
        }
        // Set in under the name, past the tick circle.
        .padding(.leading, Metrics.mark + 8)
        .padding(.bottom, open || !kit.missingWords.isEmpty || !warnings.isEmpty ? 4 : 0)
    }

    /// One thing inside: its name, muted — with a small tick when the kit is checked
    /// before each trip — and Take out / Put back.
    private func content(_ c: KitContent, k: Int, aside: Bool) -> some View {
        let ticked = kit.ticked.contains(c.thing.id)
        let ticks = kit.check && !c.takenOut && !aside
        return HStack(spacing: 6) {
            if ticks {
                Button { tick(c.thing.id, !ticked) } label: {
                    HStack(spacing: 6) {
                        TickCircle(on: ticked, tint: tint)
                            .scaleEffect(0.8)
                        Text(c.thing.name).font(.system(.subheadline))
                            .foregroundStyle(ticked ? Theme.muted : Theme.ink).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: Metrics.line - 4, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("trip-line-\(n)-kit-\(k)-tick")
                .accessibilityLabel(c.thing.name)
                .accessibilityAddTraits(ticked ? .isSelected : [])
            } else {
                Text(c.thing.name)
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .strikethrough(c.takenOut, color: Theme.muted)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: Metrics.line - 4, alignment: .leading)
            }
            Button { takeOut(c.thing.id, !c.takenOut) } label: {
                Text(c.takenOut ? "Put back" : "Take out").font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(AppSection.events.color)
                    .padding(.horizontal, 8).frame(minHeight: Metrics.chip - 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("trip-line-\(n)-kit-\(k)-out")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trip-line-\(n)-kit-\(k)")
        .accessibilityValue(c.takenOut ? "taken out" : (ticked ? "ticked" : ""))
    }
}
