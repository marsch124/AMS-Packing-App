import SwiftUI
import PackingCore
import PackingLibrary

/// One bag's own page — his asks (2026-09-26): rename a bag, delete a bag, and "see
/// or get more information about the bags". His choices: a rename reaches every
/// trip; a delete first moves the bag's things to a bag he picks; the page shows
/// everything — its numbers, the things usually in it, its trips, and its details
/// as a thing.
///
/// Duplicate (0.90, his ask of 19 Oct 2026 — "if I buy four of the same and just want to change
/// colour and name"): the page turns to the copy at once, its name selected for typing. So the
/// sheet holds the bag SHOWN, and each bag gets a fresh page (`.id`): nothing typed on the
/// original's page — its fields, the delete question — follows onto the copy's.
struct BagDetail: View {
    let bagId: String
    @EnvironmentObject var model: LibraryModel
    @State private var shown: String
    /// The copy just made: its page opens with the name selected.
    @State private var copied: String?

    init(bagId: String) {
        self.bagId = bagId
        _shown = State(initialValue: bagId)
    }

    var body: some View {
        BagPage(bagId: shown, selectName: copied == shown) { copy in
            copied = copy
            shown = copy
        }
        .environmentObject(model)
        .id(shown)
    }

    /// "Travel", "Travel and Swim", "Travel, Swim and Run" (`BagPage.names`).
    static func names(_ lists: [String]) -> String { BagPage.names(lists) }
}

/// The page of one bag (`BagDetail` holds which).
struct BagPage: View {
    let bagId: String
    /// Open with the name selected, ready to be typed over (a copy just made).
    var selectName = false
    /// Duplicate made this copy: the sheet turns to it.
    var duplicated: (String) -> Void = { _ in }
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: String?
    /// The name's selection, and whether it has the keys — for a copy just made (0.90).
    @State private var nameSelection: TextSelection?
    @FocusState private var naming: Bool
    /// Its Notes (0.90) — the thing's own `note` — as typed, written a moment after the last key
    /// (`noteWrite`) and at once on Done, Duplicate, Its details or leaving the page.
    @State private var note = ""
    @State private var noteWrite: Task<Void, Never>?
    @State private var problem = ""
    @State private var maxKg = ""
    @State private var litres = ""
    @State private var empty = ""
    @State private var allThings = false
    @State private var askingToDelete = false
    /// Where the bag's things go on a delete: nil = not chosen yet, "" = no bag.
    @State private var moveTo: String?
    /// What Delete was missing when pressed too early, said under it.
    @State private var deleteNeeds = ""
    @State private var opened: Opened?
    /// For the lost-luggage desk (0.80): what is typed in its four fields, written a moment
    /// after the last key (`lostWrite`) and at once on Return, a pill, the details door or
    /// leaving the page.
    @State private var lost = LostTyped()
    @State private var lostWrite: Task<Void, Never>?

    struct LostTyped: Equatable { var brand = "", colour = "", sizeNote = "", marks = "" }

    /// One sheet, several destinations (the Search lesson: several sheets on one view).
    enum Opened: Identifiable {
        case thing(String)
        var id: String { switch self { case .thing(let id): return id } }
    }

