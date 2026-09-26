import Foundation
import PackingCore

/// Everything he owns, plans and has packed — in memory, as PackingCore values.
///
/// The relational shape is the web app's: ONE catalogue item per physical thing,
/// MANY memberships (one per place it sits on a template), and templates that hold
/// no items of their own. A template with its items is always RESOLVED on demand.
public struct Library: Equatable, Sendable {
    public var items: [Item] = []
    public var memberships: [Membership] = []
    /// Templates WITHOUT their items.
    public var templates: [PackList] = []
    /// Trips WITH their lines. A trip's lines are self-contained copies: they stand
    /// on their own even when the template they came from is long gone.
    public var trips: [TripEvent] = []
    public var actions: [ActionItem] = []
    public var kits: [Kit] = []
    /// The "When" timeline. EMPTY means "the factory seven" — nothing is ever
    /// seeded into the store (docs/store.md, rule 1).
    public var phases: [Phase] = []
    /// The author-made Settings lists, one row per entry. A kind with no rows means
    /// "use the defaults in the code".
    public var shared: [SharedRow] = []
    public var photos: [PhotoRecord] = []
    /// Facts about the library itself, by name (the import marker…).
    public var meta: [String: JSONValue] = [:]

    public init() {}

    public var isEmpty: Bool {
        items.isEmpty && memberships.isEmpty && templates.isEmpty && trips.isEmpty
            && actions.isEmpty && kits.isEmpty && phases.isEmpty && shared.isEmpty
            && photos.isEmpty && meta.isEmpty
    }

    // MARK: - Resolved views

