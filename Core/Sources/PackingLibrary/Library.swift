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

    /// Nothing of his here. A device's check-in does not count (`isDeviceNote`): it
    /// is about the device, and it must not shut the first-run doors.
    public var isEmpty: Bool {
        items.isEmpty && memberships.isEmpty && templates.isEmpty && trips.isEmpty
            && actions.isEmpty && kits.isEmpty && phases.isEmpty && shared.isEmpty
            && photos.isEmpty && meta.keys.allSatisfy(Library.isDeviceNote)
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
    ///
    /// A place on a template that no longer exists does not count (the spec pass,
    /// 2026-10-05): such a thing shows on no template, so a backup that left it out
    /// of `things` too lost it — and "a backup, then Restore" is exactly what Worth
    /// a look suggests for "a thing sits on a template that no longer exists".
    public func thingsOnNoList() -> [Item] {
        let used = Set(placesOnTemplates().map(\.itemId))
        return items.filter { !used.contains($0.id) }.map { resolveItemAlone($0) }
    }

    /// The places on templates that can be shown: their template and their thing
    /// both exist. A membership pointing at a gone template (a delete on the other
    /// device while this one added to it) is left out — of a backup too.
    public func placesOnTemplates() -> [Membership] {
        let lists = Set(templates.map(\.id)), things = Set(items.map(\.id))
        return memberships.filter { lists.contains($0.templateId) && things.contains($0.itemId) }
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
            var m = membershipFromResolved(cat, list.id, row, order, existing)
            // How many and the note are the row's own only where they say something
            // the thing does not. `membershipFromResolved` (the web app's, kept as a
            // copy) stores the row's RESOLVED values — the thing's own note included —
            // so putting a thing on a template, or saving that template later, froze
            // the thing's note onto every row, and a change to the note never reached
            // them again (the spec pass, 5 Oct 2026; "Blank means the same as the thing
            // itself").
            m.qty = Library.placeAnswer(shown: row.qty, stored: existing?.qty, thing: cat.qty)
            m.note = Library.placeAnswer(shown: row.note, stored: existing?.note, thing: cat.note)
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
    ///
    /// It matches the web app's `regenerateEntries` in what it keeps, with one fix
    /// the web app never needed: a thing on the trip TWICE (Underwear from two
    /// templates, going into two bags) made both fresh lines take the SAME old
    /// line — one id twice on the trip, and the Mac app stopped (his E.6 crash,
    /// 2026-09-28). Here each old line is taken at most once, the same thing in the
    /// same bag first, so each keeps its own tick; and no id ever appears twice.
    public func regenerated(_ trip: TripEvent) -> [Item] {
        let known = Set(templates.map(\.id))
        let fresh = buildTotalEntries(trip, resolvedTemplates())
        let prev = trip.entries
        var taken = Set<Int>()
        func match(_ f: Item) -> Item? {
            guard let sid = f.sourceItemId, !sid.isEmpty else { return nil }
            let same = prev.indices.filter { !taken.contains($0) && prev[$0].sourceItemId == sid }
            let pick = same.first { normName(prev[$0].container) == normName(f.container) } ?? same.first
            guard let i = pick else { return nil }
            taken.insert(i)
            return prev[i]
        }
        // A line with NOTHING behind it — no template, no thing — and not typed on the
        // trip is a line someone SENT: a shared trip travels without its links (the spec
        // pass, 5 Oct 2026: the first Save in Trip settings threw a received trip's whole
        // list away, ticks and all). There is nothing to rebuild it from, so it stays —
        // and a fresh line of the same name into the same bag is not added beside it.
        func sent(_ e: Item) -> Bool { !e.custom && (e.sourceListId ?? "").isEmpty && (e.sourceItemId ?? "").isEmpty }
        func key(_ e: Item) -> String { "\(normName(e.name))|\(e.container)" }
        let sentKeys = Set(prev.filter(sent).map(key))
        var out: [Item] = []
        for f in fresh {
            if let old = match(f) { out.append(old) } else if !sentKeys.contains(key(f)) { out.append(f) }
        }
        let matched = Set(out.compactMap { $0.sourceItemId }.filter { !$0.isEmpty })
        for (i, e) in prev.enumerated() where !taken.contains(i) {
            if e.custom { out.append(e); continue }
            // Ticked or edited, and nothing fresh covers it: kept, as in the web app.
            if let sid = e.sourceItemId, !sid.isEmpty, !matched.contains(sid), e.checked || e.edited { out.append(e); continue }
            // Its template is gone: nothing to regenerate it from, so it stays.
            if let source = e.sourceListId, !source.isEmpty, !known.contains(source) { out.append(e); continue }
            // Sent to him: nothing to regenerate it from either.
            if sent(e) { out.append(e) }
        }
        // Belt and braces: never two lines with one id.
        var seen = Set<String>()
        for n in out.indices where !seen.insert(out[n].id).inserted {
            out[n].id = PackingEnv.makeId()
            seen.insert(out[n].id)
        }
        return out
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
    /// order (Swim / Bike / Run…), grouped by his activity groups — and, last, every
    /// template with no activity area, under "Other templates" (group id "").
    ///
    /// The spec pass (5 Oct 2026): a template made with "No activity area" (A new
    /// template offers it) was shown on the Templates tab but never offered for a trip,
    /// and Trip settings dropped it from a trip on Save. The web app offers such lists
    /// last ("Other lists"); so does this, in the words of the Templates tab.
    public func activityChoices() -> [(group: ActivityGroup, lists: [PackList])] {
        let all = resolvedTemplates().filter { $0.role.isEmpty }
        let grouped: [(group: ActivityGroup, lists: [PackList])] = GROUPS.compactMap { g in
            let mine = orderActivities(g.id, all.filter { $0.group == g.id })
            return mine.isEmpty ? nil : (g, mine)
        }
        let other = all.filter { !GROUP_IDS.contains($0.group) }
        return other.isEmpty ? grouped : grouped + [(ActivityGroup(id: "", label: "Other templates", hint: ""), other)]
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
    ///
    /// A thing ALREADY on the template is not put on a second time (nil): typing its
    /// name again is a slip, never a wish — the picker and the review refuse it too
    /// (the spec pass, 5 Oct 2026). A thing can still sit twice on one template
    /// where the data says so (the web app allows it); it is never MADE so by typing.
    @discardableResult
    public mutating func addToTemplate(templateId: String, name: String, container: String = "", phase: String = "") -> Item? {
        let clean = jsTrim(name)
        guard !clean.isEmpty, var list = resolvedTemplate(id: templateId) else { return nil }
        guard !isOnTemplate(templateId: templateId, name: clean) else { return nil }
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

    /// Is a thing of this name on this template already? (By the thing's name, as
    /// typing finds a thing.)
    public func isOnTemplate(templateId: String, name: String) -> Bool {
        let wanted = normName(name)
        let here = Set(memberships.filter { $0.templateId == templateId }.map(\.itemId))
        return items.contains { here.contains($0.id) && normName($0.name) == wanted }
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
    ///
    /// Also the things on NO template — a thing with a schedule is looked after
    /// whether or not it is packed, and the web app keeps such things since v175 —
    /// and never a thing "not in use" (retired), which the kit no longer counts
    /// either. Until 0.62 a loose thing never showed on Care or its calendar, while
    /// a retired one still counted as needing care (the spec pass, 5 Oct 2026).
    /// Each template is named as he sees it: his bag list is "Bags", never the
    /// stored "Containers" (his words rule, 27 Sep 2026).
    public func careRows(today: String) -> [MaintenanceRow] {
        var lists = resolvedTemplates().map { list -> PackList in
            var shown = list
            shown.name = shownName(list)
            return shown
        }
        let loose = thingsOnNoList()
        if !loose.isEmpty {
            // A list with no name and no id: its things get a row, but no template
            // to name. (An explicit id, so reading Care never draws a fresh one.)
            lists.append(PackList(id: "", name: "", items: loose, createdAt: "", updatedAt: ""))
        }
        return maintenanceList(lists, today).filter { !$0.item.retired }
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
    ///
    /// A line set aside never went either, ticked or not (the spec pass, 5 Oct 2026:
    /// older trips hold lines ticked and THEN set aside; and on a trip with no tick at
    /// all, "the list is the evidence" asked about the set-aside lines as packed).
    public func reviewLines(tripId: String) -> (packed: [Item], neverPacked: [Item]) {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return ([], []) }
        let items = trip.entries.filter { $0.itemType != "reminder" }
        let went: (Item) -> Bool = { $0.checked && !isSetAside($0) }
        guard items.contains(where: went) else {
            return (items.filter { !isSetAside($0) }, items.filter { isSetAside($0) })
        }
        return (items.filter(went), items.filter { !went($0) })
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
        // A line set aside did not go, whatever an older tick under it says (see
        // reviewLines): it is unticked first, so the model counts it as listed and never
        // packed — and on a trip with no tick at all it is left out, not counted packed.
        for n in trips[t].entries.indices where isSetAside(trips[t].entries[n]) { trips[t].entries[n].checked = false }
        let anyWent = trips[t].entries.contains { $0.itemType != "reminder" && $0.checked }
        for n in trips[t].entries.indices where trips[t].entries[n].itemType != "reminder" {
            let line = trips[t].entries[n]
            trips[t].entries[n].used = !anyWent && isSetAside(line) ? nil : !unused.contains(line.id)
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
                // The bag list reads "Bags" (stored as "Containers" — see Bags.swift).
                let shown = shownName(t)
                if !(names[m.itemId] ?? []).contains(shown) { names[m.itemId, default: []].append(shown) }
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
        followThing(id: id)                  // its open lines on trips still ahead (his I.7)
        return true
    }

    /// Delete a thing — his ask (2026-09-27): off every list and out of every kit,
    /// then gone. Past trips keep their lines (a trip line is a copy); a to-do tied
    /// to it keeps its name. A BAG is refused: things are packed in it by name, so
    /// it goes through `deleteBag`, which asks where they go.
    @discardableResult
    public mutating func deleteThing(id: String, evenABag: Bool = false) -> Bool {
        guard items.contains(where: { $0.id == id }) else { return false }
        if !evenABag, bags().contains(where: { $0.id == id }) { return false }
        memberships.removeAll { $0.itemId == id }
        for k in kits.indices { kits[k].itemIds.removeAll { $0 == id } }
        items.removeAll { $0.id == id }
        return true
    }

    /// The lists a thing is on, by name, as he sees them.
    public func listsOf(itemId: String) -> [String] {
        templates.filter { t in memberships.contains { $0.itemId == itemId && $0.templateId == t.id } }
            .map { shownName($0) }
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
        // …and on to the trips still ahead, where nothing is decided yet (his I.7).
        followThing(id: id)
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

// MARK: - Arranging a template: its headings and the order of its rows

// His choice (5 Oct 2026, layout "C" of three pictures): on a template's page,
// Arrange shows a grip on every heading and every thing; he holds it and drags a
// heading to move its whole section, or a thing to its place — under its own
// heading or another. A heading's name is tapped to rename it or remove it.
// (Spec 04, open item 19: "renaming, reordering or deleting a section and
// reordering rows need a way of working he has not seen … worth a picture first".)
//
// How the order is KEPT: a template's rows are its memberships, read in `order`;
// its headings are `sections`, in their own order. A trip takes the rows in
// `order` and lists its headings by FIRST APPEARANCE of a row under them
// (`buildTotalEntries`, `groupBySection`) — it never reads `sections`' order. So
// every move below also renumbers the rows 0, 1, 2… in the order the page reads by
// Section (each heading's rows in turn, then the rows under no heading). Then a
// new trip, or a rebuilt one, reads exactly as he arranged it, and the numbers
// stay small whole numbers however often he drags (as `saveTemplate` keeps them).
// Only the rows whose number changed are written: the store saves differences.

extension Library {
    /// A heading of this template other than `except` already has this name (by
    /// `normName`: case and spaces do not count). A blank name is never "taken".
    public func sectionNameTaken(templateId: String, name: String, except sectionId: String = "") -> Bool {
        let wanted = normName(name)
        guard !wanted.isEmpty, let t = templates.first(where: { $0.id == templateId }) else { return false }
        return t.sections.contains { $0.id != sectionId && normName($0.name) == wanted }
    }

    /// Rename a heading. The name is trimmed; a blank name, a name another heading
    /// of this template has, an unknown template or heading are refused (false).
    /// A change of case of its own name is allowed. Its rows stay where they are.
    /// (Trips already made keep the words they were made with: a trip's lines carry
    /// the heading's NAME, frozen like everything else on a line.)
    @discardableResult
    public mutating func renameSection(templateId: String, sectionId: String, to name: String) -> Bool {
        let clean = jsTrim(name)
        guard !clean.isEmpty, let t = templates.firstIndex(where: { $0.id == templateId }),
              let s = templates[t].sections.firstIndex(where: { $0.id == sectionId }),
              !sectionNameTaken(templateId: templateId, name: clean, except: sectionId) else { return false }
        guard templates[t].sections[s].name != clean else { return true }
        templates[t].sections[s].name = clean
        templates[t].updatedAt = nowISO()
        return true
    }

    /// Move a heading, with every row under it, to just before the heading
    /// `before` — or after the last heading when `before` is nil. False for an
    /// unknown template, heading or `before`.
    @discardableResult
    public mutating func moveSection(templateId: String, sectionId: String, before: String? = nil) -> Bool {
        guard let t = templates.firstIndex(where: { $0.id == templateId }),
              let from = templates[t].sections.firstIndex(where: { $0.id == sectionId }) else { return false }
        if let before, !templates[t].sections.contains(where: { $0.id == before }) { return false }
        guard before != sectionId else { return true }
        var sections = templates[t].sections
        let moving = sections.remove(at: from)
        let at = before.flatMap { b in sections.firstIndex { $0.id == b } } ?? sections.count
        sections.insert(moving, at: at)
        let moved = sections != templates[t].sections
        templates[t].sections = sections
        if renumberRows(templateId: templateId) || moved { templates[t].updatedAt = nowISO() }
        return true
    }

    /// Take a heading away. Nothing is lost: its rows stay on the template, under
    /// no heading (where they keep their order among the other rows there). False
    /// for an unknown template or heading.
    @discardableResult
    public mutating func removeSection(templateId: String, sectionId: String) -> Bool {
        guard let t = templates.firstIndex(where: { $0.id == templateId }),
              templates[t].sections.contains(where: { $0.id == sectionId }) else { return false }
        templates[t].sections.removeAll { $0.id == sectionId }
        templates[t].updatedAt = nowISO()
        for n in memberships.indices where memberships[n].templateId == templateId && memberships[n].section == sectionId {
            memberships[n].section = ""
        }
        _ = renumberRows(templateId: templateId)
        return true
    }

    /// Move one row of a template under the heading `section` ("" = under no
    /// heading): just before the row `before` when that row sits under the same
    /// heading, else at the end of that heading's rows. Its bag, When, how many,
    /// note and conditions go with it — only its heading and place change. False
    /// for an unknown template or row, or a heading this template does not have.
    @discardableResult
    public mutating func moveRow(templateId: String, memId: String, section: String, before: String? = nil) -> Bool {
        guard let t = templates.firstIndex(where: { $0.id == templateId }),
              section.isEmpty || templates[t].sections.contains(where: { $0.id == section }),
              let n = memberships.firstIndex(where: { $0.id == memId && $0.templateId == templateId }) else { return false }
        var heads = arrangedRows(templateId: templateId)
        // Out of where it was…
        for h in heads.indices { heads[h].rows.removeAll { $0 == memId } }
        // …and into its new heading, before `before` if that row is there.
        guard let h = heads.firstIndex(where: { $0.sectionId == section }) else { return false }
        let at = before.flatMap { b in heads[h].rows.firstIndex(of: b) } ?? heads[h].rows.count
        heads[h].rows.insert(memId, at: at)
        // (A row under a heading id this template does not have is shown under no
        // heading; moved, it is filed there for real.)
        var changed = memberships[n].section != section
        memberships[n].section = section
        changed = setRowOrder(heads.flatMap(\.rows)) || changed
        if changed { templates[t].updatedAt = nowISO() }
        return true
    }

    /// The template's rows (membership ids) as its page reads them by Section:
    /// each heading in turn, with the rows whose `section` is that heading, then
    /// one last group (`sectionId` "") with every other row — no heading, or a
    /// heading id this template does not have (the page shows those under no
    /// heading too). Inside a group the rows keep their `order`, ties as stored.
    public func arrangedRows(templateId: String) -> [(sectionId: String, rows: [String])] {
        guard let t = templates.first(where: { $0.id == templateId }) else { return [] }
        let mine = memberships
            .filter { $0.templateId == templateId }
            .stableSorted(compare: { a, b in jsSign((a.order.isNaN ? 0 : a.order) - (b.order.isNaN ? 0 : b.order)) })
        let known = Set(t.sections.map(\.id))
        var out = t.sections.map { s in (sectionId: s.id, rows: mine.filter { $0.section == s.id }.map(\.id)) }
        out.append((sectionId: "", rows: mine.filter { !known.contains($0.section) }.map(\.id)))
        return out
    }

    /// One line of the page while he arranges: a heading (a section id), the line
    /// that heads the rows under no heading, or a row (a membership id).
    public enum ArrangeLine: Hashable, Sendable { case heading(String), rest, row(String) }

    /// The page while he arranges, top to bottom, as ONE list — so a single drag can
    /// carry a thing from under one heading to under another: every heading, even an
    /// empty one (something can be dragged into it), with its rows; then, when the
    /// template has headings, the "Everything else" line and the rows under no
    /// heading. A template with no headings is just its rows. Rows whose thing is
    /// gone are not shown, as everywhere.
    public func arrangeLines(templateId: String) -> [ArrangeLine] {
        guard let t = templates.first(where: { $0.id == templateId }) else { return [] }
        let things = Set(items.map(\.id))
        let shown = Set(memberships.filter { $0.templateId == templateId && things.contains($0.itemId) }.map(\.id))
        var lines: [ArrangeLine] = []
        for group in arrangedRows(templateId: templateId) {
            if !group.sectionId.isEmpty { lines.append(.heading(group.sectionId)) }
            else if !t.sections.isEmpty { lines.append(.rest) }
            lines += group.rows.filter { shown.contains($0) }.map { .row($0) }
        }
        return lines
    }

    /// A drag on that list: the line at `from` dropped at `to`, counted the way
    /// SwiftUI's `onMove` counts (`to` is a place in the list BEFORE the move). A
    /// heading takes its rows along and lands before the next heading below where
    /// it was dropped (or last); a row goes under the nearest heading above where it
    /// was dropped, before the row that follows it there — dropped above every
    /// heading, it goes to the top of the first. The "Everything else" line never
    /// moves. False when nothing could be done.
    @discardableResult
    public mutating func dropLine(templateId: String, from: Int, to: Int) -> Bool {
        var lines = arrangeLines(templateId: templateId)
        guard lines.indices.contains(from), (0...lines.count).contains(to),
              let t = templates.first(where: { $0.id == templateId }) else { return false }
        let moving = lines.remove(at: from)
        let at = to > from ? to - 1 : to
        lines.insert(moving, at: at)
        let below = lines[(at + 1)...]
        switch moving {
        case .rest:
            return false
        case .heading(let id):
            let next = below.first { if case .row = $0 { return false }; return true }
            if case .heading(let before)? = next { return moveSection(templateId: templateId, sectionId: id, before: before) }
            return moveSection(templateId: templateId, sectionId: id)
        case .row(let id):
            var section: String? = nil
            for line in lines[..<at].reversed() {
                if case .heading(let s) = line { section = s; break }
                if case .rest = line { section = ""; break }
            }
            var before: String? = nil
            if case .row(let b)? = below.first { before = b }
            if section == nil, let first = t.sections.first {
                // Above every heading: the top of the first one.
                section = first.id
                before = nil
                if let h = lines.firstIndex(of: .heading(first.id)), h + 1 < lines.count, case .row(let b) = lines[h + 1] { before = b }
            }
            return moveRow(templateId: templateId, memId: id, section: section ?? "", before: before)
        }
    }

    /// Number this template's rows 0, 1, 2… in the order its page reads. True when
    /// a number changed.
    private mutating func renumberRows(templateId: String) -> Bool {
        setRowOrder(arrangedRows(templateId: templateId).flatMap(\.rows))
    }

    /// Give these memberships the order 0, 1, 2… as listed — changing only the ones
    /// whose number really changes. True when one did.
    private mutating func setRowOrder(_ ids: [String]) -> Bool {
        var at: [String: Int] = [:]
        for (n, m) in memberships.enumerated() { at[m.id] = n }
        var changed = false
        for (place, id) in ids.enumerated() {
            guard let n = at[id], memberships[n].order != Double(place) else { continue }
            memberships[n].order = Double(place)
            changed = true
        }
        return changed
    }
}