    var body: some View {
        let bag = model.library.bags().first { $0.id == bagId }
        VStack(spacing: 0) {
            if let bag {
                let facts = model.library.bagFacts(name: bag.name)
                header(bag)
                KeyboardAwayScroll {
                    VStack(alignment: .leading, spacing: 12) {
                        // Notes right under the name (0.90, his ask with an arrow at that spot) — the
                        // bag's thing's own Notes, as a thing's page has them under its name.
                        notes(bag)
                        numbers(bag)
                        cabinSwitch(bag)
                        airTagSwitch(bag)
                        // For the lost-luggage desk (0.80, spec 07 part 18 A): said once, every trip uses it.
                        lostDesk(bag)
                        // Its pockets (0.69): named once, offered when a thing is ticked.
                        BagPockets(bagId: bag.id).environmentObject(model)
                        thingsInIt(facts)
                        trips(facts)
                        detailsDoor(bag)
                        // Duplicate (0.90): near the end, calm — the copy opens at once.
                        duplicateBag(bag)
                        deleteBag(bag, facts)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 24)
                }
            } else {
                // Deleted (or never there): nothing to show — close.
                Color.clear.onAppear { dismiss() }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $opened) { o in
            switch o {
            case .thing(let id): ThingEditor(itemId: id).environmentObject(model)
            }
        }
        .onAppear {
            guard let bag else { return }
            maxKg = bag.maxKg > 0 ? BagsScreen.show(bag.maxKg) : ""
            litres = bag.capacityL > 0 ? BagsScreen.show(bag.capacityL) : ""
            empty = bag.weight > 0 ? String(Int(bag.weight.rounded())) : ""
            loadLost(model.library.bagDetails(id: bag.id) ?? BagDetails())
            note = storedNote ?? ""
            if selectName { selectTheName(bag.name) }
        }
        // Notes changed elsewhere (Its details, the other device) reach the field — unless what is
        // typed already says it, or is still on its way to being written.
        .onChange(of: storedNote) { _, kept in
            guard let kept, noteWrite == nil, jsTrim(note) != kept else { return }
            note = kept
        }
        .onChange(of: note) { _, _ in noteTyped() }
        // A change from the other device, or from "Its details", reaches the fields — unless
        // what is typed already says it, or is still on its way to being written.
        .onChange(of: model.library.bagDetails(id: bagId)) { _, kept in
            guard let kept, lostWrite == nil else { return }
            followLost(kept)
        }
        .onDisappear { writeLost(); writeNote() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bag-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    // MARK: The name

    private func header(_ bag: Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                // The name is the field — press it, type, Rename.
                TextField("", text: Binding(get: { renaming ?? bag.name }, set: { renaming = $0; problem = "" }),
                          selection: $nameSelection)
                    .textFieldStyle(.plain)
                    .focused($naming)
                    .font(.system(.title3, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .onSubmit { rename(bag) }
                    .accessibilityIdentifier("bag-name")
                if let wanted = renaming, jsTrim(wanted) != bag.name {
                    Button { rename(bag) } label: {
                        Text("Rename").font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: 34)
                            .background(Capsule().fill(AppSection.care.color))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("bag-rename")
                }
                Spacer(minLength: 4)
                // Done takes a name typed and not yet renamed (0.90: a copy is named and closed in
                // one go); a name refused keeps the page open and says why.
                Button("Done") { leave(bag) }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    .keyboardShortcut(.cancelAction)            // Escape closes it, as Done does (Escape everywhere, 5 Oct 2026)
                    .accessibilityIdentifier("bag-done")
            }
            if !problem.isEmpty {
                Text(problem).font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .accessibilityIdentifier("bag-problem")
            }
        }
        .padding(16)
    }

    @discardableResult private func rename(_ bag: Item) -> Bool {
        guard let wanted = renaming else { return true }
        guard jsTrim(wanted) != bag.name else { renaming = nil; return true }
        var ok = false
        model.change { ok = $0.renameThing(id: bag.id, to: wanted) }
        if ok { renaming = nil; problem = "" }
        else { problem = jsTrim(wanted).isEmpty ? "A bag needs a name." : "You already have something called that." }
        return ok
    }

    /// Done: what is typed is kept first — a new name too — then the page closes.
    private func leave(_ bag: Item) {
        guard rename(bag) else { return }
        writeLost()
        writeNote()
        dismiss()
    }

    /// The copy's name, selected and holding the keys, so what he types replaces it — once the
    /// sheet has come up (a field focused while it is still sliding in is not given the keys).
    private func selectTheName(_ name: String) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            naming = true
            try? await Task.sleep(for: .milliseconds(100))
            nameSelection = TextSelection(range: name.startIndex..<name.endIndex)
        }
    }

    // MARK: Notes (0.90) — the bag's thing's own

    private var storedNote: String? { model.library.items.first { $0.id == bagId }?.note }

    private func notes(_ bag: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NOTES").font(.system(.caption2, weight: .semibold)).kerning(0.4).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("bag-detail-notes-label")
            TextField("Anything worth remembering", text: $note, axis: .vertical)
                .lineLimit(1...8)
                .textFieldStyle(.plain)
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).padding(.vertical, 9).frame(minHeight: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                .accessibilityIdentifier("bag-detail-notes")
            // The notes its templates keep for it, as under a thing's Notes (a bag he also packs).
            ForEach(Array(model.library.rowNotes(itemId: bag.id).enumerated()), id: \.offset) { n, said in
                Text("Note on the \(said.template) template: \(said.note)")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bag-row-note-\(n)")
            }
        }
    }