    /// One template with its items, as the screens and the model's functions want
    /// it. Every row carries the ids of the item and the membership it came from,
    /// so saving it can find its way back (the web app's `resolveOne`).
    public func resolved(_ template: PackList) -> PackList {
        var byId: [String: Item] = [:]
        for i in items { byId[i.id] = i }
        return Library.resolveOne(template, byId, memberships)
    }
    public func resolvedTemplate(id: String) -> PackList? {
        templates.first { $0.id == id }.map(resolved)
    }
    /// Every template, resolved, A–Z.
    public func resolvedTemplates() -> [PackList] {
        var byId: [String: Item] = [:]
        for i in items { byId[i.id] = i }
        return templates
            .map { Library.resolveOne($0, byId, memberships) }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name) })
    }
    static func resolveOne(_ template: PackList, _ byId: [String: Item], _ mems: [Membership]) -> PackList {
        let mine = mems
            .filter { $0.templateId == template.id }
            .stableSorted(compare: { a, b in jsSign((a.order.isNaN ? 0 : a.order) - (b.order.isNaN ? 0 : b.order)) })
        let defaults = templateDefaults(template)
        var rows: [Item] = []
        for m in mine {
            guard let item = byId[m.itemId] else { continue }
            var r = resolveMembership(item, m, defaults)
            r.itemId = item.id
            r.memId = m.id
            rows.append(r)
        }
        var l = template
        l.items = rows
        return coerceList(l)
    }

    /// Things that are on no template. They exist in their own right (web app v175).
    public func thingsOnNoList() -> [Item] {
        let used = Set(memberships.map(\.itemId))
        return items.filter { !used.contains($0.id) }.map { resolveItemAlone($0) }
    }

    // MARK: - Saving a template

    /// Take an edited (resolved) template apart again: what describes the THING goes
    /// to the shared catalogue item, what describes its place on THIS list goes to
    /// the membership. A row taken off the list loses its membership only — the
    /// thing itself survives. (The web app's `saveList`, v176.)
    public mutating func saveTemplate(_ list: PackList, keepingMembershipIds: Bool = true) {
        var byId: [String: Int] = [:]
        for (n, i) in items.enumerated() { byId[i.id] = n }
        var byName: [String: Int] = [:]
        for (n, i) in items.enumerated() where byName[normName(i.name)] == nil { byName[normName(i.name)] = n }
        var memIndex: [String: Int] = [:]
        for (n, m) in memberships.enumerated() { memIndex[m.id] = n }

        var present = Set<String>()
        var order = 0.0
        for row in list.items {
            if jsTrim(row.name).isEmpty { continue }
            // Which catalogue item is this: by link, else by name, else brand new.
            var at: Int? = nil
            if let iid = row.itemId, let n = byId[iid] { at = n }
            else if let n = byName[normName(row.name)] { at = n }
            if let n = at {
                items[n] = applyIntrinsic(items[n], row)
            } else if row.link {
                continue   // never invent an item from a link whose target has vanished
            } else {
                var cat = catalogItemFromResolved(row)
                // A row that already names its item keeps that id: trip lines point at it.
                if let iid = row.itemId, !iid.isEmpty { cat.id = iid }
                items.append(cat)
                at = items.count - 1
                byId[cat.id] = at
                if byName[normName(cat.name)] == nil { byName[normName(cat.name)] = at }
            }
            let cat = items[at!]
            // Reuse the membership when we can (its id stays stable), else make one.
            var existing: Membership? = nil
            if let mid = row.memId, let n = memIndex[mid], memberships[n].templateId == list.id {
                existing = memberships[n]
            } else if let n = memberships.firstIndex(where: { $0.templateId == list.id && $0.itemId == cat.id && !present.contains($0.id) }) {
                existing = memberships[n]
            } else if keepingMembershipIds, let mid = row.memId, !mid.isEmpty, memIndex[mid] == nil {
                existing = newMembership(id: mid, itemId: cat.id, templateId: list.id)
            }
            let m = membershipFromResolved(cat, list.id, row, order, existing)
            order += 1
            if let n = memIndex[m.id] { memberships[n] = m }
            else { memberships.append(m); memIndex[m.id] = memberships.count - 1 }
            present.insert(m.id)
        }
        // Memberships of THIS template that are no longer present go. Items never do.
        memberships.removeAll { $0.templateId == list.id && !present.contains($0.id) }

        var template = list
        template.items = []
        template = coerceList(template)
        template.updatedAt = nowISO()
        if let n = templates.firstIndex(where: { $0.id == template.id }) { templates[n] = template }
        else { templates.append(template) }
    }

    // MARK: - Trips

    /// Regenerate a trip from its templates, keeping his edits — and NEVER dropping a
    /// line whose template no longer exists (docs/store.md, rule 9).
    ///
    /// The model's `regenerateEntries` keeps a line only when a template still
    /// produces it, or it is custom, ticked or edited. So a past trip built from
    /// templates he has since deleted would lose every unticked line — one of his
    /// real trips would go from 88 lines to none. A line whose source template is
    /// gone has nothing left to be regenerated FROM: it stays, where it was.
    public func regenerated(_ trip: TripEvent) -> [Item] {
        let known = Set(templates.map(\.id))
        let fresh = regenerateEntries(trip, resolvedTemplates())
        let kept = Set(fresh.map(\.id))
        let orphans = trip.entries.filter { e in
            guard !kept.contains(e.id), let source = e.sourceListId, !source.isEmpty else { return false }
            return !known.contains(source)
        }
        return fresh + orphans
    }

    /// Tick or untick one line. The smallest write the app makes, and the most common.
    @discardableResult
    public mutating func setChecked(_ checked: Bool, tripId: String, entryId: String) -> Bool {
        guard let t = trips.firstIndex(where: { $0.id == tripId }),
              let e = trips[t].entries.firstIndex(where: { $0.id == entryId }) else { return false }
        trips[t].entries[e].checked = checked
        return true
    }
}

// MARK: - Making a trip

extension Library {
    /// Build a trip's packing list from the templates it names and add it to the
    /// library. The trip's length in nights comes from its dates, as in the web app.
    /// Returns the trip as stored (with its lines).
    @discardableResult
    public mutating func createTrip(_ draft: TripEvent) -> TripEvent {
        var trip = coerceEvent(draft)
        if trip.id.isEmpty { trip.id = PackingEnv.makeId() }
        trip.nights = nightsBetween(trip.startDate, trip.endDate) ?? 0
        trip.entries = buildTotalEntries(trip, resolvedTemplates())
        trip.generatedAt = nowISO()
        trip.createdAt = nowISO()
        trip.updatedAt = trip.createdAt
        trips.append(trip)
        return trip
    }

