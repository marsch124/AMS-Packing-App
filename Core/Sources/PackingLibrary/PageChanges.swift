import Foundation
import PackingCore

// Cancel everywhere (0.92). His words, 19 Oct 2026: "I open an item and change some property. How
// do I cancel that? There is only a Done button, right?" — and "the cancel function should be
// existing throughout the whole app right?"
//
// A page whose controls change the library at once (a template's page, Your choices) works on a
// COPY of the library while it is open (`PageDraft` in the app). Cancel throws the copy away. Save
// hands over what the page changed — only that: every record the page did not touch keeps what the
// real library holds now, so a change from the other device while the page was open is not undone.

extension Library {
    /// This library with what a page changed on its copy — the copy as it opened (`from`) and as
    /// it is now (`to`) — put in. Per record, by id: one the page added is the page's, one it deleted
    /// goes, every other one stays as it is here. One it changed: things, rows, templates and trips
    /// take only the FIELDS the page changed (0.93 trips, 0.94 the rest of a template page's work);
    /// the smaller tables (to-dos, kits, "When" steps, settings rows, photos) the page's whole record.
    /// Nothing changed = this library.
    public func applyingPage(from: Library, to: Library) -> Library {
        guard from != to else { return self }
        var out = self
        out.items = Library.mergeFields(items, from: from.items, to: to.items, id: \.id)
        out.memberships = Library.mergeFields(memberships, from: from.memberships, to: to.memberships, id: \.id)
        out.templates = Library.mergeFields(templates, from: from.templates, to: to.templates, id: \.id, stamp: "updatedAt")
        out.trips = Library.mergeTrips(trips, from: from.trips, to: to.trips)
        out.actions = Library.merge(actions, from: from.actions, to: to.actions, id: \.id)
        out.kits = Library.merge(kits, from: from.kits, to: to.kits, id: \.id)
        out.phases = Library.merge(phases, from: from.phases, to: to.phases, id: \.id)
        out.shared = Library.merge(shared, from: from.shared, to: to.shared, id: \.id)
        out.photos = Library.merge(photos, from: from.photos, to: to.photos, id: \.id)
        for (key, value) in to.meta where from.meta[key] != value { out.meta[key] = value }
        for key in from.meta.keys where to.meta[key] == nil { out.meta[key] = nil }
        return out
    }

    // A trip, its head and each of its lines on their own (0.93, the outside review of 0.92 — his
    // "fix 1, 2 and 6"). A page never edits a trip itself, but what it does reaches the trips ahead:
    // a thing renamed or a row saved rewrites the thing's open lines (`followThing`, which also
    // stamps the trip's `updatedAt`), a place or an owner renamed in Your choices is carried into
    // every line. Handed over as whole trips, the page's copy from when it opened — with ALL its
    // lines — replaced the real one: a tick or a line added on the other device meanwhile was
    // undone or deleted. Now only the fields the page changed are put in, line by line, and on the
    // trip's head; the stamp alone is no change; a trip or a line deleted on the other device
    // stays deleted (the page never deletes or adds one on purpose — what it touched there was a
    // follow).

    /// The trips: `live` with what the page changed on its copy (`from` → `to`) put in, field by
    /// field. A trip the page added comes last; one it deleted goes.
    static func mergeTrips(_ live: [TripEvent], from: [TripEvent], to: [TripEvent]) -> [TripEvent] {
        guard from != to else { return live }
        var before: [String: TripEvent] = [:]
        for t in from { before[t.id] = t }
        var after: [String: TripEvent] = [:]
        for t in to { after[t.id] = t }
        var out: [TripEvent] = []
        var placed = Set<String>()
        for trip in live {
            placed.insert(trip.id)
            guard let was = before[trip.id] else { out.append(trip); continue }   // new here since the page opened
            guard let now = after[trip.id] else { continue }                      // the page deleted it
            out.append(was == now ? trip : trip.withPage(from: was, to: now))
        }
        for t in to where before[t.id] == nil && !placed.contains(t.id) {          // the page made it
            out.append(t)
            placed.insert(t.id)
        }
        return out
    }

    /// A trip's lines: `live` with the fields the page changed put in, line by line. A line the
    /// page added comes last; one it deleted goes; one gone here stays gone.
    static func mergeLines(_ live: [Item], from: [Item], to: [Item]) -> [Item] {
        guard from != to else { return live }
        var before: [String: Item] = [:]
        for x in from { before[x.id] = x }
        var after: [String: Item] = [:]
        for x in to { after[x.id] = x }
        var out: [Item] = []
        var placed = Set<String>()
        for x in live {
            placed.insert(x.id)
            guard let was = before[x.id] else { out.append(x); continue }
            guard let now = after[x.id] else { continue }
            if was == now { out.append(x); continue }
            let merged = Library.fieldsPut(was.json, now.json, into: x.json, except: [])
            out.append(merged.map { Item(json: $0) } ?? x)
        }
        for x in to where before[x.id] == nil && !placed.contains(x.id) {
            out.append(x)
            placed.insert(x.id)
        }
        return out
    }

