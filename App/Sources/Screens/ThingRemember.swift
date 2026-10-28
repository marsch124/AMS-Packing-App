import SwiftUI
import PackingCore
import PackingLibrary

// Reminders on things (0.101, spec 07 part 21 — his yes to the picture, 26 Oct 2026: "build it").
// Kept out of ThingEditor and TripScreen, as the kit part is: the page holds a `RememberDraft`,
// shows `ThingRememberPart` (since 0.104 two rows of the frame Before a trip, also here) and saves
// it in its Save — nothing is stored before Save, and Cancel leaves the thing as it was. The trip
// shows `RemindLeftMark` / `WithMark` in a line and `ThingRemindersUnder` below a ticked one.

/// "Remember" and "Also pack" (until 0.104 "Remember with it" and "Goes with") as the page holds them, until Save.
struct RememberDraft: Equatable {
    /// A bag or a template's reminder: neither block.
    var none = true
    var reminders: [ThingReminder] = []
    var with: [String] = []
    private var openedReminders: [ThingReminder] = []
    private var openedWith: [String] = []

    init() {}

    init(_ lib: Library, thingId: String) {
        guard let thing = lib.items.first(where: { $0.id == thingId }) else { return }
        none = Library.isReminder(thing) || lib.bags().contains { ($0.itemId ?? $0.id) == thingId }
        guard !none else { return }
        reminders = Library.thingReminders(thing)
        with = lib.companions(of: thingId).map(\.id)
        openedReminders = reminders
        openedWith = with
    }

    /// Written in the page's own Save — onto the thing as it is now, list by list (0.95's rule).
    func save(_ lib: inout Library, thingId: String) {
        guard !none else { return }
        lib.saveThingRemembers(id: thingId, openedReminders: openedReminders, reminders: reminders,
                               openedWith: openedWith, with: with)
    }
}

/// On a thing's page, inside Before a trip (0.104): A "Remember" (until 0.104 "Remember with it")
/// or B "Also pack" (until 0.104 "Goes with") — the controls of one row; the row's label is the frame's.
struct ThingRememberPart: View {
    enum Part { case remember, alsoPack }
    let part: Part
    let thingId: String
    @Binding var draft: RememberDraft
    /// His "When" steps, as the page's When list shows them.
    let steps: [(value: String, label: String)]
    @EnvironmentObject var model: LibraryModel
    @Environment(\.colorScheme) private var scheme

    /// The reminder open for changes, and what is typed over its words.
    @State private var open: String?
    @State private var words = ""
    @State private var wordsNeeds = ""
    /// The add row (0.104: shown only after "+ Add" — compact until then): a new reminder and its
    /// When ("" = the one it would get).
    @State private var adding = false
    @State private var newWords = ""
    @State private var newWhen = ""
    @State private var addNeeds = ""
    @State private var carried: ReorderDrag?
    @State private var heights: [String: CGFloat] = [:]
    /// The list of his things to add from is open, and what is typed in its Find — never saved
    /// (here, not in the draft: the page compares the draft to tell whether anything changed).
    @State private var picking = false
    @State private var query = ""

    private var tint: Color { AppSection.care.color }

    var body: some View {
        if draft.none {
            EmptyView()
        } else {
            switch part {
            case .remember: remember
            case .alsoPack: alsoPack
            }
        }
    }