    /// The templates a trip can be built from: the tickable activities, in his
    /// order (Swim / Bike / Run…), grouped by his activity groups.
    public func activityChoices() -> [(group: ActivityGroup, lists: [PackList])] {
        let all = resolvedTemplates().filter { $0.role.isEmpty }
        return GROUPS.compactMap { g in
            let mine = orderActivities(g.id, all.filter { $0.group == g.id })
            return mine.isEmpty ? nil : (g, mine)
        }
    }
}

// MARK: - While packing

extension Library {
    /// Add a thing to THIS trip only, typed on the spot ("Also the tripod"). A
    /// custom line: no template behind it, so a regenerate always keeps it.
    @discardableResult
    public mutating func addCustomLine(tripId: String, name: String, container: String = "", phase: String = "") -> Item? {
        let clean = jsTrim(name)
        guard !clean.isEmpty, let t = trips.firstIndex(where: { $0.id == tripId }) else { return nil }
        var line = newItem(name: clean, container: container.isEmpty ? "Carry-on / hand luggage" : container,
                           phase: phase.isEmpty ? defaultPhaseId() : phase)
        line.custom = true
        line.checked = false
        trips[t].entries.append(line)
        trips[t].updatedAt = nowISO()
        return line
    }
}

// MARK: - To-dos

extension Library {
    /// A to-do, loose or tied to a thing. Lives in its own table, as in the web app.
    @discardableResult
    public mutating func addAction(text: String, kind: String = "todo", itemId: String = "", itemName: String = "",
                                   priority: String = "normal", whenPhase: String = "") -> ActionItem? {
        let clean = jsTrim(text)
        guard !clean.isEmpty else { return nil }
        let a = newAction(text: clean, kind: kind, itemId: itemId, itemName: itemName, priority: priority, whenPhase: whenPhase)
        actions.append(a)
        return a
    }

    /// Ticking is permanent on the action — it does not reset per trip.
    @discardableResult
    public mutating func setActionDone(_ done: Bool, id: String) -> Bool {
        guard let n = actions.firstIndex(where: { $0.id == id }) else { return false }
        actions[n].done = done
        actions[n].doneAt = done ? nowISO() : ""
        actions[n].updatedAt = nowISO()
        return true
    }

    public mutating func deleteAction(id: String) { actions.removeAll { $0.id == id } }

    /// The central list: open before done, high before normal, sooner before later.
    public func sortedActions(kind: String = "todo") -> [ActionItem] {
        actions.filter { $0.kind == kind }.stableSorted(compare: { a, b in compareActions(a, b) })
    }
}

// MARK: - Editing a template

extension Library {
    /// Add a thing to a template. A thing of that name already in the library is
    /// PUT ON the template (one thing, one more place it sits) — a new name makes a
    /// new thing. Returns the resolved row as it now appears on the template.
    @discardableResult
    public mutating func addToTemplate(templateId: String, name: String, container: String = "", phase: String = "") -> Item? {
        let clean = jsTrim(name)
        guard !clean.isEmpty, var list = resolvedTemplate(id: templateId) else { return nil }
        var row = newItem(name: clean, container: container.isEmpty ? "Carry-on / hand luggage" : container,
                          phase: phase.isEmpty ? defaultPhaseId() : phase)
        if let existing = items.first(where: { normName($0.name) == normName(clean) }) {
            row = resolveItemAlone(existing)   // the thing's own defaults come along
            row.memId = nil
        }
        list.items.append(row)
        saveTemplate(list)
        return resolvedTemplate(id: templateId)?.items.last
    }

    /// Take a row off a template. The thing itself survives (web app v176): on
    /// its other templates, or as a thing on no list.
    @discardableResult
    public mutating func removeFromTemplate(templateId: String, memId: String) -> Bool {
        guard var list = resolvedTemplate(id: templateId), list.items.contains(where: { $0.memId == memId }) else { return false }
        list.items.removeAll { $0.memId == memId }
        saveTemplate(list)
        return true
    }
}

// MARK: - Care

extension Library {
    /// Everything with a care schedule or care notes, most urgent first — the
    /// model's own list over the resolved templates (one row per thing, however
    /// many templates it sits on).
    public func careRows(today: String) -> [MaintenanceRow] {
        maintenanceList(resolvedTemplates(), today)
    }

    /// "Done today": log a service on the THING (care is intrinsic — it describes
    /// the physical object), which moves its next due date on.
    @discardableResult
    public mutating func logCare(itemId: String, on day: String, note: String = "") -> Bool {
        guard let n = items.firstIndex(where: { $0.id == itemId }) else { return false }
        logMaintenance(&items[n], day, note)
        return true
    }
}

