import SwiftUI
import PackingCore
import PackingLibrary

/// "Only on some trips" — Season, Context, Transport and Food as rows of pills, on a
/// thing's page and on a template's row (spec 07 part 14; his words, 10 Oct 2026: "if I
/// have an item on five templates, I need to change this in five places").
///
/// On a template's row (`thing` given) each kind also says where its answer comes from.
/// While it follows the thing, its lit pills are drawn BORROWED (a violet wash and outline,
/// ink words — not filled) and the line under them says "Same as the thing: Winter"; a tap
/// on any pill makes the kind this template's own, starting from what was shown, and then
/// "Same as the thing" puts the thing's answer back. A kind whose pills come back to exactly
/// the thing's answer IS the same as the thing again (rule 4: undoing a tap goes back).
/// What is held here is stored only on Save (`Library.saveRow`, `Library.setThingLimits`).
struct OnlySomeTripsPills: View {
    /// "row" or "thing": the pills are `<id>-<kind>-<n>` (`row-seasons-1`), never words.
    let id: String
    @Binding var picks: TripLimits
    /// What is stored now — its words the app does not know are pills of their own.
    let stored: TripLimits
    /// Context narrows workout templates only (`contextApplies`).
    let showContext: Bool
    /// The thing's own answers, on a template's row; nil on the thing's page.
    var thing: TripLimits? = nil
    var tint: Color = AppSection.templates.color
    /// The thing's page on the Mac (0.75): the pill each kind's arrows are on — ringed, as On
    /// these templates rings its own (nil = none) — and a click, which puts the page's focus
    /// on that kind and the arrows on that pill. Each kind is a field of the page's Tab order
    /// (`ThingField.limit`), scrolled to by its key. Unused on a template's row.
    var cursor: (TripLimit) -> Int? = { _ in nil }
    var clicked: ((TripLimit, Int) -> Void)? = nil

    private var kinds: [TripLimit] { OnlySomeTripsPills.kinds(showContext: showContext) }

    var body: some View {
        ForEach(kinds, id: \.self) { k in
            let options = OnlySomeTripsPills.options(k, stored: stored, thing: thing)
            VStack(alignment: .leading, spacing: 6) {
                Pills(title: k.title, options: options, selected: Set(picks[k]), id: "\(id)-\(k.rawValue)",
                      tint: tint, cursor: cursor(k), borrowed: follows(k)) { word in
                    OnlySomeTripsPills.toggle(&picks, k, word)
                    if let clicked, let n = options.firstIndex(where: { $0.id == word }) { clicked(k, n) }
                }
                if let thing { from(k, thing: thing[k]) }
            }
            .keyed(.limit(k))
        }
    }

    /// The kinds shown, in their order: Context only where it counts (a workout template).
    static func kinds(showContext: Bool) -> [TripLimit] {
        TripLimit.allCases.filter { $0 != .contexts || showContext }
    }

    /// The app's words (food in its short words), then any stored word it does not know —
    /// the pills of one kind, in their order (the Mac's arrows walk the same list).
    static func options(_ k: TripLimit, stored: TripLimits, thing: TripLimits?) -> [(id: String, label: String)] {
        let known = k.vocabulary.map { (id: $0, label: TripLimit.label($0)) }
        let odd = Library.unknownConditions(stored[k] + (thing?[k] ?? []), k.vocabulary).map { (id: $0, label: $0) }
        return known + odd
    }

    /// A pill pressed — or Space on the one the Mac's arrows are on: on if it was off, off if on.
    static func toggle(_ picks: inout TripLimits, _ k: TripLimit, _ word: String) {
        if picks[k].contains(word) { picks[k].removeAll { $0 == word } } else { picks[k].append(word) }
    }

    /// On a template's row: is this kind the thing's answer right now?
    private func follows(_ k: TripLimit) -> Bool {
        guard let thing else { return false }
        return Library.sameLimit(picks[k], thing[k])
    }

    /// Where the answer comes from, and the way back to the thing's.
    @ViewBuilder private func from(_ k: TripLimit, thing own: [String]) -> some View {
        let same = Library.sameLimit(picks[k], own)
        VStack(alignment: .leading, spacing: 6) {
            Text(Library.limitFromWords(k, shown: picks[k], thing: own))
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(id)-\(k.rawValue)-from")
            if !same {
                Button { picks[k] = own } label: {
                    Text("Same as the thing").font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                        .overlay(Capsule().stroke(tint, lineWidth: 1.2))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("\(id)-\(k.rawValue)-same")
            }
        }
    }
}