    // Things, rows and templates field by field too (0.94, the open point of 0.93's report). Handed
    // over whole, a thing the page touched — its note written, or a follow of a place renamed in Your
    // choices — went back to the page's copy of it: the bag the other device chose for it meanwhile
    // was undone. The same for a row (its count) and a template (its colour). Now only the fields the
    // page changed are put onto the record as it is here; a record deleted on the other device stays
    // deleted, as a trip does (there is nothing here to put the page's fields onto).

    /// One table, field by field: `live` with the fields the page changed (`from` → `to`) put onto
    /// each record as it is here; what the page added comes last, in the page's order; what it deleted
    /// goes; one gone here stays gone. `stamp` (a template's `updatedAt`) is no change of its own:
    /// anything put in moves it on to the later of the two.
    static func mergeFields<T: JSONModel>(_ live: [T], from: [T], to: [T], id: (T) -> String, stamp: String? = nil) -> [T] {
        guard from != to else { return live }
        var before: [String: T] = [:]
        for x in from { before[id(x)] = x }
        var after: [String: T] = [:]
        for x in to { after[id(x)] = x }
        let except: Set<String> = stamp.map { [$0] } ?? []
        var out: [T] = []
        var placed = Set<String>()
        for x in live {
            let key = id(x)
            placed.insert(key)
            guard let was = before[key] else { out.append(x); continue }   // new here since the page opened
            guard let now = after[key] else { continue }                   // the page deleted it
            if was == now { out.append(x); continue }
            guard var o = Library.fieldsPut(was.json, now.json, into: x.json, except: except)?.objectValue else {
                out.append(x); continue                                     // only the stamp moved
            }
            if let s = stamp, let mine = now.json[s]?.stringValue, let here = x.json[s]?.stringValue {
                o[s] = .string(max(mine, here))
            }
            out.append(T(json: .object(o)))
        }
        for x in to where before[id(x)] == nil && !placed.contains(id(x)) {        // the page made it
            out.append(x)
            placed.insert(id(x))
        }
        return out
    }

    /// `into` with every field that differs between `was` and `now` set to `now`'s (a field `now`
    /// lacks is taken away); `except` is never touched. nil when no field differs.
    static func fieldsPut(_ was: JSONValue, _ now: JSONValue, into: JSONValue, except: Set<String>) -> JSONValue? {
        let a = was.objectValue ?? [:], b = now.objectValue ?? [:]
        var o = into.objectValue ?? [:]
        var any = false
        for key in Set(a.keys).union(b.keys) where !except.contains(key) && a[key] != b[key] {
            o[key] = b[key]
            any = true
        }
        return any ? .object(o) : nil
    }

    /// One table: `live` with the page's changes (`from` → `to`) put in, in `live`'s order; what
    /// the page added comes last, in the page's order.
    static func merge<T: Equatable>(_ live: [T], from: [T], to: [T], id: (T) -> String) -> [T] {
        guard from != to else { return live }
        var before: [String: T] = [:]
        for x in from { before[id(x)] = x }
        var after: [String: T] = [:]
        for x in to { after[id(x)] = x }
        // What the page changed or added, and what it deleted.
        var changed: [String: T] = [:]
        for x in to where before[id(x)] != x { changed[id(x)] = x }
        let deleted = Set(before.keys.filter { after[$0] == nil })
        guard !changed.isEmpty || !deleted.isEmpty else { return live }
        var out: [T] = []
        var placed = Set<String>()
        for x in live {
            let key = id(x)
            if deleted.contains(key) { continue }
            out.append(changed[key] ?? x)
            placed.insert(key)
        }
        for x in to where changed[id(x)] != nil && !placed.contains(id(x)) {
            out.append(x)
            placed.insert(id(x))
        }
        return out
    }
}

extension TripEvent {
    /// This trip with what a page changed on its copy of it (`from` → `to`): the head field by
    /// field — the time it was last changed is no change of its own — and the lines line by line.
    /// Anything put in moves the time on to the later of the two.
    func withPage(from was: TripEvent, to now: TripEvent) -> TripEvent {
        var out = self
        if let head = Library.fieldsPut(was.json, now.json, into: json, except: ["entries", "updatedAt"]) {
            out = TripEvent(json: head)
        }
        out.entries = Library.mergeLines(entries, from: was.entries, to: now.entries)
        if out != self, now.updatedAt > out.updatedAt { out.updatedAt = now.updatedAt }
        return out
    }
}