    /// "+ Add" / "Close" — the row's quiet door, an outlined capsule in the page's orange.
    private func door(_ open: Bool, id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(open ? "Close" : "+ Add").font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, Metrics.cardSide).frame(minHeight: Metrics.chip)
                .overlay(Capsule().stroke(tint, lineWidth: 1.4))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }

    // MARK: - A · Remember

    /// Each reminder one line — its words · its When; a tap opens it. Then "+ Add", which opens the
    /// add row (the words, Add, the When).
    private var remember: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(draft.reminders.enumerated()), id: \.element.id) { n, r in
                row(r, n: n, count: draft.reminders.count)
            }
            if adding { foot }
            door(adding, id: "thing-remind-new") {
                adding.toggle(); newWords = ""; addNeeds = ""
            }
            .padding(.top, draft.reminders.isEmpty && !adding ? 0 : Metrics.cardGap)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thing-remember")
    }

    private func phase(_ id: String) -> (label: String, color: Color) {
        let p = phaseOrFallback(id)
        let label = steps.first { $0.value == id }?.label ?? p.label
        return (label, Color(hexString: readableHex(p.color, dark: scheme == .dark)))
    }

    @ViewBuilder private func row(_ r: ThingReminder, n: Int, count: Int) -> some View {
        let when = phase(r.when)
        VStack(alignment: .leading, spacing: Metrics.cardGap) {
            HStack(spacing: 2) {
                if count > 1 {
                    ReorderGrip(id: "thing-remind-\(n)-grip", label: "Move \(r.text)", key: r.id,
                                step: heights[r.id] ?? Metrics.line, drag: $carried,
                                canMove: { by in draft.reminders.indices.contains(n + by) },
                                move: { by in move(r.id, by) }, tint: tint)
                        .padding(.leading, -6)
                }
                Button {
                    if open == r.id { close() } else { open = r.id; words = r.text; wordsNeeds = "" }
                } label: {
                    // One line: its words · its When (sketch A's "Charge it · day before"), wrapping as words do.
                    (Text(r.text).foregroundStyle(Theme.ink)
                     + Text(" \u{00B7} ").foregroundStyle(Theme.muted)
                     + Text(when.label).fontWeight(.semibold).foregroundStyle(when.color))
                        .font(.system(.subheadline))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: Metrics.line, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("thing-remind-\(n)")
                .accessibilityValue(when.label)
            }
            .reorderStep(r.id, into: $heights)
            .reorderLift(carried, key: r.id, tint: tint)
            if open == r.id { panel(r, n: n, count: count) }
        }
    }

    /// The open reminder: its words, its When, up and down (Mac), Done — and Remove.
    private func panel(_ r: ThingReminder, n: Int, count: Int) -> some View {
        VStack(alignment: .leading, spacing: Metrics.cardGap) {
            TextField("The reminder", text: $words)
                .textFieldStyle(.plain)
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .padding(.horizontal, Metrics.cardSide).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .onSubmit { done(r) }
                .accessibilityIdentifier("thing-remind-name")
                .needsLine($wordsNeeds, typed: words, id: "thing-remind-name-needs")
            DropDown(title: "When", heading: .beside, options: steps, selected: r.when, id: "thing-remind-when",
                     tint: tint, other: true) { when in
                if let k = draft.reminders.firstIndex(where: { $0.id == r.id }) { draft.reminders[k].when = when }
            }
            HStack(spacing: Metrics.cardGap) {
                if ReorderArrows.shown {
                    arrow(up: true, enabled: n > 0, id: r.id)
                    arrow(up: false, enabled: n < count - 1, id: r.id)
                }
                Spacer()
                Button { done(r) } label: { FieldButtonLabel(title: "Done", tint: tint) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("thing-remind-done")
            }
            // Held until the page's Save, as all of it: Cancel brings it back, so no question first.
            SmallDeleteButton(title: "Remove reminder", id: "thing-remind-remove") {
                draft.reminders.removeAll { $0.id == r.id }
                close()
            }
        }
        .padding(.bottom, Metrics.cardGap)
    }

    private func arrow(up: Bool, enabled: Bool, id: String) -> some View {
        Button { if enabled { move(id, up ? -1 : 1) } } label: {
            SVGPath.path(up ? "M6 15l6-6 6 6" : "M6 9l6 6 6-6")
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .onGrid(Metrics.glyph)
                .foregroundStyle(enabled ? tint : Theme.line)
                .frame(width: Metrics.tap, height: Metrics.tap)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(enabled ? tint : Theme.line, lineWidth: 1.2))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(up ? "thing-remind-up" : "thing-remind-down")
        .accessibilityLabel(up ? "Move up" : "Move down")
    }

    private func move(_ id: String, _ by: Int) {
        guard let k = draft.reminders.firstIndex(where: { $0.id == id }), draft.reminders.indices.contains(k + by) else { return }
        draft.reminders.swapAt(k, k + by)
    }

    /// The add row: a new reminder's words and Add, then its When.
    private var foot: some View {
        let picked = !newWhen.isEmpty && steps.contains { $0.value == newWhen }
        let when = picked ? newWhen : Library.whenForNewThingReminder(draft.reminders)
        return VStack(alignment: .leading, spacing: Metrics.cardGap) {
            HStack(spacing: Metrics.cardGap) {
                TextField("Add a reminder", text: $newWords)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, Metrics.cardSide).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add(when) }
                    .accessibilityIdentifier("thing-remind-add-name")
                // Always in colour (his rule); pressed too early it says what is missing.
                Button { add(when) } label: { FieldButtonLabel(title: "Add", tint: tint) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("thing-remind-add")
            }
            .needsLine($addNeeds, typed: newWords, id: "thing-remind-add-needs")
            DropDown(title: "When", heading: .beside, options: steps, selected: when, id: "thing-remind-add-when",
                     tint: tint, other: true) { newWhen = $0 }
        }
        .padding(.top, draft.reminders.isEmpty ? 0 : Metrics.cardGap)
    }

    private func add(_ when: String) {
        if let problem = Library.thingReminderProblem(newWords, others: draft.reminders) { addNeeds = problem; return }
        draft.reminders.append(ThingReminder(text: jsTrim(newWords), when: when))
        newWords = ""
        #if os(iOS)
        // The keyboard goes down: the new line, and Save, are in sight (the CI simulator has no hardware keyboard).
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func done(_ r: ThingReminder) {
        if jsTrim(words) != r.text {
            if let problem = Library.thingReminderProblem(words, others: draft.reminders, except: r.id) {
                wordsNeeds = problem == "Type the reminder first." ? "A reminder needs words." : problem
                return
            }
            if let k = draft.reminders.firstIndex(where: { $0.id == r.id }) { draft.reminders[k].text = jsTrim(words) }
        }
        close()
    }

    private func close() { open = nil; words = ""; wordsNeeds = "" }

    // MARK: - B · Also pack

    /// Chips of the things packed with it, each with its ✕, and "+ Add" at the end of the same row;
    /// "+ Add" opens the list of his things under it.
    private var alsoPack: some View {
        let byId = Dictionary(model.library.items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let chosen = draft.with.compactMap { byId[$0] }
        return VStack(alignment: .leading, spacing: Metrics.cardGap) {
            FlowRow(spacing: Metrics.cardGap) {
                ForEach(Array(chosen.enumerated()), id: \.element.id) { n, other in chip(other, n: n) }
                door(picking, id: "thing-with-add") { picking.toggle(); query = "" }
            }
            if picking { picker }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thing-with")
    }

    /// A thing packed with it: its name and ✕ — side by side, never a button in a button.
    private func chip(_ other: Item, n: Int) -> some View {
        HStack(spacing: 2) {
            Text(other.name).font(.system(.subheadline, weight: .semibold)).foregroundStyle(tint).lineLimit(1)
                .accessibilityIdentifier("thing-with-\(n)")
            Button { draft.with.removeAll { $0 == other.id } } label: {
                ClearMark().frame(width: Metrics.mark, height: Metrics.mark).frame(width: Metrics.chip, height: Metrics.chip).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("thing-with-\(n)-remove")
            .accessibilityLabel("Take \(other.name) off Also pack")
        }
        .padding(.leading, Metrics.cardSide).padding(.trailing, Metrics.cardGap / 2)
        .frame(minHeight: Metrics.chip)
        .overlay(Capsule().stroke(tint, lineWidth: 1.2))
    }

    /// His things that can go with it, found by what is typed — the first eight shown.
    private var picker: some View {
        let q = normName(query)
        let fit = model.library.goesWithCandidates(thingId: thingId, chosen: draft.with)
            .filter { q.isEmpty || normName($0.name).contains(q) }
        let shown = Array(fit.prefix(8))
        return VStack(alignment: .leading, spacing: 0) {
            TextField("Find a thing", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .padding(.horizontal, Metrics.cardSide).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .padding(.bottom, Metrics.cardGap)
                .accessibilityIdentifier("thing-with-search")
            ForEach(Array(shown.enumerated()), id: \.element.id) { n, other in
                Button {
                    draft.with.append(other.id)
                    query = ""
                } label: {
                    HStack(spacing: Metrics.cardGap) {
                        Text(other.name).font(.system(.body)).foregroundStyle(Theme.ink).lineLimit(1)
                        Spacer(minLength: Metrics.cardGap)
                        Text("Add").font(.system(.footnote, weight: .semibold)).foregroundStyle(tint)
                    }
                    .frame(maxWidth: .infinity, minHeight: Metrics.compact, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                .accessibilityIdentifier("thing-with-pick-\(n)")
                .accessibilityLabel(other.name)
            }
            if fit.count > shown.count {
                Text("\(fit.count - shown.count) more \u{2014} type to find them")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted).padding(.top, Metrics.cardGap)
            } else if fit.isEmpty {
                Text(q.isEmpty ? "Nothing else to add." : "Nothing by that name.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted).padding(.top, Metrics.cardGap)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thing-with-picker")
    }
}

// MARK: - Before a trip (0.104)

/// Before a trip's fold, kept on this device for every thing (0.104 — "folded as C").
enum BeforeATripFold {
    static let key = "ams.thing.before.folded"
}

/// The frame "Before a trip" on a thing's page (0.104 — his mix of sketches A and C, 28 Oct 2026): a
/// card in the page's orange right after Name and Notes, its title line with the chevron that folds
/// it — folded, that ONE line says what is set (`BeforeATrip.summary`) — and under it the rows
/// (`BeforeATripRow`), a hairline between each two. Every room inside is the cards' shared tokens
/// (`Metrics.cardSide`, `cardInset`, `cardGap`, `cardLine`), the same as Before you go's on a trip.
struct BeforeATripFrame<Content: View>: View {
    @Binding var folded: Bool
    let summary: String
    @ViewBuilder let content: () -> Content
    /// The widest row label: every label takes it, so the controls start on one line.
    @State private var labels: CGFloat = 0

    private var tint: Color { AppSection.care.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
            if !folded {
                VStack(alignment: .leading, spacing: 0) { content() }
                    .environment(\.beforeLabelWidth, labels)
                    .onPreferenceChange(BeforeLabelWidth.self) { labels = $0 }
            }
        }
        .padding(.horizontal, Metrics.cardSide)
        .padding(.top, Metrics.cardGap)
        .padding(.bottom, folded ? Metrics.cardGap : Metrics.cardInset)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1.2))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thing-before-frame")
    }

    /// "Before a trip", folded the summary after it, and the chevron at the right (as Before you go's
    /// on a trip). A tap anywhere on the line folds or opens it. Not a button round its words: on the
    /// Mac a button folds its words into its own, and the summary is read on its own.
    private var title: some View {
        HStack(spacing: Metrics.cardGap * 2) {
            Text("Before a trip").font(.headline).foregroundStyle(tint)
                .lineLimit(1).fixedSize()
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("thing-before-title")
            if folded {
                Text(summary).font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .lineLimit(1).minimumScaleFactor(0.85).truncationMode(.tail)
                    .accessibilityIdentifier("thing-before-summary")
            }
            Spacer(minLength: 0)
            Button { fold() } label: {
                SVGPath.path(folded ? "M9 6l6 6-6 6" : "M6 9l6 6 6-6")
                    .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
                    .frame(width: Metrics.cardLine, height: Metrics.cardLine).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityLabel(folded ? "Show Before a trip" : "Fold Before a trip")
            .accessibilityValue(folded ? "folded" : "open")
            .accessibilityIdentifier("thing-before-fold")
        }
        .frame(minHeight: Metrics.cardLine)
        .contentShape(Rectangle())
        .onTapGesture { fold() }
    }

    private func fold() {
        withAnimation(.easeInOut(duration: 0.2)) { folded.toggle() }
    }
}

/// One row of Before a trip: a short label on the left (its id the old heading's, `thing-heading-…`),
/// the controls on the right; a hairline above every row but the first.
struct BeforeATripRow<Content: View>: View {
    let label: String
    let id: String
    var first = false
    @ViewBuilder let content: () -> Content
    @Environment(\.beforeLabelWidth) private var width

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.cardSide) {
            Text(label).font(.system(.subheadline)).foregroundStyle(Theme.ink)
                .lineLimit(1).fixedSize()
                .background(GeometryReader { g in Color.clear.preference(key: BeforeLabelWidth.self, value: g.size.width) })
                .frame(width: width > 0 ? width : nil, alignment: .leading)
                // Level with the first line of controls (a pill, a reminder's line).
                .frame(minHeight: Metrics.chip)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(id)
            VStack(alignment: .leading, spacing: Metrics.cardGap) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Metrics.cardGap)
        .overlay(alignment: .top) {
            if !first { Theme.line.frame(height: 1).accessibilityHidden(true) }
        }
    }
}

/// The widest label of Before a trip's rows.
struct BeforeLabelWidth: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

extension EnvironmentValues {
    @Entry var beforeLabelWidth: CGFloat = 0
}

/// A switch drawn as a pill (0.104, Before a trip — sketch A's "Liquid", "Charge before a trip"):
/// filled in the page's orange with white words when on, outlined when off — orange either way, never
/// grey. To VoiceOver and the UI tests it is still the switch it was (`accessibilityRepresentation`):
/// the same id on it, on or off as its value, its old words as its name.
struct ChipToggle: View {
    let title: String
    /// What VoiceOver says (the switch's words until 0.104), when the pill says it shorter.
    var spoken: String? = nil
    /// A drawn mark before the words (the battery's).
    var mark: String? = nil
    @Binding var isOn: Bool

    private var tint: Color { AppSection.care.color }

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: Metrics.cardGap) {
                if let mark {
                    IconMark(path: mark, size: 16).foregroundStyle(isOn ? Color.white : tint)
                        .accessibilityHidden(true)
                }
                Text(title).font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(isOn ? Color.white : tint).lineLimit(1)
            }
            .padding(.horizontal, Metrics.cardSide).frame(minHeight: Metrics.chip)
            .background(Capsule().fill(isOn ? tint : Color.clear))
            .overlay(Capsule().stroke(tint, lineWidth: 1.4))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityRepresentation { Toggle(spoken ?? title, isOn: $isOn) }
    }
}

// MARK: - On the trip

/// "1 left" after a line's name: its thing's reminders not ticked yet on this trip (orange, small).
struct RemindLeftMark: View {
    let left: Int
    let id: String

    var body: some View {
        Text("\(left) left")
            .font(.system(.caption, weight: .semibold).monospacedDigit())
            .foregroundStyle(AppSection.care.color)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 5).fill(AppSection.care.color.opacity(0.14)))
            .fixedSize()
            .accessibilityLabel("\(left) to remember")
            .accessibilityIdentifier(id)
    }
}

