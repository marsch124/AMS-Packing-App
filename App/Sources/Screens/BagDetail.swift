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
///
/// 0.91 — typing without a wait (his test sheet of 19 Oct 2026: "There is a delay. Once I have entered
/// data, there is a delay if I would like to scroll or move to the next data field"): every field on
/// the page keeps what is typed to itself (`DraftedField`, EditDraft.swift) and the page writes it all
/// in ONE change when it is left with Done (until 0.92 also a swipe down and Escape, until 0.98 also
/// the app going away), and before Duplicate or Its details. Moving from field to field and scrolling write nothing; a key
/// draws its field and nothing else (the name is typed in `BagHeader`, its own view, for the same reason).
///
/// 0.92 — Cancel (his question of 19 Oct 2026: "I open an item and change some property. How do I
/// cancel that? There is only a Done button, right?"): Cancel, top left as on a thing's page, closes
/// the page and writes NOTHING it holds. So everything changed on the page waits on its ledger — the
/// typed fields (0.91) and now the desk's pills, Goes in the cabin, Has an AirTag and a name taken
/// with Rename — and the pockets, written as they changed until 0.98 and put back by Cancel. Photos
/// are kept the moment they are taken, as on a thing's page. Its details and Duplicate write the page
/// first (they show or copy what it says): Cancel after them takes back only what changed since.
/// Escape is Cancel; Done and ⌘S write.
///
/// 0.98 — the Apple way (his decision of 21 Oct 2026: "Yes, go with the Apple way for Cancel/Done:
/// remove the keep-on-close from the template page, your lists and the bag page"), as Calendar's and
/// Contacts' edit sheets: nothing reaches the library until Done. The pockets too are held now — each
/// Add, rename, move and ✕ a step on the ledger (`EditDraft.step`), the page showing them from its own
/// copy (`BagPockets`) — so Cancel has nothing to put back. The app put away and back: the page is
/// still open with everything on it; the app swiped away or ended: nothing of it was kept.
struct BagPage: View {
    let bagId: String
    /// Open with the name selected, ready to be typed over (a copy just made).
    var selectName = false
    /// Duplicate made this copy: the sheet turns to it.
    var duplicated: (String) -> Void = { _ in }
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// What is typed on the page and not written yet (0.91).
    @State private var draft = EditDraft()
    @State private var allThings = false
    @State private var askingToDelete = false
    /// Where the bag's things go on a delete: nil = not chosen yet, "" = no bag.
    @State private var moveTo: String?
    /// What Delete was missing when pressed too early, said under it.
    @State private var deleteNeeds = ""
    @State private var opened: Opened?
    /// The desk's pills and the two switches as picked on the page and not written yet (0.92), by
    /// their key on the ledger: a type's or size's raw value ("" = none), "1"/"0" for a switch.
    @State private var held: [String: String] = [:]
    /// Something is held on the page and not written (0.92) — since 0.98 a pocket changed too: a
    /// swipe down then asks first. Set once, by the ledger, when it first holds something
    /// (`EditDraft.onFirstHold`).
    @State private var touched = false
    /// Part of the page was written while it stayed open — by Its details (0.94; until 0.98 also the
    /// app put away): Discard then says that what was kept stays.
    @State private var keptEarlier = false
    /// Its details wrote the page (0.98): the pockets show the library again, not the page's copy.
    @State private var pocketsFresh = 0

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
                // Done closes only when what the page holds was kept (0.94): a save the store refused
                // leaves the page open, still holding it — the name too — for Done again.
                BagHeader(bag: bag, selectName: selectName, draft: draft, done: { if draft.flush(model) { dismiss() } },
                          cancel: { cancel() })
                    .environmentObject(model)
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
                        // Held on the ledger with the rest (0.98): nothing reaches the library before Done.
                        BagPockets(bagId: bag.id, draft: draft).environmentObject(model).id(pocketsFresh)
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
            if !touched && draft.onFirstHold == nil { armTouched() }     // once: not again after a sheet on top
        }
        // A swipe down (the iPhone): with nothing held it closes; with something held it asks first —
        // Discard is Cancel (0.92, the app's rule; spec 06 §20a). Until then a swipe wrote everything.
        // Only Done writes — since 0.98 not the app going away either (the Apple way): the ledger
        // stays in memory while the app is away, and goes with it when the app is swiped away.
        .asksBeforeDiscarding(touched, keptEarlier: keptEarlier) { cancel() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bag-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    // MARK: Notes (0.90) — the bag's thing's own

    private var storedNote: String { model.library.items.first { $0.id == bagId }?.note ?? "" }

    private func notes(_ bag: Item) -> some View {
        let id = bagId
        return VStack(alignment: .leading, spacing: 4) {
            Text("NOTES").font(.system(.caption2, weight: .semibold)).kerning(0.4).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("bag-detail-notes-label")
            DraftedField(key: "note", kept: storedNote, draft: draft,
                         differs: { [storedNote] in jsTrim($0) != storedNote },
                         write: { words, lib in _ = lib.setThingNote(id: id, words) }) { text in
                TextField("Anything worth remembering", text: text, axis: .vertical)
                    .lineLimit(1...8)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).padding(.vertical, 9).frame(minHeight: 40)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    .accessibilityIdentifier("bag-detail-notes")
            }
            // The notes its templates keep for it, as under a thing's Notes (a bag he also packs).
            ForEach(Array(model.library.rowNotes(itemId: bag.id).enumerated()), id: \.offset) { n, said in
                Text("Note on the \(said.template) template: \(said.note)")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bag-row-note-\(n)")
            }
        }
    }

    // MARK: Duplicate (0.90) — his ask of 19 Oct 2026

    /// "Duplicate this bag": a copy of everything that describes it — not its photos, its trips
    /// or what is in it (BagDuplicate.swift) — right after it on Your bags; its page opens at once,
    /// the name ("Duffel 2") selected for typing. Calm, outlined, like Start a new trip from this one.
    /// What the page holds is written first, in the same change — then a name typed and not taken
    /// is renamed if it can be (the newest word on the name wins over one taken before it).
    private func duplicateBag(_ bag: Item) -> some View {
        Button {
            var copy: Item?
            let id = bag.id, name = draft.typedName
            // A save the store refused (0.94): no copy, and the page keeps holding what it held.
            let kept = draft.writing(model) { lib in
                if let name, let now = lib.items.first(where: { $0.id == id })?.name, jsTrim(name) != now {
                    _ = lib.renameThing(id: id, to: name)
                }
                copy = lib.duplicateBag(id: id)
            }
            if kept, let copy { duplicated(copy.id) }
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

    // MARK: Numbers — kept as typed, written when the page is left (0.91)

    private func numbers(_ bag: Item) -> some View {
        let id = bag.id
        return HStack(spacing: 10) {
            number("Max kg", key: "maxKg", now: bag.maxKg, shown: bag.maxKg > 0 ? BagsScreen.show(bag.maxKg) : "",
                   id: "bag-detail-maxkg") { v, lib in _ = lib.setBag(id: id, maxKg: v) }
            number("Litres", key: "litres", now: bag.capacityL, shown: bag.capacityL > 0 ? BagsScreen.show(bag.capacityL) : "",
                   id: "bag-detail-litres") { v, lib in _ = lib.setBag(id: id, capacityL: v) }
            number("Empty g", key: "empty", now: bag.weight, shown: bag.weight > 0 ? String(Int(bag.weight.rounded())) : "",
                   id: "bag-detail-empty") { v, lib in _ = lib.setBag(id: id, emptyGrams: v) }
        }
    }

    private func number(_ title: String, key: String, now: Double, shown: String, id: String,
                        write: @escaping (Double, inout Library) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.system(.caption2, weight: .semibold)).kerning(0.4).foregroundStyle(Theme.muted)
            DraftedField(key: key, kept: shown, draft: draft, differs: { TypedNumber.differs($0, from: now) },
                         write: { words, lib in if let v = TypedNumber.read(words) { write(v, &lib) } }) { text in
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .font(.system(.body, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    .accessibilityIdentifier(id)
            }
        }
    }

    // MARK: The cabin — a plane trip checks this bag (his idea 4, 2 Oct 2026)

    private func cabinSwitch(_ bag: Item) -> some View {
        let thing = model.library.items.first { $0.id == bag.id } ?? bag
        let kept = Library.isCabinBag(thing), id = bag.id
        return Toggle(isOn: Binding(get: { held["cabin"].map { $0 == "1" } ?? kept },
                                    set: { on in hold("cabin", on ? "1" : "0", kept: kept ? "1" : "0") { v, lib in _ = lib.setBagCabin(id: id, v == "1") } })) {
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
        let kept = Library.hasAirTag(thing), id = bag.id
        return Toggle(isOn: Binding(get: { held["airTag"].map { $0 == "1" } ?? kept },
                                    set: { on in hold("airTag", on ? "1" : "0", kept: kept ? "1" : "0") { v, lib in _ = lib.setBagAirTag(id: id, v == "1") } })) {
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
    /// colour are the thing's own — "Its details" shows the same values. Its words kept as typed
    /// and written when the page is left (0.91); since 0.92 its pills too (Cancel forgets them).
    private func lostDesk(_ bag: Item) -> some View {
        let kept = model.library.bagDetails(id: bag.id) ?? BagDetails()
        let id = bag.id
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
                lostField("brand", kept.brand, "e.g. Samsonite", id: "bag-detail-brand") { $0.brand = $1 }
            }
            lostPart("Colour") {
                BagColourPart(kept: kept.colour, draft: draft, write: BagPage.detail(id) { $0.colour = $1 })
            }
            lostPart("Type") {
                FlowRow(spacing: 6) {
                    let now = held["type"] ?? kept.type?.rawValue ?? ""
                    ForEach(BagType.allCases) { type in
                        let on = now == type.rawValue
                        bagChoice(type.name, on: on, id: "bag-detail-type-\(type.rawValue)") {
                            hold("type", on ? "" : type.rawValue, kept: kept.type?.rawValue ?? "") { v, lib in
                                BagPage.details(id, &lib) { $0.type = BagType(rawValue: v) }
                            }
                        }
                    }
                }
            }
            lostPart("Size") {
                FlowRow(spacing: 6) {
                    let now = held["size"] ?? kept.size?.rawValue ?? ""
                    ForEach(BagSize.allCases) { size in
                        let on = now == size.rawValue
                        bagChoice(size.name, on: on, id: "bag-detail-size-\(size.rawValue)") {
                            hold("size", on ? "" : size.rawValue, kept: kept.size?.rawValue ?? "") { v, lib in
                                BagPage.details(id, &lib) { $0.size = BagSize(rawValue: v) }
                            }
                        }
                    }
                }
                lostField("sizeNote", kept.sizeNote, "Measures, e.g. 55 \u{00D7} 40 \u{00D7} 20 cm", id: "bag-detail-sizenote") { $0.sizeNote = $1 }
            }
            lostPart("Distinctive marks") {
                lostField("marks", kept.marks, "e.g. red strap, sticker on the side", id: "bag-detail-marks", lines: true) { $0.marks = $1 }
            }
            // How it looks (his ask of 14 Oct 2026): the bag itself, empty or any time — not packed.
            lostPart("Photos of the bag") {
                BagOwnPhotos(bagId: bag.id).environmentObject(model)
            }
        }
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

    /// One of the desk's words, kept as typed: in Body regular; the marks grow downwards, up to four lines.
    private func lostField(_ key: String, _ kept: String, _ prompt: String, id: String, lines: Bool = false,
                           _ set: @escaping (inout BagDetails, String) -> Void) -> some View {
        DraftedField(key: key, kept: kept, draft: draft, differs: { jsTrim($0) != kept },
                     write: BagPage.detail(bagId, set)) { text in
            bagTextField(text, prompt, id: id, lines: lines)
        }
    }

    /// Write one of the desk's answers onto the bag (only what differs is written — `setBagDetails`).
    static func details(_ id: String, _ lib: inout Library, _ edit: (inout BagDetails) -> Void) {
        guard var d = lib.bagDetails(id: id) else { return }
        edit(&d)
        _ = lib.setBagDetails(d, id: id)
    }

    /// The write of one typed desk field.
    static func detail(_ id: String, _ set: @escaping (inout BagDetails, String) -> Void) -> (String, inout Library) -> Void {
        { words, lib in details(id, &lib) { set(&$0, words) } }
    }

    /// A pill or a switch (0.92): shown at once and held on the page's ledger with everything typed —
    /// written when the page is left by Done or a swipe, forgotten by Cancel.
    private func hold(_ key: String, _ value: String, kept: String, write: @escaping (String, inout Library) -> Void) {
        held[key] = value
        draft.typed(key, value, differs: value != kept, write: write)
    }

    // MARK: Cancel (0.92) — his "How do I cancel that?"

    /// Close and write nothing the page holds — since 0.98 its pocket changes neither: they were
    /// held too, so there is nothing to put back (until 0.98 they were written as made, and Cancel put
    /// back what this page changed — 0.95's `PocketsTrail`).
    private func cancel() {
        draft.close()
        dismiss()
    }

    /// The page has written what it holds (Its details): Cancel goes back to here, Discard says that
    /// what was kept stays, and the pockets show the library again.
    private func savedHere() {
        if touched { keptEarlier = true }
        pocketsFresh += 1
        armTouched()
    }

    /// Nothing held: the ledger says when it first holds something (0.92).
    private func armTouched() {
        touched = false
        draft.onFirstHold = { touched = true }
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
        // What is typed is written first: Its details shows the same notes, brand and colour.
        Button {
            guard draft.flush(model) else { return }       // refused (0.94): the page keeps holding it
            savedHere()
            opened = .thing(bag.id)
        } label: {
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
        draft.discard()                     // nothing typed about a bag that goes is written
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
        bagChoice(title, on: on, id: id, pick)
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

/// A bag page's header: Cancel and Done (0.92: Cancel top left, as on a thing's page), and under
/// them the name, which IS the field — press it, type, Rename (0.91: its own view, so a key typed in
/// the name draws the name and not the whole page). A name taken — Rename, Return, or Done with a
/// name typed (0.90: a copy is named and closed in one go) — is checked at once (a name refused keeps
/// the page open and says why) and held on the page's ledger since 0.92: written with everything else
/// when the page is left by Done or a swipe; Cancel forgets it. What is typed and not taken is on the
/// ledger for Duplicate.
struct BagHeader: View {
    let bag: Item
    /// Open with the name selected, ready to be typed over (a copy just made).
    let selectName: Bool
    let draft: EditDraft
    /// Done: the page closes and writes what it holds.
    let done: () -> Void
    /// Cancel (0.92): the page closes and writes nothing it holds.
    let cancel: () -> Void
    @EnvironmentObject var model: LibraryModel
    @State private var renaming: String?
    /// A name taken and not written yet (0.92) — what the field shows when nothing is typed.
    @State private var heldName: String?
    /// The name's selection, and whether it has the keys — for a copy just made (0.90).
    @State private var nameSelection: TextSelection?
    @FocusState private var naming: Bool
    @State private var problem = ""

    var body: some View {
        let shown = heldName ?? bag.name
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Cancel") { cancel() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.muted)
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel, as on a thing's page (0.92)
                    .accessibilityIdentifier("bag-cancel")
                Spacer()
                Button("Done") { if rename() { done() } }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    .keyboardShortcut("s")                       // ⌘S = Done (0.92)
                    .accessibilityIdentifier("bag-done")
            }
            HStack(spacing: 10) {
                TextField("", text: Binding(get: { renaming ?? shown },
                                            set: { renaming = $0; draft.typedName = $0; problem = "" }),
                          selection: $nameSelection)
                    .textFieldStyle(.plain)
                    .focused($naming)
                    .font(.system(.title3, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .onSubmit { rename() }
                    .accessibilityIdentifier("bag-name")
                if let wanted = renaming, jsTrim(wanted) != shown {
                    Button { rename() } label: {
                        Text("Rename").font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: 34)
                            .background(Capsule().fill(AppSection.care.color))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("bag-rename")
                }
            }
            if !problem.isEmpty {
                Text(problem).font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .accessibilityIdentifier("bag-problem")
            }
        }
        .padding(16)
        .onAppear { if selectName { selectTheName(bag.name) } }
    }

    /// Take the name typed: checked now, held on the page's ledger (0.92) — `renameThing` when the
    /// page writes. False, and why under it, for no name or one another thing has.
    @discardableResult private func rename() -> Bool {
        guard let wanted = renaming else { return true }
        let clean = jsTrim(wanted), id = bag.id
        guard clean != (heldName ?? bag.name) else { renaming = nil; draft.typedName = nil; return true }
        if clean.isEmpty { problem = "A bag needs a name."; return false }
        if model.library.items.contains(where: { $0.id != id && normName($0.name) == normName(clean) }) {
            problem = "You already have something called that."
            return false
        }
        draft.typed("name", clean, differs: clean != bag.name) { words, lib in _ = lib.renameThing(id: id, to: words) }
        heldName = clean == bag.name ? nil : clean
        renaming = nil; draft.typedName = nil; problem = ""
        return true
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
}

/// The desk's Colour: the field and its seven pills, which light up by what is TYPED (0.91: its own
/// view, so a key draws only this). Typed words wait on the page's ledger — and since 0.92 a pill's
/// colour too: it writes its word into the field ("" = the lit one taken off), and Cancel forgets it.
struct BagColourPart: View {
    let kept: String
    let draft: EditDraft
    let write: (String, inout Library) -> Void
    @State private var typed: String?

    var body: some View {
        let shown = typed ?? kept
        let lit = BagDetails(colour: shown)
        VStack(alignment: .leading, spacing: 6) {
            bagTextField(Binding(get: { shown }, set: { words in
                EditTiming.mark("key")
                typed = words
                draft.typed("colour", words, differs: jsTrim(words) != kept, write: write)
            }), "e.g. Dark blue", id: "bag-detail-colour")
            FlowRow(spacing: 6) {
                ForEach(BagDetails.colourPills) { p in
                    let on = lit.lit(p)
                    bagChoice(p.label, on: on, id: "bag-detail-colour-\(p.label.lowercased())") {
                        let words = on ? "" : p.value
                        typed = words
                        draft.typed("colour", words, differs: jsTrim(words) != kept, write: write)
                    }
                }
            }
        }
        .onChange(of: kept) { _, now in
            guard !draft.isPending("colour"), let t = typed, t != now else { return }
            typed = nil
        }
    }
}

/// The desk's text field (as the numbers' field, in Body regular); `lines`: grows downwards, up to four.
func bagTextField(_ text: Binding<String>, _ prompt: String, id: String, lines: Bool = false) -> some View {
    TextField(prompt, text: text, axis: lines ? .vertical : .horizontal)
        .lineLimit(lines ? 1...4 : 1...1)
        .textFieldStyle(.plain)
        .font(.system(.body)).foregroundStyle(Theme.ink)
        .padding(.horizontal, 10).padding(.vertical, lines ? 9 : 0).frame(minHeight: 40)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
        .accessibilityIdentifier(id)
}

/// A pill on a bag's page: one choice of a row, lit in Care's orange.
func bagChoice(_ title: String, on: Bool, id: String, _ pick: @escaping () -> Void) -> some View {
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
        .takesDroppedPhoto(room: !full, tint: AppSection.events.color) { jpeg in
            guard let jpeg else { return }
            let b = bagId
            model.change { _ = $0.addBagOwnPhoto(id: b, jpeg: jpeg) }
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