// MARK: - After a trip: the review

extension Library {
    /// A thing he wished he'd had, and where it should go. `templateId` "" = no list:
    /// it becomes a thing of its own ("Your things").
    public struct Missed: Equatable, Sendable {
        public var name: String
        public var templateId: String
        public init(name: String, templateId: String) { self.name = name; self.templateId = templateId }
    }

    /// The lines a review asks about: everything packable that is not a reminder.
    /// When anything was ticked, the unticked ones never went in the bag — they are
    /// shown apart and counted as "skipped", never as "unused" (web app v162).
    public func reviewLines(tripId: String) -> (packed: [Item], neverPacked: [Item]) {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return ([], []) }
        let items = trip.entries.filter { $0.itemType != "reminder" }
        let anyTicked = items.contains { $0.checked }
        guard anyTicked else { return (items, []) }
        return (items.filter { $0.checked }, items.filter { !$0.checked })
    }

    /// The templates a trip was built from, in the order its lines name them.
    public func tripTemplates(tripId: String) -> [PackList] {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return [] }
        var seen = Set<String>(), out: [PackList] = []
        for e in trip.entries {
            guard let lid = e.sourceListId, !lid.isEmpty, seen.insert(lid).inserted,
                  let t = templates.first(where: { $0.id == lid }) else { continue }
            out.append(t)
        }
        return out
    }

    /// Save a review, as the web app does: the missed things go onto their lists
    /// first (so the next trip brings them), every line is marked used or not, the
    /// model folds that into each thing's history (`applyReview`), and the trip is done.
    @discardableResult
    public mutating func saveReview(tripId: String, unused: Set<String>, missed: [Missed], when: String) -> Bool {
        guard let t = trips.firstIndex(where: { $0.id == tripId }) else { return false }
        for m in missed {
            let name = jsTrim(m.name)
            guard !name.isEmpty else { continue }
            if m.templateId.isEmpty {
                if items.contains(where: { normName($0.name) == normName(name) }) { continue }
                var cat = catalogItemFromResolved(newItem(name: name))
                cat.id = PackingEnv.makeId()
                items.append(cat)
            } else if let list = resolvedTemplate(id: m.templateId),
                      !list.items.contains(where: { normName($0.name) == normName(name) }) {
                addToTemplate(templateId: m.templateId, name: name)
            }
        }
        for n in trips[t].entries.indices where trips[t].entries[n].itemType != "reminder" {
            trips[t].entries[n].used = !unused.contains(trips[t].entries[n].id)
        }
        // The model folds the review into the rows of the templates. The new history
        // is then written straight onto each THING — not through saveTemplate: a thing
        // that sits on one template twice (a different "When" each time) has only its
        // FIRST row updated by applyReview, and saving the template would let the stale
        // twin overwrite it. (The web app's saveList does exactly that — found by this
        // port's test, 2026-09-22.) The updated row is the one stamped with `when`.
        var lists = resolvedTemplates()
        for changed in applyReview(trips[t], &lists, when) {
            for row in changed.items where row.stats.lastReviewed == when {
                guard let iid = row.itemId, let n = items.firstIndex(where: { $0.id == iid }) else { continue }
                items[n].stats = row.stats
            }
        }
        trips[t].status = "done"
        trips[t].reviewedAt = when
        trips[t].updatedAt = when
        return true
    }
}

// MARK: - Your things

