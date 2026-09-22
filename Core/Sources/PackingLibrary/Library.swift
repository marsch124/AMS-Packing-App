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
