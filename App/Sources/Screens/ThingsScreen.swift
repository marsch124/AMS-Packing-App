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
    @State private var editing: String?
    /// What he added on this visit, newest first — his and Anna's field test (3 Oct
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
                Text("Your things").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("things-done")
            }
            .padding(16)
            TextField("Search your things…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 17)).foregroundStyle(Theme.ink)
                .clearButton($query, id: "things-search")
                .padding(.horizontal, 12).frame(minHeight: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .padding(.horizontal, 16)
            HStack(spacing: 10) {
                Text(shown.count == 1 ? "1 thing" : "\(shown.count) things")
                    .font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("things-count")
                Spacer()
                if homeless > 0 {
                    Button { noListOnly.toggle() } label: {
                        Text("On no template \(homeless)").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(noListOnly ? Color.white : AppSection.care.color)
                            .padding(.horizontal, 12).frame(minHeight: 32)
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
                                thingRow(row, n: n)
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
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("thing-new-name")
                Button { add() } label: {
                    Text("New").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(jsTrim(newName).isEmpty ? Theme.muted : Color.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(jsTrim(newName).isEmpty ? Theme.line : AppSection.care.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(jsTrim(newName).isEmpty)
                .accessibilityIdentifier("thing-new")
            }
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
            VStack(alignment: .leading, spacing: 2) {
                Text(row.item.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                Text([row.templates.isEmpty ? "On no template" : row.templates.joined(separator: ", "),
                      row.item.storage].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 14)).foregroundStyle(row.templates.isEmpty ? AppSection.care.color : Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
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
        Text(title.uppercased())
            .font(.system(size: 15, weight: .heavy)).kerning(0.6).foregroundStyle(AppSection.care.color)
            .padding(.top, 12).padding(.bottom, 2)
            .accessibilityIdentifier(id)
    }

    private func add() {
        let name = newName
        guard !jsTrim(name).isEmpty else { return }
        var made: Item?
        model.change { made = $0.addThing(name: name) }
        newName = ""
        guard let id = made?.id else { return }
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

    var body: some View {
        let templates = model.library.templates.filter { $0.role != CONTAINER_ROLE }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
        let owners = model.library.ownerChoices()          // each once (his screenshot, 2026-09-26)
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("thing-cancel")
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("thing-save")
            }
            .padding(16)
            KeyboardAwayScroll {
                // A field sits right under its heading, and the space goes BETWEEN the
                // headings (his screenshot, 2026-09-28: "put the Bike field much nearer
                // its heading, the same goes for everything").
                VStack(alignment: .leading, spacing: 22) {
                    labelled("Name") { field($draft.name, "Name", "thing-name") }
                    labelled("Kept at home") { field($draft.storage, "e.g. Hall closet", "thing-storage") }
                    Pills(title: "Kind of thing", options: CATEGORIES.map { ($0, $0) }, selected: [draft.category],
                          id: "thing-category", tint: AppSection.care.color, compact: true) { draft.category = $0 }
                    Pills(title: "Usually packed in", options: containerNames(model.library.resolvedTemplates()).map { ($0, $0) },
                          selected: [draft.container], id: "thing-bag", tint: AppSection.care.color, compact: true) { draft.container = $0 }
                    // On a plane, and Valid until — what Check before you go reads (his ideas 4 and 5).
                    VStack(alignment: .leading, spacing: 8) {
                        HeadingBand(title: "On a plane", id: "thing-heading-plane")
                        Toggle(isOn: $draft.liquid) { flagWords("Liquid", "In the cabin: 100 ml at most, in the clear bag.") }
                            .tint(AppSection.care.color)
                            .accessibilityIdentifier("thing-liquid")
                        Toggle(isOn: $draft.restricted) { flagWords("Not allowed in the cabin", "A knife, tools, gas — it goes in the hold.") }
                            .tint(AppSection.care.color)
                            .accessibilityIdentifier("thing-restricted")
                    }
                    labelled("Valid until") { validUntil }
                    Pills(title: "When", options: PHASES.map { ($0.id, $0.label) }, selected: [draft.phase],
                          id: "thing-when", tint: AppSection.care.color, compact: true) { draft.phase = $0 }
                    if !owners.isEmpty {
                        Pills(title: "Whose it is", options: [("", "Nobody's in particular")] + owners.map { ($0, $0) },
                              selected: [draft.ownedBy], id: "thing-owner", tint: AppSection.care.color, compact: true) { draft.ownedBy = $0 }
                    }
                    Pills(title: "Condition", options: [("", "Not said")] + ITEM_CONDITIONS.map { ($0.id, $0.label) },
                          selected: [draft.condition], id: "thing-condition", tint: AppSection.care.color, compact: true) { draft.condition = $0 }
                    labelled("Weight, in grams (0 = not known)") {
                        field(Binding(get: { draft.weight == 0 ? "" : String(Int(draft.weight)) },
                                      set: { draft.weight = Double(jsTrim($0)) ?? 0 }), "0", "thing-weight")
                    }
                    // Brand, colour and notes — for bags above all (his bag page, 2026-09-26),
                    // and for any thing: the web app's editor has had them all along.
                    labelled("Brand") { field($draft.manufacturer, "e.g. Patagonia", "thing-brand") }
                    labelled("Colour") { field($draft.color, "e.g. Black", "thing-colour") }
                    labelled("Notes") { field($draft.note, "Anything worth remembering", "thing-notes") }
                    Pills(title: "On these templates", options: templates.map { ($0.id, $0.name) }, selected: onLists,
                          id: "thing-lists", tint: AppSection.templates.color, compact: true) { id in
                        if onLists.contains(id) { onLists.remove(id) } else { onLists.insert(id) }
                    }
                    // Where the trip tags live (his ask, 2 Oct 2026, to have them here).
                    Text("Only on some trips — Season, Indoor/Outdoor, Transport, Food — is set per template: open the template and tap this thing.")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("thing-tags-hint")
                    if !problem.isEmpty {
                        Text(problem).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .accessibilityIdentifier("thing-problem")
                    }
                    Text("A change here reaches every template it is on. Past trips keep what they were packed with.")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                    deleteThing
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            if let it = model.library.items.first(where: { $0.id == itemId }) { draft = it }
            onLists = Set(model.library.memberships.filter { $0.itemId == itemId }.map(\.templateId))
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
                        .font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text(lists.isEmpty ? "It is on none of your templates. Trips you already packed keep it."
                         : "It leaves your \(BagDetail.names(lists)) template\(lists.count == 1 ? "" : "s"). Trips you already packed keep it.")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Keep it") { askingToDelete = false }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                            .accessibilityIdentifier("thing-delete-no")
                        Spacer()
                        Button {
                            let id = itemId
                            dismiss()
                            model.change { _ = $0.deleteThing(id: id) }
                        } label: {
                            Text("Delete the thing").font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 14).frame(minHeight: 40)
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

    /// A passport, an ID card, sun cream, medicine: the trip warns before it runs out.
    @ViewBuilder private var validUntil: some View {
        VStack(alignment: .leading, spacing: 8) {
            if draft.expiry.isEmpty {
                Button { draft.expiry = Today.local } label: {
                    Text("Add a date").font(.system(size: 16, weight: .bold)).foregroundStyle(AppSection.care.color)
                        .padding(.horizontal, 14).frame(minHeight: 40)
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
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("thing-expiry-clear")
                }
                // How far away it is, in words, as the date changes — his and Anna's
                // field test (Oct 2026): "It didn't say 10 days. You have to calculate
                // that yourself." Large, and red once it has run out. A text of its own,
                // outside any button, so the Mac does not fold it away.
                Text(distanceWords(from: today, to: draft.expiry))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle((daysBetween(today, draft.expiry) ?? 0) < 0 ? AppSection.actions.color : Theme.ink)
                    .accessibilityIdentifier("thing-expiry-distance")
                // The usual spans in one tap, counted from today; the date above still
                // picks an exact day. The one matching the date is filled in.
                FlowRow(spacing: 8) {
                    ForEach(Array(ThingEditor.quickSpans.enumerated()), id: \.offset) { n, span in
                        let on = draft.expiry == addMonths(today, span.months)
                        Button { draft.expiry = addMonths(today, span.months) } label: {
                            Text(span.label)
                                .font(.system(size: 15, weight: .bold).monospacedDigit())
                                .foregroundStyle(on ? Color.white : AppSection.care.color)
                                .padding(.horizontal, 14).frame(minHeight: 38)
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
                .font(.system(size: 14)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The quick choices under Valid until: sun cream lasts about a year once open,
    /// a passport five or ten.
    static let quickSpans: [(label: String, months: Int)] = [
        ("+1 month", 1), ("+6 months", 6), ("+1 year", 12), ("+5 years", 60), ("+10 years", 120),
    ]

    private func flagWords(_ title: String, _ says: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
            Text(says).font(.system(size: 14)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
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

    /// A heading and its field, held together: 4 points apart, where the headings
    /// themselves are 22 apart.
    private func labelled<Content: View>(_ text: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HeadingBand(title: text, id: "thing-heading-\(text.prefix { $0.isLetter }.lowercased())")
            content()
        }
    }

    private func field(_ text: Binding<String>, _ prompt: String, _ id: String) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).frame(minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier(id)
    }

    private func save() {
        guard let it = model.library.items.first(where: { $0.id == itemId }) else { dismiss(); return }
        if jsTrim(draft.name) != it.name {
            var ok = false
            model.change { ok = $0.renameThing(id: itemId, to: draft.name) }
            if !ok { problem = jsTrim(draft.name).isEmpty ? "A thing needs a name." : "You already have a thing called that."; return }
        }
        let d = draft
        let lists = onLists
        model.change { lib in
            _ = lib.updateThing(id: itemId) { thing in
                thing.storage = jsTrim(d.storage)
                thing.category = d.category
                thing.container = d.container
                thing.phase = d.phase
                thing.ownedBy = d.ownedBy
                thing.condition = d.condition
                thing.weight = d.weight
                thing.manufacturer = jsTrim(d.manufacturer)
                thing.color = jsTrim(d.color)
                thing.note = jsTrim(d.note)
                thing.liquid = d.liquid
                thing.restricted = d.restricted
                thing.expiry = d.expiry
            }
            for t in lib.templates where t.role != CONTAINER_ROLE {
                _ = lib.setOnTemplate(itemId: itemId, templateId: t.id, on: lists.contains(t.id))
            }
        }
        dismiss()
    }
}