extension Library {
    /// Every thing he owns, whether or not it is on a list — A–Z as the web app
    /// sorts it — with the names of the templates it sits on ([] = on no list).
    public func thingRows() -> [(item: Item, templates: [String])] {
        var names: [String: [String]] = [:]
        for t in templates {
            for m in memberships where m.templateId == t.id {
                if !(names[m.itemId] ?? []).contains(t.name) { names[m.itemId, default: []].append(t.name) }
            }
        }
        return items
            .map { (item: $0, templates: names[$0.id] ?? []) }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.item.name, b.item.name, sensitivity: .base) })
    }

    /// A new thing, on no list yet. Refused for a blank name or one he already has.
    @discardableResult
    public mutating func addThing(name: String) -> Item? {
        let clean = jsTrim(name)
        guard !clean.isEmpty, !items.contains(where: { normName($0.name) == normName(clean) }) else { return nil }
        var cat = catalogItemFromResolved(newItem(name: clean))
        cat.id = PackingEnv.makeId()
        items.append(cat)
        return cat
    }

    /// Rename a thing — once, and every list it is on shows the new name (it is ONE
    /// thing). Past trips keep the name they were packed with: a trip line is a copy.
    /// Refused for a blank name or one another thing already has.
    @discardableResult
    public mutating func renameThing(id: String, to name: String) -> Bool {
        let clean = jsTrim(name)
        guard !clean.isEmpty, let n = items.firstIndex(where: { $0.id == id }),
              !items.contains(where: { $0.id != id && normName($0.name) == normName(clean) }) else { return false }
        // A BAG is found by its name everywhere — carry the new name through, from
        // whichever screen it is renamed (his choice, 2026-09-26: all trips too).
        let wasBag = bags().first { $0.id == id }
        items[n].name = clean
        if let bag = wasBag, bag.name != clean { renameBagEverywhere(from: bag.name, to: clean) }
        return true
    }

    /// Where the thing is kept at home ("Garage shelf"). "" = not said.
    @discardableResult
    public mutating func setStorage(id: String, place: String) -> Bool {
        guard let n = items.firstIndex(where: { $0.id == id }) else { return false }
        items[n].storage = jsTrim(place)
        return true
    }
}

// MARK: - Changing a thing

extension Library {
    /// Change what the THING itself knows — its category, its own bag and "When",
    /// who owns it, its condition, its weight. Every list it is on follows, because
    /// there is one thing. (A list's own exception lives on the membership.)
    @discardableResult
    public mutating func updateThing(id: String, _ apply: (inout Item) -> Void) -> Bool {
        guard let n = items.firstIndex(where: { $0.id == id }) else { return false }
        var it = items[n]
        apply(&it)
        items[n] = coerceItem(it)
        return true
    }

    /// Put a thing on a list, or take it off. Taking it off removes the membership
    /// only — the thing itself stays (web app v176).
    @discardableResult
    public mutating func setOnTemplate(itemId: String, templateId: String, on: Bool) -> Bool {
        guard items.contains(where: { $0.id == itemId }), templates.contains(where: { $0.id == templateId }) else { return false }
        let here = memberships.filter { $0.templateId == templateId }
        if on {
            guard !here.contains(where: { $0.itemId == itemId }) else { return true }
            var m = newMembership(itemId: itemId, templateId: templateId)
            m.order = (here.map(\.order).max() ?? -1) + 1
            memberships.append(m)
        } else {
            memberships.removeAll { $0.templateId == templateId && $0.itemId == itemId }
        }
        return true
    }
}

// MARK: - A row of a template (the membership: this list's own answers)

extension Library {
    /// The row as it sits on THIS list, and the thing behind it.
    public func row(templateId: String, memId: String) -> (row: Item, thing: Item, membership: Membership)? {
        guard let m = memberships.first(where: { $0.id == memId && $0.templateId == templateId }),
              let thing = items.first(where: { $0.id == m.itemId }),
              let row = resolvedTemplate(id: templateId)?.items.first(where: { $0.memId == memId }) else { return nil }
        return (row, thing, m)
    }

    /// Change what THIS list says about the thing: its bag and "When" here (blank =
    /// follow the thing), how many, a note, which section of the list it sits in.
    @discardableResult
    public mutating func updateMembership(memId: String, _ apply: (inout Membership) -> Void) -> Bool {
        guard let n = memberships.firstIndex(where: { $0.id == memId }) else { return false }
        var m = memberships[n]
        apply(&m)
        memberships[n] = coerceMembership(m)
        return true
    }

    /// A named section of a template ("Lights", "Rig"), added if it is new.
    @discardableResult
    public mutating func addSection(templateId: String, name: String) -> TemplateSection? {
        let clean = jsTrim(name)
        guard !clean.isEmpty, let t = templates.firstIndex(where: { $0.id == templateId }) else { return nil }
        if let there = templates[t].sections.first(where: { normName($0.name) == normName(clean) }) { return there }
        let s = newSection(clean)
        templates[t].sections.append(s)
        return s
    }
}
