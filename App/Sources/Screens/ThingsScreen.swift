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
        let shown = all.filter { (!noListOnly || $0.templates.isEmpty) && (q.isEmpty || normName($0.item.name).contains(q)) }
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
                                thingRow(row, n: n).id("just-added-\(row.item.id)")
                            }
                            if !rest.isEmpty { listHeading("A–Z", id: "things-rest") }
                        }
                        ForEach(Array(rest.enumerated()), id: \.element.item.id) { n, row in
                            thingRow(row, n: fresh.count + n)
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
            ThingEditor(itemId: e.id).environmentObject(model)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("things-detail")
        .onAppear { if query.isEmpty, !searching.isEmpty { query = searching } }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    private static let top = "things-top"

    private func thingRow(_ row: (item: Item, templates: [String]), n: Int) -> some View {
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
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        .accessibilityIdentifier("thing-row-\(n)")
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
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
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

    var body: some View {
        let templates = model.library.templatesForThings()
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
        let owners = model.library.ownerChoices()          // each once (his screenshot, 2026-09-26)
        let bag = ThingEditor.bagChoices(model.library.bagNames(), current: draft.container)
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
            KeyboardAwayScroll {
                // A field sits right under its heading, and the space goes BETWEEN the
                // headings (his screenshot, 2026-09-28: "put the Bike field much nearer
                // its heading, the same goes for everything").
                VStack(alignment: .leading, spacing: 12) {
                    labelled("Name") { field($draft.name, "Name", "thing-name") }
                    // Notes right under the name — his ask (4 Oct 2026): "please put the
                    // notes field immediately under the name".
                    labelled("Notes") {
                        notesField
                        rowNotes
                    }
                    // The order is his (6 Oct 2026): what it is and whose, the templates it is on,
                    // where it lives and goes and when, the details, and last what a flight and a
                    // date ask of it.
                    // Every pick-one list here is a drop-down (his word, 6 Oct 2026: "Can we please
                    // make these kinds of drop-downs everywhere?"); a kind of thing from the web app
                    // that is none of the app's is shown on a row of its own.
                    DropDown(title: "Kind of thing", options: CATEGORIES.map { ($0, $0) }, selected: draft.category,
                             id: "thing-category", other: true) { draft.category = $0 }
                    if !owners.isEmpty {
                        // No owner means each has one of their own — his words (4 Oct 2026):
                        // "Replace 'Nobody's in particular' with 'Both have one'".
                        DropDown(title: "Whose it is", options: [("", OWNER_BOTH)] + owners.map { ($0, $0) },
                                 selected: draft.ownedBy, id: "thing-owner", other: true) { draft.ownedBy = $0 }
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
                          id: "thing-lists", tint: AppSection.templates.color, heading: .band) { id in
                        if onLists.contains(id) { onLists.remove(id) } else { onLists.insert(id) }
                    }
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
                    DropDown(title: "Usually packed in", options: bag.options.map { ($0.id, $0.label) },
                             selected: bag.selected, id: "thing-bag") { draft.container = $0 }
                    DropDown(title: "When", options: PHASES.map { ($0.id, $0.label) }, selected: draft.phase,
                             id: "thing-when") { draft.phase = $0 }
                    labelled("Weight, in grams (0 = not known)") {
                        field(Binding(get: { weightText }, set: { weightText = $0; weightProblem = "" }), "0", "thing-weight")
                        if !weightProblem.isEmpty {
                            Text(weightProblem).font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(AppSection.actions.color)
                                .accessibilityIdentifier("thing-weight-problem")
                        }
                    }
                    // Brand, colour and notes — for bags above all (his bag page, 2026-09-26),
                    // and for any thing: the web app's editor has had them all along.
                    labelled("Brand") { field($draft.manufacturer, "e.g. Patagonia", "thing-brand") }
                    labelled("Colour") { field($draft.color, "e.g. Black", "thing-colour") }
                    // The condition's ID is what is stored; a thing still holding a label
                    // (stored by the table before 0.62) lights its pill all the same.
                    DropDown(title: "Condition", options: [("", "Not said")] + ITEM_CONDITIONS.map { ($0.id, $0.label) },
                             selected: model.library.conditionId(for: draft.condition) ?? draft.condition,
                             id: "thing-condition") { draft.condition = $0 }
                    careFields
                    // On a plane, and Valid until — what Check before you go reads (his ideas 4 and 5).
                    VStack(alignment: .leading, spacing: 8) {
                        HeadingBand(title: "On a plane", id: "thing-heading-plane")
                        Toggle(isOn: $draft.liquid) { flagWords("Liquid") }
                            .tint(AppSection.care.color)
                            .accessibilityIdentifier("thing-liquid")
                        Toggle(isOn: $draft.restricted) { flagWords("Not allowed in the cabin") }
                            .tint(AppSection.care.color)
                            .accessibilityIdentifier("thing-restricted")
                    }
                    labelled("Valid until") { validUntil }
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
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            if let it = model.library.items.first(where: { $0.id == itemId }) {
                draft = it
                weightText = amountText(it.weight)
                careEvery = it.maintenance?.intervalDays ?? 0
                careNotes = it.maintenance?.notes ?? ""
            }
            onLists = Set(model.library.memberships.filter { $0.itemId == itemId }.map(\.templateId))
            for t in onLists { sections[t] = model.library.thingSection(itemId: itemId, templateId: t) }
            sectionsAtOpen = sections
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thing-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    /// A heading in the editor — as large as the pill headings (his ask, 2026-09-27).
    /// Delete the thing — his ask (2026-09-27). Small, at the side, and it asks
    /// first. A bag is deleted on its own page, which asks where its things go.
    @ViewBuilder private var deleteThing: some View {
        let isBag = model.library.bags().contains { $0.id == itemId }
        if !isBag {
            if askingToDelete {
                let lists = model.library.listsOf(itemId: itemId)
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
                            let id = itemId
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
                }
            }
        }
    }

    private func sectionChoice(_ t: PackList, n: Int) -> some View {
        let typed = newSections[t.id] ?? ""
        return DropDown(title: "Section on \(t.name)", heading: .title,
                        options: t.sections.map { ($0.id, $0.name) } + (typed.isEmpty ? [] : [(RowEditor.newSectionKey, typed)]),
                        selected: sections[t.id] ?? "", id: DropDownIds(stringLiteral: "thing-section-\(n)"),
                        tint: AppSection.templates.color, blank: "No section",
                        newEntry: DropDownNew(placeholder: "A new section", needs: "Type the section's name first.") {
                            newSection($0, on: t.id)
                        }) { sections[t.id] = $0 }
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
        DropDown(title: "Kept at home", options: model.library.storagePlaces().map { ($0, $0) },
                 selected: draft.storage,
                 id: DropDownIds(field: "thing-storage", list: "thing-places", row: "thing-place", title: "thing-heading-kept"),
                 blank: "Not said", other: true, same: { normName($0) == normName($1) },
                 newEntry: DropDownNew(placeholder: "A new place", needs: "Type the place first.") { typed in
                     // Made in Your choices — or, when he already has it, his own spelling of it.
                     var made: String?
                     model.change { made = $0.addPlace(typed) }
                     if let made { draft.storage = made }
                 }) { draft.storage = $0 }
    }

    /// Care: how often the thing is looked after, and what to do. Care listed only
    /// records that came from the web app — nothing in this app could make one (the
    /// spec pass, 5 Oct 2026). "Done today" on Care moves the next date on.
    @ViewBuilder private var careFields: some View {
        let standard = MAINTENANCE_INTERVALS.map { ($0.days, $0.days == 0 ? "None" : $0.label) }
        let options = standard + (standard.contains { $0.0 == careEvery } ? [] : [(careEvery, "Every \(careEvery) days")])
        VStack(alignment: .leading, spacing: 6) {
            DropDown(title: "Care", options: options.map { (String($0.0), $0.1) }, selected: String(careEvery),
                     id: "thing-care") { careEvery = Int($0) ?? 0 }
            TextField("What to do, e.g. Wax the leather", text: $careNotes, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).padding(.vertical, 11).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .accessibilityIdentifier("thing-care-notes")
        }
    }

    /// "Usually packed in": every bag name, then the bag the thing names if it is
    /// none of those (so it is seen, lit), then "No bag" — LAST, so the built-in
    /// bags keep their places. It could not be set back to no bag at all (the spec
    /// pass, 5 Oct 2026). A bag named in other capitals is lit as the bag it is.
    static func bagChoices(_ names: [String], current: String) -> (options: [(id: String, label: String)], selected: String) {
        let now = jsTrim(current)
        let same = names.first { $0.lowercased() == now.lowercased() }
        var options = names.map { (id: $0, label: $0) }
        if !now.isEmpty, same == nil { options.append((id: current, label: now)) }
        options.append((id: "", label: "No bag"))
        return (options, now.isEmpty ? "" : (same ?? current))
    }

    /// A passport, an ID card, sun cream, medicine: the trip warns before it runs out.
    @ViewBuilder private var validUntil: some View {
        VStack(alignment: .leading, spacing: 8) {
            if draft.expiry.isEmpty {
                // Pill-sized, under a heading that is bigger (field test, 3 Oct 2026).
                Button { draft.expiry = Today.local } label: {
                    Text("Add a date").font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.care.color)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                        .overlay(Capsule().stroke(AppSection.care.color, lineWidth: 1.4))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("thing-expiry-add")
            } else {
                let today = Today.local
                HStack(spacing: 12) {
                    DatePicker("", selection: Binding(get: { ThingEditor.date(draft.expiry) ?? Date() },
                                                      set: { draft.expiry = ThingEditor.ymd($0) }),
                               displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("thing-expiry")
                    Spacer(minLength: 8)
                    Button("Remove the date") { draft.expiry = "" }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("thing-expiry-clear")
                }
                // How far away it is, in words, as the date changes — their
                // field test (Oct 2026): "It didn't say 10 days. You have to calculate
                // that yourself." Large, and red once it has run out. A text of its own,
                // outside any button, so the Mac does not fold it away.
                Text(distanceWords(from: today, to: draft.expiry))
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle((daysBetween(today, draft.expiry) ?? 0) < 0 ? AppSection.actions.color : Theme.ink)
                    .accessibilityIdentifier("thing-expiry-distance")
                // The usual spans in one tap, counted from today; the date above still
                // picks an exact day. The one matching the date is filled in.
                FlowRow(spacing: 8) {
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
            Text("The trip warns before it runs out \u{2014} a document (Documents & money) six months ahead.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
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
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier("thing-notes")
    }

    /// The notes its templates keep for it, under its own (spec 05, item 18): a row's
    /// note wins on its template, and a library from the web app keeps its notes
    /// there — Notes looked empty while a template said something. Changed on the
    /// template, so only shown here.
    @ViewBuilder private var rowNotes: some View {
        let notes = model.library.rowNotes(itemId: itemId)
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

    private func field(_ text: Binding<String>, _ prompt: String, _ id: String) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .font(.system(.body)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier(id)
    }

    private func save() {
        guard let it = model.library.items.first(where: { $0.id == itemId }) else { dismiss(); return }
        // The weight first, so a typo saves nothing (and says so). Untouched, the
        // stored weight stays exactly as it is, however many decimals it has.
        let weight = weightText == amountText(it.weight) ? it.weight : readAmount(weightText)
        guard let grams = weight else {
            weightProblem = "The weight must be a number of grams, like 250 or 12,5."
            return
        }
        if jsTrim(draft.name) != it.name {
            var ok = false
            model.change { ok = $0.renameThing(id: itemId, to: draft.name) }
            if !ok { problem = jsTrim(draft.name).isEmpty ? "A thing needs a name." : "You already have a thing called that."; return }
        }
        let d = draft
        let lists = onLists
        let every = careEvery, notes = jsTrim(careNotes)
        let chosen = sections, atOpen = sectionsAtOpen, typed = newSections
        model.change { lib in
            _ = lib.updateThing(id: itemId) { thing in
                thing.storage = jsTrim(d.storage)
                thing.category = d.category
                thing.container = d.container
                thing.phase = d.phase
                thing.ownedBy = d.ownedBy
                thing.condition = d.condition
                thing.weight = grams
                thing.manufacturer = jsTrim(d.manufacturer)
                thing.color = jsTrim(d.color)
                thing.note = jsTrim(d.note)
                thing.liquid = d.liquid
                thing.restricted = d.restricted
                thing.expiry = d.expiry
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
        }
        dismiss()
    }
}