/// "with Camera" on a line that came along with another thing (violet, small).
struct WithMark: View {
    let names: [String]
    let id: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let violet = ThingDetailLine.violet(scheme)
        Text("with \(names.joined(separator: ", "))")
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(violet)
            .lineLimit(1)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 5).fill(violet.opacity(0.13)))
            .fixedSize()
            .accessibilityIdentifier(id)
    }
}

/// Under a ticked line: its thing's reminders still open — "Before it goes: Empty the SD card" —
/// each with its own tick. One ticked here stays a moment, struck through, then goes. The tick is
/// the trip's ONE tick for it (Before you go's To do shows the same).
struct ThingRemindersUnder: View {
    let tripId: String
    let rows: [ThingReminderOnTrip]
    /// The line's number on the trip (`trip-line-<n>`).
    let n: Int
    @EnvironmentObject var model: LibraryModel
    /// Ticked here just now: shown struck through for a moment.
    @State private var going: Set<String> = []

    var body: some View {
        let shown = rows.filter { !$0.done || going.contains($0.reminder.id) }
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { k, r in
                    Button { toggle(r) } label: {
                        HStack(spacing: 8) {
                            TickCircle(on: r.done, tint: AppSection.care.color)
                                .frame(width: Metrics.mark, height: Metrics.mark)
                            (Text("Before it goes: ").foregroundStyle(r.done ? Theme.muted : AppSection.care.color).fontWeight(.semibold)
                             + Text(r.reminder.text).foregroundStyle(r.done ? Theme.muted : Theme.ink))
                                .font(.system(.subheadline))
                                .strikethrough(r.done, color: Theme.muted)
                                .lineLimit(2)
                            Spacer(minLength: 4)
                        }
                        .padding(.vertical, 2).frame(minHeight: Metrics.line).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("trip-line-\(n)-remind-\(k)")
                    .accessibilityLabel("Before it goes: \(r.reminder.text)")
                    .accessibilityAddTraits(r.done ? .isSelected : [])
                }
            }
            .padding(.leading, Metrics.mark + 8)
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("trip-line-\(n)-remind")
        }
    }

    private func toggle(_ r: ThingReminderOnTrip) {
        let on = !r.done
        model.change { _ = $0.setThingReminderDone(on, tripId: tripId, lineId: r.lineId, reminderId: r.reminder.id) }
        guard on else { going.remove(r.reminder.id); return }
        going.insert(r.reminder.id)
        let id = r.reminder.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.25)) { _ = going.remove(id) }
        }
    }
}