    /// A key typed: written 0.4 s after the last one, as the lost-luggage fields are.
    private func noteTyped() {
        guard let kept = storedNote, jsTrim(note) != kept else { noteWrite?.cancel(); noteWrite = nil; return }
        noteWrite?.cancel()
        noteWrite = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            writeNote()
        }
    }

    private func writeNote() {
        noteWrite?.cancel()
        noteWrite = nil
        guard let kept = storedNote, jsTrim(note) != kept else { return }
        let id = bagId, words = note
        model.change { _ = $0.setThingNote(id: id, words) }
    }

    // MARK: Duplicate (0.90) — his ask of 19 Oct 2026

    /// "Duplicate this bag": a copy of everything that describes it — not its photos, its trips
    /// or what is in it (BagDuplicate.swift) — right after it on Your bags; its page opens at once,
    /// the name ("Duffel 2") selected for typing. Calm, outlined, like Start a new trip from this one.
    private func duplicateBag(_ bag: Item) -> some View {
        Button {
            rename(bag)
            writeLost()
            writeNote()
            var copy: Item?
            let id = bag.id
            model.change { copy = $0.duplicateBag(id: id) }
            if let copy { duplicated(copy.id) }
        } label: {
            VStack(spacing: 2) {
                Text("Duplicate this bag")
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.care.color)
                Text("Sizes, details and pockets \u{2014} not its photos or trips")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.care.color, lineWidth: 1.4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("bag-duplicate")
    }

    // MARK: Numbers — saved as typed (the 0.25 lesson)

    private func numbers(_ bag: Item) -> some View {
        HStack(spacing: 10) {
            number("Max kg", $maxKg, now: bag.maxKg, id: "bag-detail-maxkg") { v in
                model.change { _ = $0.setBag(id: bag.id, maxKg: v) }
            }
            number("Litres", $litres, now: bag.capacityL, id: "bag-detail-litres") { v in
                model.change { _ = $0.setBag(id: bag.id, capacityL: v) }
            }
            number("Empty g", $empty, now: bag.weight, id: "bag-detail-empty") { v in
                model.change { _ = $0.setBag(id: bag.id, emptyGrams: v) }
            }
        }
    }

    private func number(_ title: String, _ text: Binding<String>, now: Double, id: String,
                        commit: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.system(.caption2, weight: .semibold)).kerning(0.4).foregroundStyle(Theme.muted)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(.body, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                .onChange(of: text.wrappedValue) { _, typed in
                    let clean = jsTrim(typed).replacingOccurrences(of: ",", with: ".")
                    let value = clean.isEmpty ? 0 : (Double(clean) ?? now)
                    if value != now { commit(value) }
                }
                .accessibilityIdentifier(id)
        }
    }

    // MARK: The cabin — a plane trip checks this bag (his idea 4, 2 Oct 2026)

    private func cabinSwitch(_ bag: Item) -> some View {
        let thing = model.library.items.first { $0.id == bag.id } ?? bag
        return Toggle(isOn: Binding(get: { Library.isCabinBag(thing) },
                                    set: { on in model.change { _ = $0.setBagCabin(id: bag.id, on) } })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Goes in the cabin").font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("Carry-on. On a plane trip, the trip checks it for liquids and things not allowed on board.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(AppSection.care.color)
        .accessibilityIdentifier("bag-detail-cabin")
    }

    // MARK: Has an AirTag — the Packing day's Tags asks for it (0.79, spec 07 part 17)

    private func airTagSwitch(_ bag: Item) -> some View {
        let thing = model.library.items.first { $0.id == bag.id } ?? bag
        return Toggle(isOn: Binding(get: { Library.hasAirTag(thing) },
                                    set: { on in model.change { _ = $0.setBagAirTag(id: bag.id, on) } })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Has an AirTag").font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("In Packing Stations, Tags asks you to check it is in the bag.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(AppSection.care.color)
        .accessibilityIdentifier("bag-detail-airtag")
    }

    // MARK: For the lost-luggage desk (0.80, spec 07 part 18 A)

    /// What an airline's desk asks about a missing bag: brand, colour, type, size and what makes
    /// it stand out. Said once, here; every trip reads it (`Library.bagDetails(bag:)`). Brand and
    /// colour are the thing's own — "Its details" shows the same values.
    private func lostDesk(_ bag: Item) -> some View {
        let kept = model.library.bagDetails(id: bag.id) ?? BagDetails()
        let typedColour = BagDetails(colour: lost.colour)
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("For the lost-luggage desk").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("bag-lost-heading")
                Text("What an airline\u{2019}s desk asks when a bag goes missing. Said once, here \u{2014} every trip uses it.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            lostPart("Brand") {
                lostField($lost.brand, "e.g. Samsonite", id: "bag-detail-brand")
            }
            lostPart("Colour") {
                lostField($lost.colour, "e.g. Dark blue", id: "bag-detail-colour")
                FlowRow(spacing: 6) {
                    ForEach(BagDetails.colourPills) { pill in
                        let on = typedColour.lit(pill)
                        choice(pill.label, on: on, id: "bag-detail-colour-\(pill.label.lowercased())") {
                            lost.colour = on ? "" : pill.value
                            writeLost()
                        }
                    }
                }
            }
            lostPart("Type") {
                FlowRow(spacing: 6) {
                    ForEach(BagType.allCases) { type in
                        let on = kept.type == type
                        choice(type.name, on: on, id: "bag-detail-type-\(type.rawValue)") { writeLost { $0.type = on ? nil : type } }
                    }
                }
            }
            lostPart("Size") {
                FlowRow(spacing: 6) {
                    ForEach(BagSize.allCases) { size in
                        let on = kept.size == size
                        choice(size.name, on: on, id: "bag-detail-size-\(size.rawValue)") { writeLost { $0.size = on ? nil : size } }
                    }
                }
                lostField($lost.sizeNote, "Measures, e.g. 55 \u{00D7} 40 \u{00D7} 20 cm", id: "bag-detail-sizenote")
            }
            lostPart("Distinctive marks") {
                lostField($lost.marks, "e.g. red strap, sticker on the side", id: "bag-detail-marks", lines: true)
            }
            // How it looks (his ask of 14 Oct 2026): the bag itself, empty or any time — not packed.
            lostPart("Photos of the bag") {
                BagOwnPhotos(bagId: bag.id).environmentObject(model)
            }
        }
        .onChange(of: lost) { _, _ in lostTyped() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bag-lost")
    }

    /// A small label over its answer — as MAX KG over the numbers.
    private func lostPart<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(.caption2, weight: .semibold)).kerning(0.4).foregroundStyle(Theme.muted)
            content()
        }
    }

    /// The numbers' field, in Body regular; the marks grow downwards, up to four lines.
    private func lostField(_ text: Binding<String>, _ prompt: String, id: String, lines: Bool = false) -> some View {
        TextField(prompt, text: text, axis: lines ? .vertical : .horizontal)
            .lineLimit(lines ? 1...4 : 1...1)
            .textFieldStyle(.plain)
            .font(.system(.body)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 10).padding(.vertical, lines ? 9 : 0).frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
            .onSubmit { writeLost() }
            .accessibilityIdentifier(id)
    }

    private func loadLost(_ d: BagDetails) {
        lost = LostTyped(brand: d.brand, colour: d.colour, sizeNote: d.sizeNote, marks: d.marks)
    }

    /// The kept answers into the fields — each only where what is typed does not already say it.
    private func followLost(_ d: BagDetails) {
        if jsTrim(lost.brand) != d.brand { lost.brand = d.brand }
        if jsTrim(lost.colour) != d.colour { lost.colour = d.colour }
        if jsTrim(lost.sizeNote) != d.sizeNote { lost.sizeNote = d.sizeNote }
        if jsTrim(lost.marks) != d.marks { lost.marks = d.marks }
    }

    /// A key typed: written 0.4 s after the last one (a whole save per key would be slow on a
    /// big library — `LibraryModel.commit` builds every record again).
    private func lostTyped() {
        guard let kept = model.library.bagDetails(id: bagId) else { return }
        var d = kept
        d.brand = lost.brand; d.colour = lost.colour; d.sizeNote = lost.sizeNote; d.marks = lost.marks
        guard d.trimmed != kept else { lostWrite?.cancel(); lostWrite = nil; return }
        lostWrite?.cancel()
        lostWrite = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            writeLost()
        }
    }

    /// Write what is typed (and a pill's answer) now. Only what differs is written.
    private func writeLost(_ edit: (inout BagDetails) -> Void = { _ in }) {
        lostWrite?.cancel()
        lostWrite = nil
        guard let kept = model.library.bagDetails(id: bagId) else { return }
        var d = kept
        d.brand = lost.brand; d.colour = lost.colour; d.sizeNote = lost.sizeNote; d.marks = lost.marks
        edit(&d)
        guard d.trimmed != kept else { return }
        let id = bagId
        model.change { _ = $0.setBagDetails(d, id: id) }
    }

    // MARK: What goes in it

    private func thingsInIt(_ facts: Library.BagFacts) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            heading("Usually in it", count: facts.things.count, id: "bag-things-count")
            if facts.things.isEmpty {
                quiet("Nothing yet. A thing goes here when its \u{201C}Usually packed in\u{201D} is this bag.")
            }
            let shown = allThings ? facts.things : Array(facts.things.prefix(12))
            ForEach(Array(shown.enumerated()), id: \.element.id) { i, thing in
                Button { opened = .thing(thing.id) } label: {
                    HStack {
                        Text(thing.name).font(.system(.callout)).foregroundStyle(Theme.ink).lineLimit(1)
                        Spacer(minLength: 8)
                        if thing.weight > 0 {
                            Text(BagsCard.kilos(thing.weight)).font(.system(.footnote).monospacedDigit()).foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(minHeight: Metrics.chip).contentShape(Rectangle())
                    .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("bag-thing-\(i)")
            }
            if facts.things.count > 12 {
                Button(allThings ? "Show fewer" : "Show all \(facts.things.count)") { allThings.toggle() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("bag-things-all")
            }
        }
    }

    // MARK: Where it has been

    private func trips(_ facts: Library.BagFacts) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            heading("On your trips", count: facts.trips.count, id: "bag-trips-count")
            if facts.trips.isEmpty { quiet("Not packed on a trip yet.") }
            ForEach(Array(facts.trips.prefix(8).enumerated()), id: \.offset) { i, t in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(t.name).font(.system(.callout)).foregroundStyle(Theme.ink).lineLimit(1)
                        Text(t.date).font(.system(.footnote).monospacedDigit()).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    Text(t.limitKg > 0 ? "\(BagsCard.kilos(t.grams)) / \(BagsCard.number(t.limitKg)) kg" : BagsCard.kilos(t.grams))
                        .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                        .foregroundStyle(t.over ? AppSection.actions.color : Theme.muted)
                }
                .frame(minHeight: Metrics.compact)
                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("bag-trip-\(i)")
            }
            if let top = facts.heaviest, facts.trips.count > 1 {
                Text("Heaviest: \(BagsCard.kilos(top.grams)) on \(top.name)")
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("bag-heaviest")
            }
        }
    }

    // MARK: Its details as a thing

    private func detailsDoor(_ bag: Item) -> some View {
        Button { writeLost(); writeNote(); opened = .thing(bag.id) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Its details").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("Kept at home, condition, brand, colour, notes")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
                SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 24, height: 24).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 14).frame(minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("bag-details")
    }

    // MARK: Deleting — small, at the side, and it asks where the things go

    @ViewBuilder private func deleteBag(_ bag: Item, _ facts: Library.BagFacts) -> some View {
        let others = model.library.bags().filter { $0.id != bag.id }
        // A bag nothing is packed in has nothing to move — a plain "Delete?" (his
        // ask, 2026-09-27, about his empty Handbag).
        let used = model.library.bagIsUsed(name: bag.name)
        // It may ALSO be a thing he packs — his Day pack on Travel (2026-09-27). Then
        // he chooses each time: stop it being a bag only, or delete it completely.
        let lists = model.library.listsHoldingBag(id: bag.id)
        if askingToDelete {
            VStack(alignment: .leading, spacing: 10) {
                Text("Delete \u{201C}\(bag.name)\u{201D}?")
                    .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                if !used {
                    Text("Nothing is packed in the \(bag.name), so nothing needs to move.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bag-delete-empty")
                } else {
                    // His words (2026-09-27): "any item that previously was designated to be
                    // packed in this item should be moved to another item" — or to none.
                    Text(facts.things.isEmpty
                         ? "Anything packed in the \(bag.name) will be packed in another bag instead. Choose which one, or no bag:"
                         : "The \(facts.things.count) thing\(facts.things.count == 1 ? "" : "s") packed in the \(bag.name) will be packed in another bag instead. Choose which one, or no bag:")
                        .font(.system(.subheadline)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bag-delete-explain")
                    FlowRow(spacing: 6) {
                        ForEach(Array(others.enumerated()), id: \.element.id) { i, other in
                            choice(other.name, on: moveTo == other.name, id: "bag-move-\(i)") { moveTo = other.name; deleteNeeds = "" }
                        }
                        choice("No bag", on: moveTo == "", id: "bag-move-none") { moveTo = ""; deleteNeeds = "" }
                    }
                }
                if !lists.isEmpty {
                    Text("The \(bag.name) is also on your \(BagPage.names(lists)) template\(lists.count == 1 ? "" : "s"), as something you pack.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bag-delete-lists")
                }
                let ready = !used || moveTo != nil
                HStack(spacing: 10) {
                    Button("Keep it") { askingToDelete = false; moveTo = nil; deleteNeeds = "" }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("bag-delete-no")
                    Spacer()
                    if !ready {
                        // Full colour like every main button (his rule); pressed before a
                        // bag is chosen, it says so under it. It was a faded "Choose
                        // first" that did nothing (the spec pass, 5 Oct 2026).
                        deleteButton("Delete", id: "bag-delete-yes", filled: true) {
                            deleteNeeds = "Choose where its things go first \u{2014} another bag, or No bag."
                        }
                    } else if lists.isEmpty {
                        deleteButton(!used ? "Delete the bag" : moveTo == "" ? "Delete, no bag" : "Move and delete",
                                     id: "bag-delete-yes", filled: true) { delete(bag, completely: false, used: used) }
                    }
                }
                if !deleteNeeds.isEmpty {
                    Text(deleteNeeds)
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bag-delete-needs")
                }
                if ready && !lists.isEmpty {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        deleteButton(lists.count == 1 ? "Keep it on \(lists[0])" : "Keep it on my templates",
                                     id: "bag-delete-yes", filled: false) { delete(bag, completely: false, used: used) }
                        deleteButton("Delete completely", id: "bag-delete-all", filled: true) {
                            delete(bag, completely: true, used: used)
                        }
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color, lineWidth: 1))
        } else {
            SmallDeleteButton(title: "Delete bag", id: "bag-delete") { askingToDelete = true }
        }
    }

    private func delete(_ bag: Item, completely: Bool, used: Bool) {
        let target = used ? (moveTo ?? "") : "", id = bag.id
        dismiss()
        model.change { _ = $0.deleteBag(id: id, moveTo: target, completely: completely) }
    }

    private func deleteButton(_ title: String, id: String, filled: Bool,
                              _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(filled ? Color.white : AppSection.actions.color)
                .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                .background(Capsule().fill(filled ? AppSection.actions.color : Color.clear))
                .overlay(Capsule().stroke(AppSection.actions.color, lineWidth: filled ? 0 : 1.5))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }

    /// "Travel", "Travel and Swim", "Travel, Swim and Run".
    static func names(_ lists: [String]) -> String {
        guard lists.count > 1 else { return lists.first ?? "" }
        return lists.dropLast().joined(separator: ", ") + " and " + (lists.last ?? "")
    }

    private func choice(_ title: String, on: Bool, id: String, _ pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            Text(title).font(.system(.footnote, weight: .semibold))
                .foregroundStyle(on ? Color.white : Theme.ink)
                .padding(.horizontal, 10).frame(minHeight: 32)
                .background(Capsule().fill(on ? AppSection.care.color : Theme.bg))
                .overlay(Capsule().stroke(on ? AppSection.care.color : Theme.line, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Pieces

    private func heading(_ title: String, count: Int, id: String) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("\(count)").font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                .accessibilityIdentifier(id)
        }
    }

    private func quiet(_ text: String) -> some View {
        Text(text).font(.system(.footnote)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Photos of the bag ITSELF on its page (0.80, his ask of 14 Oct 2026; spec 07 part 18 A): how it
/// looks, taken empty or any time, for the lost-luggage desk — two at most, the thing's own photos.
/// Not the trip's photos of it packed (`BagPhotoRow`). Taken as those are (`PhotoTakers`), seen
/// large on a tap, each with its own Remove.
struct BagOwnPhotos: View {
    let bagId: String
    @EnvironmentObject var model: LibraryModel
    @State private var large: Int?

    var body: some View {
        let shots = model.library.bagOwnPhotos(id: bagId).compactMap { p in JPEG.image(dataURL: p.data).map { (p.id, $0) } }
        // As stored: a photo still on its way from the other device takes its place too.
        let full = (model.library.bagDetails(id: bagId)?.photoIds.count ?? 0) >= BAG_OWN_PHOTOS_MAX
        VStack(alignment: .leading, spacing: 8) {
            if shots.isEmpty {
                Text("How it looks \u{2014} taken empty, any time. Two at most.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(shots.enumerated()), id: \.element.0) { k, shot in
                        VStack(spacing: 2) {
                            Button { large = k } label: {
                                Image(decorative: shot.1, scale: 1).resizable().scaledToFill()
                                    .frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("bag-detail-photo-thumb-\(k)")
                            .accessibilityLabel("Photo \(k + 1) of the bag")
                            Button("Remove") {
                                let b = bagId, id = shot.0
                                model.change { _ = $0.removeBagOwnPhoto(id: b, photoId: id) }
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                            .frame(minWidth: 80, minHeight: 34).contentShape(Rectangle())
                            .accessibilityIdentifier("bag-detail-photo-remove-\(k)")
                        }
                    }
                }
                .sheet(item: Binding(get: { large.map(Shown.init) }, set: { large = $0?.start })) {
                    BigPhoto(images: shots.map(\.1), captions: shots.map { _ in "How the bag looks" }, start: $0.start)
                }
            }
            if full {
                Text("Two photos \u{2014} remove one to add another")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bag-detail-photo-full")
            } else {
                PhotoTakers(id: "bag-detail-photo", testTitle: shots.isEmpty ? "Photo of the bag" : "Another photo",
                            take: shots.isEmpty ? "Take a photo" : "Take another",
                            choose: shots.isEmpty ? "Choose a photo" : "Choose another") { jpeg in
                    guard let jpeg else { return }
                    let b = bagId
                    model.change { _ = $0.addBagOwnPhoto(id: b, jpeg: jpeg) }
                }
            }
        }
    }

    private struct Shown: Identifiable { let start: Int; var id: Int { start } }
}

/// The bag's own photo, small, where a trip shows the bag and has no photo of it PACKED yet
/// (0.80): the Bags card's row and the Packing day's Photos station. A tap shows it large.
/// Nothing when the bag has none — or is only a name on the lines.
struct BagLookThumb: View {
    let tripId: String
    let bag: String
    let id: String
    var side: CGFloat = 32
    @EnvironmentObject var model: LibraryModel
    @State private var large = false

    var body: some View {
        if model.library.bagPhotoIds(tripId: tripId, bag: bag).isEmpty,
           let photo = model.library.bagOwnPhotos(bag: bag).first.flatMap({ JPEG.image(dataURL: $0.data) }) {
            Button { large = true } label: {
                Image(decorative: photo, scale: 1).resizable().scaledToFill()
                    .frame(width: side, height: side).clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier(id)
            .accessibilityLabel("How the \(bag) looks")
            .sheet(isPresented: $large) { BigPhoto(images: [photo], captions: ["\(bag) \u{2014} how it looks"]) }
        }
    }
}

/// Edit the bag while packing (0.90, his ask of 19 Oct 2026: "Add the possibility to Edit bag when
/// packing"). The trip's own pen — the round one beside its name in the header (`RoundIconLabel`
/// with `PenMark`, his 12 Oct ask: a bare pen did not read as an edit button) — at the right end of a
/// bag's line wherever a trip shows its bags: the Bags card and Packing Stations' Bags out, Weigh,
/// Tags and Photos. A tap opens the bag's own page over the trip; Done (or a swipe) brings him back
/// to the same place, the station and the open bag as they were. Only for a bag of his — one with a
/// page — never for Not in a bag, or a name on the lines that is no bag of his.
///
/// The page opens from the SCREEN (`open`), not from the pen: a renamed bag is another row, and a
/// sheet hung on the old row would close the moment the name was taken.
struct EditBagPen: View {
    let bag: String
    let id: String
    let open: (String) -> Void
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        if let bagId = model.library.bagId(named: bag) {
            Button { open(bagId) } label: {
                RoundIconLabel(tint: AppSection.events.color) { PenMark() }
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier(id)
            .accessibilityLabel("Edit the \(bag)")
        }
    }
}

/// The bag whose page a trip has open (`EditBagPen`).
struct EditBagOpen: Identifiable, Equatable { let id: String }
