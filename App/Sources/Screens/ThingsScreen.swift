import SwiftUI
import PackingCore
import PackingLibrary

/// Your things: everything he owns, whether or not it is on a list yet. Tap one
/// to change it — a change here reaches every list it is on.
struct ThingsScreen: View {
    /// Opened from a bar on the Care dashboard: start with this in the search.
    var searching: String = ""
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var noListOnly = false
    @State private var newName = ""
    /// What New was missing, said under the field (never a grey button).
    @State private var newNeeds = ""
    @State private var editing: String?
    /// What he added on this visit, newest first — their field test (3 Oct
    /// 2026): "When you add an item, it needs to be on top of the list. Now it is just
    /// hidden in the total list." They stay on top until the screen is left.
    @State private var justAdded: [String] = []
    /// The one just added, lit up for a moment so the eye lands on it.
    @State private var lit: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let all = model.library.thingRows()
        let homeless = all.filter { $0.templates.isEmpty }.count
        let q = normName(query)
        // Its notes count too (0.69): its own Notes and the notes its templates keep for it.
        let hits = model.library.noteHits(query)
        let shown = all.filter { (!noListOnly || $0.templates.isEmpty)
            && (q.isEmpty || normName($0.item.name).contains(q) || hits[$0.item.id] != nil) }
        // The note line shows only under a thing found by its notes, not by its name.
        let note: ((item: Item, templates: [String])) -> NoteHit? = { row in
            normName(row.item.name).contains(q) ? nil : hits[row.item.id]
        }
        // The ones added on this visit first (newest on top), then the rest A–Z.
        let fresh = justAdded.compactMap { id in shown.first { $0.item.id == id } }
        let rest = fresh.isEmpty ? shown : shown.filter { !justAdded.contains($0.item.id) }
        VStack(spacing: 0) {
            HStack {
                Text("Your things").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    .keyboardShortcut(.cancelAction)            // Escape closes it, as Done does (Escape everywhere, 5 Oct 2026)
                    .accessibilityIdentifier("things-done")
            }
            .padding(16)
            TextField("Search your things…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .clearButton($query, id: "things-search")
                .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .padding(.horizontal, 16)
            HStack(spacing: 10) {
                Text(shown.count == 1 ? "1 thing" : "\(shown.count) things")
                    .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("things-count")
                Spacer()
                if homeless > 0 {
                    Button { noListOnly.toggle() } label: {
                        Text("On no template \(homeless)").font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(noListOnly ? Color.white : AppSection.care.color)
                            .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                            .background(Capsule().fill(noListOnly ? AppSection.care.color : Theme.card))
                            .overlay(Capsule().stroke(AppSection.care.color.opacity(0.6), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("things-nolist")
                    .accessibilityAddTraits(noListOnly ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16).padding(.top, 10)
            ScrollViewReader { proxy in
                KeyboardAwayScroll {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id(ThingsScreen.top)
                        if !fresh.isEmpty {
                            listHeading("Just added", id: "things-just-added")
                            ForEach(Array(fresh.enumerated()), id: \.element.item.id) { n, row in
                                // A row of its own, not the A–Z row moved up: the Mac kept
                                // the moved row's old name ("thing-row-7" at the top of the
                                // list, 3 Oct 2026), so a test — and VoiceOver — lost it.
                                thingRow(row, n: n, note: note(row)).id("just-added-\(row.item.id)")
                            }
                            if !rest.isEmpty { listHeading("A–Z", id: "things-rest") }
                        }
                        ForEach(Array(rest.enumerated()), id: \.element.item.id) { n, row in
                            thingRow(row, n: fresh.count + n, note: note(row))
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 24)
                }
                // Wherever the list was scrolled to, a new thing is seen arriving.
                .onChange(of: justAdded) { _, _ in
                    if reduceMotion { proxy.scrollTo(ThingsScreen.top, anchor: .top) }
                    else { withAnimation { proxy.scrollTo(ThingsScreen.top, anchor: .top) } }
                }
            }
            HStack(spacing: 8) {
                TextField("A new thing", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("thing-new-name")
                Button { add() } label: { FieldButtonLabel(title: "New", tint: AppSection.care.color) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("thing-new")
            }
            .needsLine($newNeeds, typed: newName, id: "thing-new-needs")
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: Binding(get: { editing.map { Editing(id: $0) } }, set: { editing = $0?.id })) { e in
            // ⌘↓ ⌘↑ (Mac) go through the things as listed here; one made with ⌘N comes
            // in under Just added, as one added at the foot does.
            ThingEditor(itemId: e.id, order: { shownIds() }, made: { id in
                // A search that would hide it is emptied, as for one added at the foot.
                let name = model.library.items.first { $0.id == id }?.name ?? ""
                let q = normName(query)
                if !q.isEmpty && !normName(name).contains(q) { query = "" }
                justAdded.removeAll { $0 == id }
                justAdded.insert(id, at: 0)
            })
            .environmentObject(model)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("things-detail")
        .onAppear { if query.isEmpty, !searching.isEmpty { query = searching } }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    private static let top = "things-top"

    /// The things as listed now, top to bottom: Just added, then the rest A–Z, under the
    /// search and the On no template chip — what a thing's page goes through (Mac keys).
    private func shownIds() -> [String] {
        let q = normName(query)
        let hits = model.library.noteHits(query)    // found by its notes too (0.69), as listed
        let shown = model.library.thingRows()
            .filter { (!noListOnly || $0.templates.isEmpty)
                && (q.isEmpty || normName($0.item.name).contains(q) || hits[$0.item.id] != nil) }
            .map(\.item.id)
        let fresh = justAdded.filter { shown.contains($0) }
        return fresh + shown.filter { !fresh.contains($0) }
    }

    /// `note`: the line of its notes a search found it by (0.69), shown under it — muted,
    /// the words searched for in Care's colour. Its own text, outside the row's button, so
    /// the Mac keeps it apart (a button folds its texts into itself there); a tap on it
    /// opens the thing too.
    private func thingRow(_ row: (item: Item, templates: [String]), n: Int, note: NoteHit? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
        Button { editing = row.item.id } label: {
            // The name and where it lives on ONE line (his word, 5 Oct 2026: "set the item
            // name and the info on the same line").
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(row.item.name).font(.body).foregroundStyle(Theme.ink)
                    .lineLimit(1).layoutPriority(1)
                Spacer(minLength: 6)
                Text([row.templates.isEmpty ? "On no template" : row.templates.joined(separator: ", "),
                      row.item.storage].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(.footnote)).foregroundStyle(row.templates.isEmpty ? AppSection.care.color : Theme.muted)
                    .lineLimit(1).truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            // Lit just past the text's edges, so the name does not move.
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(lit == row.item.id ? AppSection.care.color.opacity(0.18) : Color.clear)
                .padding(.horizontal, -8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("thing-row-\(n)")
            if let note {
                NoteHitLine(hit: note, query: query, tint: AppSection.care.color)
                    .padding(.top, -3).padding(.bottom, 5)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = row.item.id }
                    .accessibilityIdentifier("thing-row-\(n)-note")
            }
        }
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }

    private func listHeading(_ title: String, id: String) -> some View {
        Text(title)
            .font(.headline).foregroundStyle(AppSection.care.color)
            .padding(.top, 12).padding(.bottom, 2)
            .accessibilityIdentifier(id)
    }

    private func add() {
        let name = newName
        guard !jsTrim(name).isEmpty else { newNeeds = "Type a name first."; return }
        var made: Item?
        model.change { made = $0.addThing(name: name) }
        guard let id = made?.id else {
            // Refused because he has one by that name: say so and keep what he typed,
            // as Your bags does. (It emptied the field without a word — his rule is
            // that a press says what went wrong; the spec pass, 5 Oct 2026.)
            newNeeds = "You already have a thing called that."
            return
        }
        newName = ""
        // A search that would hide it is emptied: the point is to SEE it arrive.
        let q = normName(query)
        if !q.isEmpty && !normName(name).contains(q) { query = "" }
        justAdded.removeAll { $0 == id }
        justAdded.insert(id, at: 0)
        lit = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard lit == id else { return }
            if reduceMotion { lit = nil } else { withAnimation(.easeOut(duration: 0.6)) { lit = nil } }
        }
    }

    private struct Editing: Identifiable { let id: String }
}

/// One thing: what IT knows — its name, where it is kept, what kind of thing it
/// is, its own bag and "When", whose it is, its condition, its weight — and which
/// lists it is on. A change here reaches every list; a list's own exception for
/// the bag stays that list's.
struct ThingEditor: View {
    let itemId: String
    /// The things of the list the page was opened from, in that list's order of the
    /// moment — Your things as shown, the table as sorted and filtered: what ⌘↓ and ⌘↑ go
    /// through on the Mac (0.68). nil = opened from no list (a trip, a bag, the search).
    var order: (() -> [String])? = nil
    /// A thing made on this page (⌘N on the Mac, 0.68): the list behind shows it.
    var made: ((String) -> Void)? = nil
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// The thing on the page: the one it was opened on until ⌘↓ ⌘↑ go on (Mac); nil = a
    /// new thing, made only when it is saved (⌘N, Mac).
    @State private var shown: String?
    @State private var draft = Item()
    @State private var onLists: Set<String> = []
    @State private var problem = ""
    @State private var askingToDelete = false
    /// The weight as he types it: "12,5" and "12." must survive the typing, so the
    /// field is not rewritten from the number on every keystroke (it was: decimals
    /// and the comma were lost, 88.7 showed as 88 — the spec pass, 5 Oct 2026).
    @State private var weightText = ""
    /// What was wrong with the weight when Save was pressed, said under the field.
    @State private var weightProblem = ""
    /// The care schedule (days, 0 = none) and care notes, edited here since 0.62.
    @State private var careEvery = 0
    @State private var careNotes = ""
    /// The section chosen on each template it is on (template id → a section id, "" =
    /// none, `RowEditor.newSectionKey` = one typed here), and what each showed when the
    /// page opened — Save writes only those he changed.
    @State private var sections: [String: String] = [:]
    @State private var sectionsAtOpen: [String: String] = [:]
    /// A section typed here, per template, waiting for Save: made only then, so Cancel
    /// leaves the template as it was (as in the row editor).
    @State private var newSections: [String: String] = [:]
    /// Each template's sections renamed, moved or removed in a Section list here (0.68),
    /// waiting for Save like a typed one — Cancel leaves the template as it was.
    @State private var sectionEdits: [String: SectionEdits] = [:]
    /// His own lists changed inside their drop-downs here (0.69, ChoiceDropDown.swift) —
    /// by list ("places", "bags", "pockets:<bag>" …), waiting for Save like the sections.
    @State private var choiceLists: [String: ChoiceEdits] = [:]
    /// A bag whose page was asked for from Usually packed in ("Open the bag", 0.69).
    @State private var bagPage: String?

    // The Mac's keys (0.68) — see ThingKeys.swift. Unused on the iPhone.
    /// The field in focus, as the page sees it: ringed, and named at the page's foot.
    @State private var at: ThingField?
    /// The text field that has the window's keys — the same field when `at` is one.
    @FocusState private var typing: ThingField?
    /// The template pill the arrows are on in On these templates.
    @State private var pillAt: Int?
    /// The drop-down whose list is open (its field's id), for the line at the foot.
    @State private var listOpen: String?
    /// Valid until as typed on the Mac ("30/6 27", "+6m"), read when the field is left or
    /// the page is saved; and what was wrong with it.
    @State private var expiryText = ""
    @State private var expiryProblem = ""
    /// The ⌘J box: open, what is typed in it, and where the focus was before.
    @State private var jumping = false
    @State private var jumpText = ""
    @State private var beforeJump: ThingField?
    /// Said at the foot instead of the keys for a moment ("That was the last thing…").
    @State private var keyNote = ""
    /// The list ⌘↓ ⌘↑ go through, as it stood when the page started going through it:
    /// a thing that leaves the list by being filled in (the table filtered to No weight)
    /// keeps its place in the walk, both ways.
    @State private var walk: [String]?
    #if os(macOS)
    @State private var keyHome = ThingKeyHome()
    #endif

    init(itemId: String, order: (() -> [String])? = nil, made: ((String) -> Void)? = nil) {
        self.itemId = itemId
        self.order = order
        self.made = made
        _shown = State(initialValue: itemId)
    }

    /// The thing on the page ("" while a new one is being made).
    private var current: String { shown ?? "" }

    /// Every template but the bag list, A–Z — the pills of On these templates.
    private var templates: [PackList] {
        model.library.templatesForThings()
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
    }
    /// What it holds, or the kit it is in (0.70, ThingKitPart.swift) — kept until Save.
    @State private var kit = KitDraft()

    var body: some View {
        let templates = self.templates
        let owners = model.library.ownerChoices()          // each once (his screenshot, 2026-09-26)
        // His own lists, as their drop-downs show them while this page holds their changes.
        let kinds = drop("categories", chosen: draft.category, words: "your kinds of thing")
        let whose = drop("owners", chosen: draft.ownedBy, words: "your owners")
        let bags = drop("bags", chosen: draft.container, words: "your bags",
                        open: DropDownOpen(title: "Open the bag") { name in openBag(name) })
        let bag = ThingEditor.bagChoices(bags.rows.isEmpty ? model.library.bagNames().map { ($0, $0) } : bags.options,
                                         current: draft.container)
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.muted)
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel, never Save (Escape everywhere, 5 Oct 2026)
                    .accessibilityIdentifier("thing-cancel")
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("thing-save")
            }
            .padding(16)
            #if os(macOS)
            if jumping { jumpBox }
            #endif
            ScrollViewReader { proxy in
            KeyboardAwayScroll {
                // A field sits right under its heading, and the space goes BETWEEN the
                // headings (his screenshot, 2026-09-28: "put the Bike field much nearer
                // its heading, the same goes for everything").
                VStack(alignment: .leading, spacing: 12) {
                    labelled("Name") { field($draft.name, "Name", "thing-name", .name) }
                        .keyed(.name)
                    // Notes right under the name — his ask (4 Oct 2026): "please put the
                    // notes field immediately under the name".
                    labelled("Notes") {
                        notesField
                        rowNotes
                    }
                    .keyed(.notes)
                    // The order is his (6 Oct 2026): what it is and whose, the templates it is on,
                    // where it lives and goes and when, the details, and last what a flight and a
                    // date ask of it.
                    // Every pick-one list here is a drop-down (his word, 6 Oct 2026: "Can we please
                    // make these kinds of drop-downs everywhere?"); a kind of thing from the web app
                    // that is none of the app's is shown on a row of its own.
                    DropDown(title: "Kind of thing", options: kinds.options, selected: draft.category,
                             id: "thing-category", other: true,
                             newEntry: kinds.newEntry("A new kind", needs: "Type the kind first.") { draft.category = $0 },
                             tools: kinds.tools, ring: ring(.category)) { draft.category = $0 }
                        .keyed(.category)
                    if !owners.isEmpty {
                        // No owner means each has one of their own — his words (4 Oct 2026):
                        // "Replace 'Nobody's in particular' with 'Both have one'".
                        // His owners (A–Z, no ↑ ↓), then anyone a thing names who is not one of them.
                        let listed = Set(model.library.owners().map(normName))
                        DropDown(title: "Whose it is",
                                 options: [("", OWNER_BOTH)] + whose.options + owners.filter { !listed.contains(normName($0)) }.map { ($0, $0) },
                                 selected: draft.ownedBy, id: "thing-owner", other: true,
                                 newEntry: whose.newEntry("A new owner", needs: "Type the name first.") { draft.ownedBy = $0 },
                                 tools: whose.tools, ring: ring(.owner)) { draft.ownedBy = $0 }
                            .keyed(.owner)
                    } else {
                        // Nobody named anywhere yet: the heading stays, and says where the
                        // names come from (it vanished, so the first owner could not be
                        // found from here — the spec pass, 5 Oct 2026).
                        VStack(alignment: .leading, spacing: 6) {
                            HeadingBand(title: "Whose it is", id: "thing-owner-title")
                            Text("Nobody is named yet. Add the names in Settings, under Your choices.")
                                .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("thing-owner-none")
                        }
                    }
                    Pills(title: "On these templates", options: templates.map { ($0.id, $0.name) }, selected: onLists,
                          id: "thing-lists", tint: AppSection.templates.color, heading: .band,
                          cursor: at == .templates ? pillAt : nil) { id in
                        toggleTemplate(id)
                        #if os(macOS)
                        // A click puts the arrows on that pill.
                        if let n = templates.firstIndex(where: { $0.id == id }) { pillAt = n; land(.templates, quiet: true) }
                        #endif
                    }
                    .keyed(.templates)
                    sectionChoices(templates)
                    // Where the trip tags live (his ask, 2 Oct 2026, to have them here).
                    Text("Only on some trips — Season, Indoor/Outdoor, Transport, Food — is set per template: open the template and tap this thing.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("thing-tags-hint")
                    // Chosen from his places, never typed (6 Oct 2026, his word: "Can we turn Kept
                    // at home into a drop-down … so that we have a list to choose from? If we write
                    // it this way, it's a possibility that the naming convention skews.")
                    keptAtHome
                        .keyed(.storage)
                    DropDown(title: "Usually packed in", options: bag.options.map { ($0.id, $0.label) },
                             selected: bag.selected, id: "thing-bag",
                             newEntry: bags.newEntry("A new bag", needs: "Type the bag's name first.") { draft.container = $0 },
                             tools: bags.tools, ring: ring(.bag)) { picked in
                        draft.container = picked
                        // A new bag: the old bag's pocket is not one of its (0.69).
                        if !model.library.pockets(bag: picked).contains(where: { normName($0) == normName(Library.usualPocket(draft)) }) {
                            Library.setUsualPocket(&draft, "")
                        }
                    }
                        .keyed(.bag)
                    // Its usual pocket (0.69), when that bag has pockets: "Backpack · Front pocket".
                    let pockets = drop("pockets", bag: draft.container, chosen: Library.usualPocket(draft),
                                       words: "the \(jsTrim(draft.container))\u{2019}s pockets")
                    if !pockets.rows.isEmpty {
                        DropDown(title: "Pocket", options: pockets.options, selected: Library.usualPocket(draft),
                                 id: "thing-pocket", blank: "Just in the bag", same: { normName($0) == normName($1) },
                                 newEntry: pockets.newEntry("A new pocket", needs: "Type the pocket's name first.") { Library.setUsualPocket(&draft, $0) },
                                 tools: pockets.tools, ring: ring(.pocket)) {
                            Library.setUsualPocket(&draft, $0)
                        }
                            .keyed(.pocket)
                    }
                    let steps = drop("phases", chosen: draft.phase, words: "your \u{201C}When\u{201D} steps")
                    DropDown(title: "When", options: steps.options, selected: draft.phase, id: "thing-when",
                             newEntry: steps.newEntry("A new step", needs: "Type the step first.") { draft.phase = $0 },
                             tools: steps.tools, ring: ring(.when)) { draft.phase = $0 }
                        .keyed(.when)
                    labelled("Weight, in grams (0 = not known)") {
                        field(Binding(get: { weightText }, set: { weightText = $0; weightProblem = "" }), "0", "thing-weight", .weight)
                        if !weightProblem.isEmpty {
                            Text(weightProblem).font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(AppSection.actions.color)
                                .accessibilityIdentifier("thing-weight-problem")
                        }
                    }
                    .keyed(.weight)
                    // Inside — a pouch or a kit and what it holds; or the kit it is in (0.70).
                    ThingKitPart(thingId: current, draft: $kit, ringed: at)
                        .keyed(.kitAdd)
                    // Brand, colour and notes — for bags above all (his bag page, 2026-09-26),
                    // and for any thing: the web app's editor has had them all along.
                    labelled("Brand") { field($draft.manufacturer, "e.g. Patagonia", "thing-brand", .brand) }
                        .keyed(.brand)
                    labelled("Colour") { field($draft.color, "e.g. Black", "thing-colour", .colour) }
                        .keyed(.colour)
                    // The condition's ID is what is stored; a thing still holding a label
                    // (stored by the table before 0.62) lights its pill all the same.
                    let condition = model.library.conditionId(for: draft.condition) ?? draft.condition
                    let wear = drop("conditions", chosen: condition, words: "your conditions")
                    DropDown(title: "Condition", options: [("", "Not said")] + wear.options,
                             selected: condition, id: "thing-condition",
                             newEntry: wear.newEntry("A new condition", needs: "Type the condition first.") { draft.condition = $0 },
                             tools: wear.tools, ring: ring(.condition)) { draft.condition = $0 }
                        .keyed(.condition)
                    careFields
                    // On a plane, and Valid until — what Check before you go reads (his ideas 4 and 5).
                    VStack(alignment: .leading, spacing: 8) {
                        HeadingBand(title: "On a plane", id: "thing-heading-plane")
                        Toggle(isOn: $draft.liquid) { flagWords("Liquid") }
                            .tint(AppSection.care.color)
                            #if os(macOS)
                            .focusRing(at == .liquid)
                            .simultaneousGesture(TapGesture().onEnded { land(.liquid, quiet: true) })
                            #endif
                            .accessibilityIdentifier("thing-liquid")
                        Toggle(isOn: $draft.restricted) { flagWords("Not allowed in the cabin") }
                            .tint(AppSection.care.color)
                            #if os(macOS)
                            .focusRing(at == .restricted)
                            .simultaneousGesture(TapGesture().onEnded { land(.restricted, quiet: true) })
                            #endif
                            .accessibilityIdentifier("thing-restricted")
                    }
                    .keyed(.liquid)
                    labelled("Valid until") { validUntil }
                        .keyed(.expiry)
                    if !problem.isEmpty {
                        Text(problem).font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .accessibilityIdentifier("thing-problem")
                    }
                    Text("A change here reaches every template it is on. Past trips keep what they were packed with.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    deleteThing
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            #if os(macOS)
            // The field the keys reach is brought into sight.
            .onChange(of: at) { _, f in
                // Only the keys scroll: a click is on what is already in sight (a pill clicked
                // scrolled the page under the next click — GitHub's Mac, 7 Oct 2026).
                if keyHome.quiet { keyHome.quiet = false; return }
                guard let f else { return }
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(ThingEditor.scrollKey(f)) }
            }
            #endif
            }
            #if os(macOS)
            keysLine
            #endif
        }
        .background(Theme.bg.ignoresSafeArea())
        // A bag's own page, from a refusal in Usually packed in (0.69): it is removed there.
        .sheet(item: Binding(get: { bagPage.map { BagPageId(id: $0) } }, set: { bagPage = $0?.id })) { b in
            BagDetail(bagId: b.id).environmentObject(model)
        }
        .onAppear {
            if let id = shown { load(id) }
            #if os(macOS)
            startKeys()
            #endif
        }
        #if os(macOS)
        .onDisappear { stopKeys() }
        .background(WindowReader { w in
            keyHome.window = w
            keyHome.page.window = w
        })
        .environment(\.dropDownKeys, keyHome.drop)
        .onChange(of: typing) { old, now in typed(from: old, to: now) }
        .onChange(of: draft.expiry) { _, now in expiryText = now; expiryProblem = "" }
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thing-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    /// Fills the page from the thing — on opening, and on the Mac when ⌘↓ ⌘↑ go on.
    private func load(_ id: String) {
        if let it = model.library.items.first(where: { $0.id == id }) {
            draft = it
            weightText = amountText(it.weight)
            careEvery = it.maintenance?.intervalDays ?? 0
            careNotes = it.maintenance?.notes ?? ""
        }
        onLists = Set(model.library.memberships.filter { $0.itemId == id }.map(\.templateId))
        var now: [String: String] = [:]
        for t in onLists { now[t] = model.library.thingSection(itemId: id, templateId: t) }
        sections = now
        sectionsAtOpen = now
        newSections = [:]
        sectionEdits = [:]
        choiceLists = [:]
        kit = KitDraft(model.library, thingId: id)     // what it holds, or its kit (0.70)
        problem = ""
        weightProblem = ""
        askingToDelete = false
        expiryText = draft.expiry
        expiryProblem = ""
    }

    private func toggleTemplate(_ id: String) {
        if onLists.contains(id) { onLists.remove(id) } else { onLists.insert(id) }
    }

    /// The ring of a drop-down in focus (Mac): the page's orange.
    private func ring(_ f: ThingField) -> Color? {
        at == f ? AppSection.care.color : nil
    }

    /// A heading in the editor — as large as the pill headings (his ask, 2026-09-27).
    /// Delete the thing — his ask (2026-09-27). Small, at the side, and it asks
    /// first. A bag is deleted on its own page, which asks where its things go.
    @ViewBuilder private var deleteThing: some View {
        let isBag = model.library.bags().contains { $0.id == current }
        // A thing being made (⌘N, Mac) is not there to delete: Cancel leaves it unmade.
        if !isBag && shown != nil {
            if askingToDelete {
                let lists = model.library.listsOf(itemId: current)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Delete \u{201C}\(draft.name)\u{201D}?")
                        .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(lists.isEmpty ? "It is on none of your templates. Trips you already packed keep it."
                         : "It leaves your \(BagDetail.names(lists)) template\(lists.count == 1 ? "" : "s"). Trips you already packed keep it.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Keep it") { askingToDelete = false }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                            .accessibilityIdentifier("thing-delete-no")
                        Spacer()
                        Button {
                            let id = current
                            dismiss()
                            model.change { _ = $0.deleteThing(id: id) }
                        } label: {
                            Text("Delete the thing").font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                                .background(Capsule().fill(AppSection.actions.color))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("thing-delete-yes")
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color, lineWidth: 1))
            } else {
                SmallDeleteButton(title: "Delete thing", id: "thing-delete") { askingToDelete = true }
            }
        }
    }

    /// Its Section on each template it is on — his ask (6 Oct 2026), to set a thing's
    /// section "already in this view": sections "give a visual structure to the packing".
    /// A section belongs to a template, so there is one drop-down per template ticked
    /// above (one ticked in this edit too), in the same order, each named for its
    /// template: "No section", that template's sections in its order, and at the foot
    /// "A new section". On a template twice, it is the first place's section (the
    /// template's own row sets any other). The pills above stay pills: several at once.
    @ViewBuilder private func sectionChoices(_ templates: [PackList]) -> some View {
        let ticked = templates.enumerated().filter { onLists.contains($0.element.id) }
        if !ticked.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(ticked, id: \.element.id) { pair in
                    sectionChoice(pair.element, n: pair.offset)
                        .keyed(.section(pair.element.id))
                }
            }
        }
    }

    private func sectionChoice(_ t: PackList, n: Int) -> some View {
        let typed = newSections[t.id] ?? ""
        // The template's sections as they will be once saved: renamed, in the new order,
        // a removed one still there to be struck out (0.68).
        let shown = model.library.sectionsAsEdited(templateId: t.id, sectionEdits[t.id] ?? SectionEdits())
        return DropDown(title: "Section on \(t.name)", heading: .title,
                        options: shown.map { ($0.id, $0.name) } + (typed.isEmpty ? [] : [(RowEditor.newSectionKey, typed)]),
                        selected: sections[t.id] ?? "", id: DropDownIds(stringLiteral: "thing-section-\(n)"),
                        tint: AppSection.templates.color, blank: "No section",
                        newEntry: DropDownNew(placeholder: "A new section", needs: "Type the section's name first.") {
                            newSection($0, on: t.id)
                        }, tools: sectionTools(t), ring: ring(.section(t.id))) { sections[t.id] = $0 }
    }

    /// Rename, move and remove a template's sections from its Section list here — his
    /// ask (7 Oct 2026, a picture of that list open): "I would like to be able to Rename,
    /// Change and Delete Sections from this here as well." Every change waits for Save, as
    /// "A new section" does, and is then written by Arrange's own functions
    /// (`Library.applySectionEdits`): a section renamed keeps its things, the order is the
    /// template's (what its page and a trip sorted by Section read), and a removed one's
    /// things stay on the template with no section.
    private func sectionTools(_ t: PackList) -> DropDownRowTools {
        let id = t.id
        // The one Section mechanism, shared with a template's row (0.69).
        return .sections(model.library, template: t, edits: sectionEdits[id] ?? SectionEdits(),
                         keep: { sectionEdits[id] = $0 },
                         removed: { value in if sections[id] == value { sections[id] = "" } })   // the thing goes to none, as its things will
    }

    /// A section typed at the foot of a template's list: one of that name already on
    /// the template is simply chosen; a new one waits for Save.
    private func newSection(_ typed: String, on templateId: String) {
        let name = jsTrim(typed)
        guard !name.isEmpty else { return }
        let have = model.library.templates.first { $0.id == templateId }?.sections ?? []
        if let there = have.first(where: { normName($0.name) == normName(name) }) {
            sections[templateId] = there.id
            newSections[templateId] = nil
        } else {
            newSections[templateId] = name
            sections[templateId] = RowEditor.newSectionKey
        }
    }

    /// Kept at home: chosen from his places, never typed (6 Oct 2026) — the first
    /// drop-down, which the others copy. "Not said" first, then his places in his order
    /// (Your choices), then the one the thing already names when it is none of his (from
    /// before 0.64, kept and ticked); at the foot "A new place", which joins Your choices
    /// so it is spelt one way everywhere. Its parts keep the names they had before the
    /// drop-down was made of it.
    private var keptAtHome: some View {
        // A new place joins Your choices on Save (0.69 — it used to join at once, and stayed
        // after Cancel); one he already has is simply chosen, in his own spelling.
        let places = drop("places", chosen: draft.storage, words: "your places")
        return DropDown(title: "Kept at home", options: places.options,
                 selected: draft.storage,
                 id: DropDownIds(field: "thing-storage", list: "thing-places", row: "thing-place", title: "thing-heading-kept"),
                 blank: "Not said", other: true, same: { normName($0) == normName($1) },
                 newEntry: places.newEntry("A new place", needs: "Type the place first.") { draft.storage = $0 },
                 tools: places.tools, ring: ring(.storage)) { draft.storage = $0 }
    }

    /// One of his lists as its drop-down here shows it, with the changes this page holds.
    private func drop(_ kind: String, bag: String = "", chosen: String, words: String, open: DropDownOpen? = nil) -> ChoiceDrop {
        let key = ThingEditor.choiceKey(kind, bag: bag)
        return ChoiceDrop(library: model.library, edits: choiceLists[key] ?? ChoiceEdits(kind: kind, bag: bag),
                          keep: { choiceLists[key] = $0 }, listWords: words, except: shown, chosen: chosen, open: open)
    }

    /// The page's key for one list's held changes: a bag's pockets by the bag.
    static func choiceKey(_ kind: String, bag: String = "") -> String {
        kind == "pockets" ? "pockets:\(normName(bag))" : kind
    }

    /// "Open the bag" under a refusal: its page, once the list has closed.
    private func openBag(_ name: String) {
        guard let id = model.library.bags().first(where: { normName($0.name) == normName(name) })?.id else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { bagPage = id }
    }

    /// Care: how often the thing is looked after, and what to do. Care listed only
    /// records that came from the web app — nothing in this app could make one (the
    /// spec pass, 5 Oct 2026). "Done today" on Care moves the next date on.
    @ViewBuilder private var careFields: some View {
        let standard = MAINTENANCE_INTERVALS.map { ($0.days, $0.days == 0 ? "None" : $0.label) }
        let options = standard + (standard.contains { $0.0 == careEvery } ? [] : [(careEvery, "Every \(careEvery) days")])
        VStack(alignment: .leading, spacing: 6) {
            DropDown(title: "Care", options: options.map { (String($0.0), $0.1) }, selected: String(careEvery),
                     id: "thing-care", ring: ring(.care)) { careEvery = Int($0) ?? 0 }
                .keyed(.care)
            TextField("What to do, e.g. Wax the leather", text: $careNotes, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).padding(.vertical, 11).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(at == .careNotes ? AppSection.care.color : Theme.line,
                                                                   lineWidth: at == .careNotes ? 2 : 1))
                .macFocused($typing, .careNotes)
                .accessibilityIdentifier("thing-care-notes")
                .keyed(.careNotes)
        }
    }

    /// "Usually packed in": every bag name, then the bag the thing names if it is
    /// none of those (so it is seen, lit), then "No bag" — LAST, so the built-in
    /// bags keep their places. It could not be set back to no bag at all (the spec
    /// pass, 5 Oct 2026). A bag named in other capitals is lit as the bag it is.
    /// The bags come as the drop-down shows them (0.69): by key and words, a bag added on
    /// this page by its key.
    static func bagChoices(_ bags: [(id: String, label: String)], current: String) -> (options: [(id: String, label: String)], selected: String) {
        let now = jsTrim(current)
        let same = bags.first { $0.id == current || $0.id.lowercased() == now.lowercased() }?.id
        var options = bags
        if !now.isEmpty, same == nil { options.append((id: current, label: now)) }
        options.append((id: "", label: "No bag"))
        return (options, now.isEmpty ? "" : (same ?? current))
    }

    /// A passport, an ID card, sun cream, medicine: the trip warns before it runs out.
    @ViewBuilder private var validUntil: some View {
        VStack(alignment: .leading, spacing: 8) {
            #if os(macOS)
            // The Mac (0.68): the date is TYPED — "2027-06-30", "30/6 27", "+6m", "+1y" —
            // in a field of its own, where the date picker stood; Add a date, Remove the
            // date and the quick spans stay as they were.
            HStack(spacing: 12) {
                expiryField.frame(width: 230)
                if draft.expiry.isEmpty { addDate } else { removeDate }
                Spacer(minLength: 0)
            }
            if !expiryProblem.isEmpty {
                Text(expiryProblem).font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(AppSection.actions.color)
                    .accessibilityIdentifier("thing-expiry-problem")
            }
            if !draft.expiry.isEmpty { expiryDistance; quickSpans }
            #else
            if draft.expiry.isEmpty {
                addDate
            } else {
                HStack(spacing: 12) {
                    DatePicker("", selection: Binding(get: { ThingEditor.date(draft.expiry) ?? Date() },
                                                      set: { draft.expiry = ThingEditor.ymd($0) }),
                               displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("thing-expiry")
                    Spacer(minLength: 8)
                    removeDate
                }
                expiryDistance
                quickSpans
            }
            #endif
            Text("The trip warns before it runs out \u{2014} a document (Documents & money) six months ahead.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Pill-sized, under a heading that is bigger (field test, 3 Oct 2026).
    private var addDate: some View {
        Button { draft.expiry = Today.local } label: {
            Text("Add a date").font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.care.color)
                .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                .overlay(Capsule().stroke(AppSection.care.color, lineWidth: 1.4))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("thing-expiry-add")
    }

    private var removeDate: some View {
        Button("Remove the date") { draft.expiry = "" }
            .buttonStyle(.plain).focusEffectDisabled()
            .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
            .accessibilityIdentifier("thing-expiry-clear")
    }

    /// How far away it is, in words, as the date changes — their field test (Oct 2026):
    /// "It didn't say 10 days. You have to calculate that yourself." Large, and red once
    /// it has run out. A text of its own, outside any button, so the Mac does not fold it
    /// away.
    private var expiryDistance: some View {
        let today = Today.local
        return Text(distanceWords(from: today, to: draft.expiry))
            .font(.system(.title3, weight: .bold))
            .foregroundStyle((daysBetween(today, draft.expiry) ?? 0) < 0 ? AppSection.actions.color : Theme.ink)
            .accessibilityIdentifier("thing-expiry-distance")
    }

    /// The usual spans in one tap, counted from today; the date above still picks an
    /// exact day. The one matching the date is filled in.
    private var quickSpans: some View {
        let today = Today.local
        return FlowRow(spacing: 8) {
            ForEach(Array(ThingEditor.quickSpans.enumerated()), id: \.offset) { n, span in
                let on = draft.expiry == addMonths(today, span.months)
                Button { draft.expiry = addMonths(today, span.months) } label: {
                    Text(span.label)
                        .font(.system(.subheadline, weight: on ? .semibold : .regular).monospacedDigit())
                        .foregroundStyle(on ? Color.white : AppSection.care.color)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                        .background(Capsule().fill(on ? AppSection.care.color : Theme.bg))
                        .overlay(Capsule().stroke(AppSection.care.color, lineWidth: 1.4))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("thing-expiry-quick-\(n)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    /// The quick choices under Valid until: sun cream lasts about a year once open,
    /// a passport five or ten.
    static let quickSpans: [(label: String, months: Int)] = [
        ("+1 month", 1), ("+6 months", 6), ("+1 year", 12), ("+5 years", 60), ("+10 years", 120),
    ]

    /// A switch's words — no explanation under them (his word, 6 Oct 2026: "Delete the
    /// explanations for liquid and not allowed in the cabin").
    private func flagWords(_ title: String) -> some View {
        Text(title).font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
    }

    private static func formatter() -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
    static func date(_ ymd: String) -> Date? { formatter().date(from: ymd) }
    static func ymd(_ d: Date) -> String { formatter().string(from: d) }

    /// A heading and its field, held together: 6 points apart (as a row of pills is
    /// under its heading), where the headings themselves are 22 apart.
    private func labelled<Content: View>(_ text: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HeadingBand(title: text, id: "thing-heading-\(text.prefix { $0.isLetter }.lowercased())")
            content()
        }
    }

    /// Notes grow downwards: a note written on site lands on a line of its own under
    /// what the thing already said (3 Oct 2026), and one line ran them together.
    private var notesField: some View {
        TextField("Anything worth remembering", text: $draft.note, axis: .vertical)
            .lineLimit(1...8)
            .textFieldStyle(.plain)
            .font(.system(.body)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).padding(.vertical, 11).frame(minHeight: Metrics.tap)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(at == .notes ? AppSection.care.color : Theme.line,
                                                               lineWidth: at == .notes ? 2 : 1))
            .macFocused($typing, .notes)
            .accessibilityIdentifier("thing-notes")
    }

    /// The notes its templates keep for it, under its own (spec 05, item 18): a row's
    /// note wins on its template, and a library from the web app keeps its notes
    /// there — Notes looked empty while a template said something. Changed on the
    /// template, so only shown here.
    @ViewBuilder private var rowNotes: some View {
        let notes = model.library.rowNotes(itemId: current)
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(notes.enumerated()), id: \.offset) { n, said in
                    Text("On the \(said.template) template: \(said.note)")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("thing-row-note-\(n)")
                }
            }
            .padding(.top, 2)
        }
    }

    private func field(_ text: Binding<String>, _ prompt: String, _ id: String, _ key: ThingField) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .font(.system(.body)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(at == key ? AppSection.care.color : Theme.line,
                                                               lineWidth: at == key ? 2 : 1))
            .macFocused($typing, key)
            .accessibilityIdentifier(id)
    }

    private func save() {
        if commit() { dismiss() }
    }

    /// Writes the page to the library. False — the page stays, and says why — when the
    /// weight, the date or the name stops it.
    @discardableResult private func commit() -> Bool {
        #if os(macOS)
        guard readExpiry() else { return false }
        #endif
        let it = shown.flatMap { id in model.library.items.first { $0.id == id } }
        // The thing is gone (deleted on the other device): the page just closes.
        if shown != nil && it == nil { dismiss(); return false }
        // The weight first, so a typo saves nothing (and says so). Untouched, the
        // stored weight stays exactly as it is, however many decimals it has.
        let weight = it.map { weightText == amountText($0.weight) } == true ? it?.weight : ThingEditor.readWeight(weightText)
        guard let grams = weight else {
            weightProblem = ThingEditor.weightSays
            return false
        }
        let itemId: String
        if let it {
            itemId = it.id
            if jsTrim(draft.name) != it.name {
                var ok = false
                model.change { ok = $0.renameThing(id: itemId, to: draft.name) }
                if !ok { problem = jsTrim(draft.name).isEmpty ? "A thing needs a name." : "You already have a thing called that."; return false }
            }
        } else {
            // A new thing (⌘N, Mac): made now, with its name; the rest follows below.
            var new: Item?
            model.change { new = $0.addThing(name: draft.name) }
            guard let new else {
                problem = jsTrim(draft.name).isEmpty ? "A thing needs a name." : "You already have a thing called that."
                return false
            }
            itemId = new.id
            shown = new.id
            made?(new.id)
        }
        problem = ""
        let d = draft
        let lists = onLists
        let every = careEvery, notes = jsTrim(careNotes)
        let chosen = sections, atOpen = sectionsAtOpen, typed = newSections, edited = sectionEdits
        let kitSays = kit
        let held = choiceLists
        var written = d
        model.change { lib in
            // A template's sections changed in its Section list here (0.68), first: the
            // thing's own choice below is made among them as they now are.
            for (templateId, edits) in edited.sorted(by: { $0.key < $1.key }) {
                _ = lib.applySectionEdits(templateId: templateId, edits)
            }
            // His lists changed in their drop-downs here (0.69): renamed, moved and new
            // entries first — the thing's own choices then follow them — removals last,
            // once the thing no longer says what it moved away from.
            let maps = lib.applyPageChoices(held)
            var page = d
            func follow(_ v: String, _ kind: String) -> String { Library.choiceValue(v, after: maps[kind] ?? [:]) }
            page.storage = follow(page.storage, "places")
            page.category = follow(page.category, "categories")
            page.ownedBy = follow(page.ownedBy, "owners")
            page.phase = follow(page.phase, "phases")
            page.condition = follow(page.condition, "conditions")
            let pocketsKey = ThingEditor.choiceKey("pockets", bag: page.container)
            Library.setUsualPocket(&page, follow(Library.usualPocket(page), pocketsKey))
            page.container = follow(page.container, "bags")
            written = page
            kitSays.save(&lib, thingId: itemId)      // what it holds, or taken out of its kit (0.70)
            _ = lib.updateThing(id: itemId) { thing in
                thing.storage = jsTrim(page.storage)
                thing.category = page.category
                thing.container = page.container
                thing.extra[USUAL_POCKET_KEY] = page.extra[USUAL_POCKET_KEY]
                thing.phase = page.phase
                thing.ownedBy = page.ownedBy
                thing.condition = page.condition
                thing.weight = grams
                thing.manufacturer = jsTrim(page.manufacturer)
                thing.color = jsTrim(page.color)
                thing.note = jsTrim(page.note)
                thing.liquid = page.liquid
                thing.restricted = page.restricted
                thing.expiry = page.expiry
                // The care record changes only when what is said here changed: its log
                // and last service stay as they were.
                let had = thing.maintenance
                if (had?.intervalDays ?? 0) != every || jsTrim(had?.notes ?? "") != notes {
                    var care = had ?? Maintenance()
                    care.intervalDays = every
                    care.notes = notes
                    thing.maintenance = normalizeMaintenance(care)
                }
            }
            for t in lib.templatesForThings() {
                _ = lib.setOnTemplate(itemId: itemId, templateId: t.id, on: lists.contains(t.id))
            }
            // Its section on each template it is on now — only where he changed it; the
            // model makes a typed one, and the trips still ahead follow, as after a row
            // is saved in the row editor.
            for t in lib.templatesForThings() where lists.contains(t.id) {
                let pick = chosen[t.id] ?? ""
                guard pick != (atOpen[t.id] ?? "") else { continue }
                let fresh = pick == RowEditor.newSectionKey
                _ = lib.setThingSection(itemId: itemId, templateId: t.id, section: fresh ? "" : pick,
                                        newSection: fresh ? (typed[t.id] ?? "") : "")
            }
            lib.applyPageRemovals(held, maps)
        }
        // The page now says what was written (⌘N's next thing starts from it).
        draft.storage = written.storage; draft.category = written.category; draft.ownedBy = written.ownedBy
        draft.phase = written.phase; draft.condition = written.condition; draft.container = written.container
        Library.setUsualPocket(&draft, Library.usualPocket(written))
        choiceLists = [:]
        return true
    }

    /// The weight as typed: on the Mac kilos may carry their unit too ("1,2 kg" = 1200 g,
    /// 0.68); the iPhone reads grams as before.
    private static func readWeight(_ typed: String) -> Double? {
        #if os(macOS)
        return readGrams(typed)
        #else
        return readAmount(typed)
        #endif
    }

    #if os(macOS)
    private static let weightSays = "The weight must be grams, like 250 or 12,5 — or kilos with their unit, like 1,2 kg."
    #else
    private static let weightSays = "The weight must be a number of grams, like 250 or 12,5."
    #endif
}

extension View {
    /// The thing page's text field tied to the field in focus — the Mac's keys only; the
    /// iPhone's fields are as they were.
    @ViewBuilder func macFocused(_ binding: FocusState<ThingField?>.Binding, _ f: ThingField) -> some View {
        #if os(macOS)
        focused(binding, equals: f)
        #else
        self
        #endif
    }

    /// Where the Mac's keys scroll to for this field (`ThingEditor.scrollKey`).
    @ViewBuilder func keyed(_ f: ThingField) -> some View {
        #if os(macOS)
        id(ThingEditor.scrollKey(f))
        #else
        self
        #endif
    }
}

#if os(macOS)
/// What the page keeps for the keys, by reference — none of it is drawn.
final class ThingKeyHome {
    weak var window: NSWindow?
    let monitor = KeyMonitor()
    let page = ThingKeys.Page()
    let drop = DropDownKeys()
    /// The next focus move came from a click: no scrolling.
    var quiet = false
    /// The letters typed on the template pills, and when the last came.
    var ahead = ""
    var aheadAt = Date.distantPast
}

// MARK: - The Mac's keys (0.68)

extension ThingEditor {
    /// The id a field's block scrolls by.
    static func scrollKey(_ f: ThingField) -> String {
        switch f {
        case .section(let t): return "key-section-\(t)"
        case .liquid, .restricted: return "key-plane"
        case .kitTakenOut, .kitAdd, .kitCheck: return "key-kit"
        case .jump: return "key-jump"
        default: return "key-\(f)"
        }
    }

    /// Every field, in his reading order — the order Tab walks.
    fileprivate func fieldOrder() -> [ThingField] {
        var out: [ThingField] = [.name, .notes, .category]
        if !model.library.ownerChoices().isEmpty { out.append(.owner) }
        let templates = self.templates
        if !templates.isEmpty { out.append(.templates) }
        for t in templates where onLists.contains(t.id) { out.append(.section(t.id)) }
        out += [.storage, .bag]
        if !model.library.pockets(bag: draft.container).isEmpty { out.append(.pocket) }   // 0.69
        out += [.when, .weight]
        // The kit part (0.70), as it shows: a thing in a kit, or one that may hold things.
        if !kit.none {
            if kit.holder != nil { out.append(.kitTakenOut) } else {
                out.append(.kitAdd)
                if !kit.contents.isEmpty { out.append(.kitCheck) }
            }
        }
        out += [.brand, .colour, .condition, .care, .careNotes, .liquid, .restricted, .expiry]
        return out
    }

    /// A field's control id — what the line at the foot names as its value, for the tests.
    fileprivate func fieldId(_ f: ThingField) -> String {
        switch f {
        case .name: return "thing-name"
        case .notes: return "thing-notes"
        case .category: return "thing-category"
        case .owner: return "thing-owner"
        case .templates: return "thing-lists"
        case .section(let t): return "thing-section-\(templates.firstIndex { $0.id == t } ?? -1)"
        case .storage: return "thing-storage"
        case .bag: return "thing-bag"
        case .pocket: return "thing-pocket"
        case .kitTakenOut: return "thing-kit-taken-out"
        case .kitAdd: return "thing-kit-add"
        case .kitCheck: return "thing-kit-check"
        case .when: return "thing-when"
        case .weight: return "thing-weight"
        case .brand: return "thing-brand"
        case .colour: return "thing-colour"
        case .condition: return "thing-condition"
        case .care: return "thing-care"
        case .careNotes: return "thing-care-notes"
        case .liquid: return "thing-liquid"
        case .restricted: return "thing-restricted"
        case .expiry: return "thing-expiry"
        case .jump: return "thing-jump"
        }
    }

    /// A field's name, as its heading says it.
    fileprivate func fieldName(_ f: ThingField) -> String {
        switch f {
        case .name: return "Name"
        case .notes: return "Notes"
        case .category: return "Kind of thing"
        case .owner: return "Whose it is"
        case .templates: return "On these templates"
        case .section(let t): return "Section on \(templates.first { $0.id == t }?.name ?? "")"
        case .storage: return "Kept at home"
        case .bag: return "Usually packed in"
        case .pocket: return "Pocket"
        case .kitTakenOut: return "Taken out for now"
        case .kitAdd: return "Add from your things"
        case .kitCheck: return "Check before each trip"
        case .when: return "When"
        case .weight: return "Weight"
        case .brand: return "Brand"
        case .colour: return "Colour"
        case .condition: return "Condition"
        case .care: return "Care"
        case .careNotes: return "What to do"
        case .liquid: return "Liquid"
        case .restricted: return "Not allowed in the cabin"
        case .expiry: return "Valid until"
        case .jump: return "Jump to field"
        }
    }

    /// The field of a drop-down's id (a click on it).
    fileprivate func field(forId id: String) -> ThingField? {
        fieldOrder().first { fieldId($0) == id }
    }

    /// The keys of the field in focus, in a few words — the line at the page's foot.
    fileprivate func keysWords(_ f: ThingField?) -> String {
        if let open = listOpen {
            return open.hasPrefix("thing-section-")
                ? "↑ ↓ move · Tab to its pen, arrows, Remove · Space presses · Return chooses · Esc closes"
                : "↑ ↓ move · Return chooses · type to jump · Esc closes the list"
        }
        guard let f else { return "Tab goes to the fields · Return saves · ⌘N saves and starts a new thing · ⌘J jumps to a field" }
        switch f {
        case .notes: return "Return starts a new line · Tab next · ⌘S saves"
        case .careNotes: return "Return starts a new line · Tab next · ⌘S saves"
        case .weight: return "grams, or kilos as 1,2 kg · Tab next · Return saves"
        case .expiry: return "a date, 2027-06-30 or 30/6 27, or +6m, +1y · Return saves"
        case .jump: return "type part of a field's name · Return goes there · Esc closes"
        case .templates: return "← → move · Space turns it on or off · type to jump · Tab next"
        case .liquid, .restricted, .kitTakenOut, .kitCheck: return "Space turns it on or off · Tab next · Return saves"
        case .kitAdd: return "Space opens or closes the list of your things · Tab next · Return saves"
        case .storage: return "type to pick, or a new place · Space opens · Tab next · Return saves"
        case .section: return "type to pick, or a new section · Space opens · Tab next · Return saves"
        case .category, .owner, .bag, .pocket, .when, .condition, .care:
            return "type to pick · Space opens · Tab next · Return saves"
        case .name, .brand, .colour: return "type · Tab next · Return saves"
        }
    }

    /// The line at the page's foot: the field in focus, and its keys — nothing to
    /// remember (the concept: "a line at the foot of the page names its keys").
    fileprivate var keysLine: some View {
        let name = jumping ? fieldName(.jump) : at.map(fieldName) ?? "Keys"
        let keys = !keyNote.isEmpty ? keyNote : keysWords(jumping ? .jump : at)
        // The field's name says which field it is by its control's id too —
        // `thing-keys-at-<id>`, for the tests (an id is never shown or spoken).
        let id = jumping ? fieldId(.jump) : at.map(fieldId) ?? "none"
        return HStack(spacing: 8) {
            Text(name).font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.care.color)
                .lineLimit(1).fixedSize()
                .accessibilityIdentifier("thing-keys-at-\(id)")
            Text(keys).font(.system(.footnote)).foregroundStyle(Theme.muted)
                .lineLimit(1).truncationMode(.tail)
                .accessibilityIdentifier("thing-keys")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .background(Theme.bg)
        .overlay(alignment: .top) { Theme.line.frame(height: 1) }
    }

    /// The ⌘J box: type part of a field's name, Return goes there.
    fileprivate var jumpBox: some View {
        let hit = jumpMatches().first
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("Jump to field").font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.care.color)
                TextField("Type part of its name", text: $jumpText)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppSection.care.color, lineWidth: 2))
                    .focused($typing, equals: .jump)
                    .accessibilityIdentifier("thing-jump")
            }
            Text(jumpText.isEmpty ? "Return goes to the field named" : hit.map { "Return goes to \(fieldName($0))" } ?? "No field is called that")
                .font(.system(.footnote)).foregroundStyle(hit == nil && !jumpText.isEmpty ? AppSection.actions.color : Theme.muted)
                .accessibilityIdentifier("thing-jump-match")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 10)
    }

    /// The fields whose name has what was typed: a word starting with it first ("wei" →
    /// Weight, "val" → Valid until), then anywhere in the name; in the page's order.
    fileprivate func jumpMatches() -> [ThingField] {
        let q = jumpText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let order = fieldOrder()
        let names = order.map { fieldName($0).lowercased() }
        let starts = order.indices.filter { i in
            names[i].hasPrefix(q) || names[i].split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains { $0.hasPrefix(q) }
        }
        let inside = order.indices.filter { !starts.contains($0) && names[$0].contains(q) }
        return (starts + inside).map { order[$0] }
    }

    // MARK: Focus

    /// Puts the page's focus on a field: ringed, scrolled to, and — a text field — given
    /// the window's keys, its words selected so typing replaces them (Notes: the cursor
    /// at the end, so nothing is lost). `whole: false` puts the cursor at the end.
    fileprivate func land(_ f: ThingField?, whole: Bool = true, quiet: Bool = false) {
        if at == .expiry, f != .expiry { readExpiry() }
        keyHome.quiet = quiet && f != at
        keyNote = ""
        at = f
        if f == .templates, pillAt == nil {
            pillAt = templates.firstIndex { onLists.contains($0.id) } ?? 0
        }
        if let f, f.isText {
            typing = f
            let atEnd = !whole || f == .notes || f == .careNotes
            // Once the field really has the keys (a turn or two of the run loop).
            DispatchQueue.main.async { DispatchQueue.main.async { selectWords(of: f, atEnd: atEnd) } }
        } else {
            typing = nil
        }
    }

    private func selectWords(of f: ThingField, atEnd: Bool) {
        guard at == f || (jumping && f == .jump),
              let editor = keyHome.window?.firstResponder as? NSTextView else { return }
        if atEnd {
            editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        } else {
            editor.selectAll(nil)
        }
    }

    /// A click into a text field moves the page's focus with it; a text field left for
    /// nothing in particular takes the ring with it.
    fileprivate func typed(from old: ThingField?, to now: ThingField?) {
        if old == .expiry, now != .expiry { readExpiry() }
        if let now, now != .jump, now != at { keyNote = ""; keyHome.quiet = true; at = now }
        if now == nil, at?.isText == true, !jumping { at = nil }
    }

    /// Tab (1) and Shift-Tab (−1): the next field in his order, round to the first.
    fileprivate func move(_ dir: Int) {
        let order = fieldOrder()
        guard !order.isEmpty else { return }
        if let at, let n = order.firstIndex(of: at) {
            land(order[(n + dir + order.count) % order.count])
        } else if case .section = at, let k = order.firstIndex(of: .storage) {
            // A Section whose template was just turned off: on from where it stood.
            land(order[dir > 0 ? k : max(k - 1, 0)])
        } else {
            land(dir > 0 ? order[0] : order[order.count - 1])
        }
    }

    // MARK: Commands

    fileprivate func startKeys() {
        let home = keyHome
        home.drop.changed = { id in listOpen = id }
        home.drop.clicked = { id in if let f = field(forId: id) { land(f, quiet: true) } }
        home.monitor.start { e in key(e) }
        home.page.save = { save() }
        home.page.saveAndNew = { saveAndNew() }
        home.page.step = { step($0) }
        home.page.canStep = order != nil
        home.page.jump = { openJump() }
        ThingKeys.shared.add(home.page)
        // The page opens with the cursor in the name, at its end.
        DispatchQueue.main.async { land(.name, whole: false) }
    }

    fileprivate func stopKeys() {
        keyHome.monitor.stop()
        ThingKeys.shared.remove(keyHome.page)
    }

    /// ⌘N: saves, then a new thing's page with this one's Kind of thing, Whose it is,
    /// Kept at home, Usually packed in, When and templates (his answer, 7 Oct 2026) —
    /// things come in groups, five dive things kept in one place — the cursor in Name.
    fileprivate func saveAndNew() {
        let was = draft
        let lists = onLists
        guard commit() else { return }
        var fresh = newItem(name: "")
        fresh.category = was.category
        fresh.ownedBy = was.ownedBy
        fresh.storage = was.storage
        fresh.container = was.container
        fresh.phase = was.phase
        shown = nil
        draft = fresh
        weightText = ""
        careEvery = 0
        careNotes = ""
        onLists = lists
        let none = Dictionary(uniqueKeysWithValues: lists.map { ($0, "") })
        sections = none
        sectionsAtOpen = none
        newSections = [:]
        sectionEdits = [:]
        choiceLists = [:]
        kit = KitDraft()
        problem = ""
        weightProblem = ""
        askingToDelete = false
        expiryText = ""
        expiryProblem = ""
        land(.name)
    }

    /// ⌘↓ (1) and ⌘↑ (−1): saves, then the next or previous thing of the list the page
    /// came from, the cursor on the same field — "all weights" is one field after another.
    /// The list as it stood when the page first went on (`walk`; before that, before this
    /// save): a thing that leaves it by being filled in (the table filtered to No weight)
    /// keeps its place, so ⌘↓ leads on from it and ⌘↑ comes back to it. A thing not in it
    /// (made here with ⌘N) takes the list as it is after the save.
    fileprivate func step(_ dir: Int) {
        guard let order else { return }
        let before = walk ?? order()
        guard commit(), let id = shown else { return }
        var list = before
        if !list.contains(id) { list = order() }
        walk = list
        guard let n = list.firstIndex(of: id) else {
            keyNote = "This thing is not in the list the page came from."
            return
        }
        let alive = Set(model.library.items.map(\.id))
        var k = n + dir
        while list.indices.contains(k), !alive.contains(list[k]) { k += dir }
        guard list.indices.contains(k) else {
            keyNote = dir > 0 ? "Saved. That was the last thing in the list." : "Saved. That was the first thing in the list."
            return
        }
        let keep = at
        shown = list[k]
        load(list[k])
        // The same field on the next page — a Section of a template it is not on: the pills.
        if let keep, fieldOrder().contains(keep) { land(keep) } else { land(keep == nil ? nil : .templates) }
    }

    fileprivate func openJump() {
        beforeJump = at
        jumpText = ""
        jumping = true
        DispatchQueue.main.async { typing = .jump }
    }

    fileprivate func closeJump(go f: ThingField?) {
        jumping = false
        jumpText = ""
        land(f ?? beforeJump)
    }

    /// Reads Valid until as typed; false (and says how to write it) when it is no date.
    @discardableResult fileprivate func readExpiry() -> Bool {
        let typed = jsTrim(expiryText)
        if typed == draft.expiry { expiryProblem = ""; return true }
        guard let ymd = readDate(typed, today: Today.local) else {
            expiryProblem = "Not a date: type 2027-06-30 or 30/6 27, or +6m, +1y."
            return false
        }
        draft.expiry = ymd
        expiryText = ymd
        expiryProblem = ""
        return true
    }

    /// The Mac's date field under Valid until.
    fileprivate var expiryField: some View {
        TextField("2027-06-30, 30/6 27 or +6m", text: Binding(get: { expiryText }, set: { now in
            // Only words that changed clear the line: the Mac hands the field's words back
            // as it is left, which wiped "Not a date" the moment it was said (GitHub's Mac).
            guard now != expiryText else { return }
            expiryText = now
            expiryProblem = ""
        }))
            .textFieldStyle(.plain)
            .font(.system(.body).monospacedDigit()).foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(at == .expiry ? AppSection.care.color : Theme.line,
                                                               lineWidth: at == .expiry ? 2 : 1))
            .focused($typing, equals: .expiry)
            .accessibilityIdentifier("thing-expiry")
    }

    // MARK: The keys

    /// Every key pressed while the page is open passes here first. Answers nil for a key
    /// the page took, the key itself for one the window should have.
    fileprivate func key(_ e: NSEvent) -> NSEvent? {
        guard let mine = keyHome.window else { return e }
        let drop = keyHome.drop
        // Keys for this page only: its window, or the list one of its drop-downs has open.
        guard e.window === mine || drop.open != nil else { return e }
        let mods = e.keyModifiers
        let code = e.keyCode

        // The page's commands, from anywhere on it — the Thing menu's keys.
        if mods == .command {
            let letter = e.charactersIgnoringModifiers?.lowercased() ?? ""
            let command: (() -> Void)?
            switch (letter, code) {
            case ("s", _): command = { save() }
            case ("n", _): command = { saveAndNew() }
            case ("j", _): command = { openJump() }
            case (_, KeyCode.down): command = order == nil ? nil : { step(1) }
            case (_, KeyCode.up): command = order == nil ? nil : { step(-1) }
            default: command = nil
            }
            guard let command else { return e }
            if let open = drop.open { _ = drop.answer[open]?(.close) }
            if jumping { jumping = false }
            command()
            return nil
        }

        // ⌘J's box: Return goes, Esc closes; the rest is typing.
        if jumping {
            switch code {
            case KeyCode.escape: closeJump(go: nil)
            case KeyCode.returnKey, KeyCode.enter:
                if let hit = jumpMatches().first { closeJump(go: hit) }
            case KeyCode.tab: break
            default: return e
            }
            return nil
        }

        // An open list: the arrows, the letters, Return and Esc are the list's.
        if let open = drop.open, let answer = drop.answer[open] {
            // A list opened by a CLICK keeps its keys as it always had them (its foot's field
            // takes them: GitHub's Mac, 7 Oct 2026, "could not type into thing-place-new"),
            // and so does a Section's name clicked into — all but Esc, which leaves it.
            if !drop.openedByKeys || drop.typingInList {
                if code == KeyCode.escape { _ = answer(.close); return nil }
                return e
            }
            switch code {
            case KeyCode.escape: _ = answer(.close)
            case KeyCode.returnKey, KeyCode.enter: _ = answer(.choose)
            case KeyCode.down: _ = answer(.down)
            case KeyCode.up: _ = answer(.up)
            case KeyCode.delete: _ = answer(.back)
            case KeyCode.space: _ = answer(.space)
            case KeyCode.tab:
                // A Section's tools first; past them the list closes and Tab goes on.
                let by = mods.contains(.shift) ? -1 : 1
                if answer(.tab(by)) { return nil }
                _ = answer(.close)
                move(by)
            default:
                guard mods.subtracting(.shift).isEmpty, let words = e.typedWords else { return e }
                _ = answer(.letters(words))
            }
            return nil
        }
        guard e.window === mine else { return e }

        switch code {
        case KeyCode.tab:
            guard mods.subtracting(.shift).isEmpty else { return e }
            move(mods.contains(.shift) ? -1 : 1)
            return nil
        case KeyCode.returnKey, KeyCode.enter:
            guard mods.isEmpty else { return e }
            // Notes are many lines: Return starts a new one there (his answer, 7 Oct 2026) —
            // and in Care's What to do too (his follow-up the same day).
            if at == .notes || at == .careNotes, let editor = mine.firstResponder as? NSTextView {
                editor.insertNewlineIgnoringFieldEditor(nil)
                return nil
            }
            save()
            return nil
        default:
            break
        }

        guard let f = at, mods.subtracting(.shift).isEmpty else { return e }
        if f.isList, let answer = drop.answer[fieldId(f)] {
            switch code {
            case KeyCode.space, KeyCode.down: _ = answer(.open)
            case KeyCode.up, KeyCode.left, KeyCode.right, KeyCode.delete: break
            default:
                guard let words = e.typedWords else { return e }
                _ = answer(.letters(words))
            }
            return nil
        }
        switch f {
        case .templates:
            return pillKey(e)
        case .liquid, .restricted:
            guard code == KeyCode.space else { return e }
            if f == .liquid { draft.liquid.toggle() } else { draft.restricted.toggle() }
            return nil
        case .kitTakenOut, .kitAdd, .kitCheck:
            guard code == KeyCode.space else { return e }
            switch f {
            case .kitTakenOut: kit.takenOut.toggle()
            case .kitCheck: kit.check.toggle()
            default: kit.picking.toggle()
            }
            return nil
        default:
            return e
        }
    }

    /// On these templates: ← → move along the pills, Space turns the one lit on or off,
    /// letters jump to the first template whose name starts so.
    private func pillKey(_ e: NSEvent) -> NSEvent? {
        let list = templates
        guard !list.isEmpty else { return e }
        let n = min(max(pillAt ?? 0, 0), list.count - 1)
        switch e.keyCode {
        case KeyCode.left: pillAt = max(n - 1, 0)
        case KeyCode.right: pillAt = min(n + 1, list.count - 1)
        case KeyCode.space: toggleTemplate(list[n].id)
        case KeyCode.up, KeyCode.down, KeyCode.delete: break
        default:
            guard let words = e.typedWords else { return e }
            let now = Date()
            keyHome.ahead = now.timeIntervalSince(keyHome.aheadAt) <= 1 ? keyHome.ahead + words : words
            keyHome.aheadAt = now
            let typed = keyHome.ahead.lowercased()
            if let hit = list.firstIndex(where: { $0.name.lowercased().hasPrefix(typed) }) { pillAt = hit }
        }
        return nil
    }
}
#endif
