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
    /// goes, one deleted here stays deleted, every other one stays as it is here. One it changed takes
    /// only the FIELDS the page changed (0.93 trips, 0.94 things, rows and templates, 0.95 to-dos,
    /// kits, "When" steps, settings rows, photos and the library's facts); a field that is a LIST of
    /// things each device adds to — a template's sections, what a kit holds, a thing's photos, his
    /// kinds of thing — is merged as a list (`mergeList`). Nothing changed = this library.
    public func applyingPage(from: Library, to: Library) -> Library {
        guard from != to else { return self }
        var out = self
        out.items = Library.mergeFields(items, from: from.items, to: to.items, id: \.id, lists: Library.thingLists)
        out.memberships = Library.mergeFields(memberships, from: from.memberships, to: to.memberships, id: \.id)
        out.templates = Library.mergeFields(templates, from: from.templates, to: to.templates, id: \.id, stamp: "updatedAt",
                                            lists: ["sections"])
        out.trips = Library.mergeTrips(trips, from: from.trips, to: to.trips)
        out.actions = Library.mergeFields(actions, from: from.actions, to: to.actions, id: \.id, stamp: "updatedAt")
        out.kits = Library.mergeFields(kits, from: from.kits, to: to.kits, id: \.id, stamp: "updatedAt", lists: ["itemIds"])
        out.phases = Library.mergePhases(phases, from: from.phases, to: to.phases)
        out.shared = Library.mergeShared(shared, from: from.shared, to: to.shared)
        // A photo is never changed in place (a new one gets a new id): its time alone is no change.
        out.photos = Library.mergeFields(photos, from: from.photos, to: to.photos, id: \.id, stamp: "createdAt")
        out.meta = Library.mergeMeta(meta, from: from.meta, to: to.meta)
        // Never a photo's bytes lost (0.95): one the page deleted because nothing showed it there any
        // more stays while anything here still shows it (the other device put it somewhere meanwhile).
        let gone = Set(from.photos.map(\.id)).subtracting(to.photos.map(\.id))
        if !gone.isEmpty {
            let shown = out.photoIdsInUse(), have = Set(out.photos.map(\.id))
            for p in photos where gone.contains(p.id) && shown.contains(p.id) && !have.contains(p.id) { out.photos.append(p) }
        }
        return out
    }

    /// A thing's fields that are lists each device adds to (0.95): its photos and what it holds as a kit.
    static let thingLists: Set<String> = ["photos", KIT_CONTENTS_KEY, KIT_OUT_KEY]

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
    /// anything put in moves it on to the later of the two. `lists`: fields merged as lists (`mergeList`).
    static func mergeFields<T: JSONModel>(_ live: [T], from: [T], to: [T], id: (T) -> String, stamp: String? = nil,
                                          lists: Set<String> = []) -> [T] {
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
            guard var o = Library.fieldsPut(was.json, now.json, into: x.json, except: except, lists: lists)?.objectValue else {
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
    /// lacks is taken away); `except` is never touched; a field in `lists` is merged as a list
    /// (`mergeList`). nil when no field differs.
    static func fieldsPut(_ was: JSONValue, _ now: JSONValue, into: JSONValue, except: Set<String>,
                          lists: Set<String> = []) -> JSONValue? {
        let a = was.objectValue ?? [:], b = now.objectValue ?? [:]
        var o = into.objectValue ?? [:]
        var any = false
        for key in Set(a.keys).union(b.keys) where !except.contains(key) && a[key] != b[key] {
            o[key] = lists.contains(key) ? Library.mergeList(o[key], was: a[key], now: b[key]) : b[key]
            any = true
        }
        return any ? .object(o) : nil
    }

    // Lists as lists (0.95, residual of the outside review). A template's sections were ONE field: when
    // each device added a section, the page's list went back and the other device's section was gone
    // (its rows pointing at a section the template no longer had). The same for what a kit holds, a
    // thing's photos, his kinds of thing, a grab list's things.
    //
    // THE RULE, for a list whose entries are each one thing (an id, or a name): what either device
    // added stays; what the page removed goes; one removed here (on the other device) stays removed;
    // an entry both kept takes what the page changed on it (a section's new name). The order is the
    // one HERE, with each entry the page added put just before the entry after it on the page (last,
    // when none is) — unless the page itself moved entries it kept (Arrange): then the PAGE's order,
    // with each entry added here put just before the entry after it here (last, when none is). A list
    // that holds one entry twice cannot be merged by entry: the page's, as before 0.95.

    /// A list-valued field: `live` with what the page did to it (`was` → `now`), by the rule above.
    /// An entry is known by its `id` (an object) or by itself (a name, an id); a field that is no list
    /// is the page's. Nothing left where the page left nothing = no field.
    static func mergeList(_ live: JSONValue?, was: JSONValue?, now: JSONValue?) -> JSONValue? {
        guard was != now else { return live }
        func list(_ v: JSONValue?) -> [JSONValue]? { v == nil || v == .null ? [] : v?.arrayValue }
        guard let l = list(live), let w = list(was), let n = list(now) else { return now }
        let merged = mergeList(l, was: w, now: n, id: listKey) { here, a, b in
            Library.fieldsPut(a, b, into: here, except: []) ?? b
        }
        return merged.isEmpty && (now == nil || now == .null) ? now : .array(merged)
    }

    /// An entry of a list, as `mergeList` knows it.
    static func listKey(_ v: JSONValue) -> String {
        if let id = v["id"]?.stringValue { return "id:" + id }
        if let s = v.stringValue { return "s:" + s }
        return "v:" + String(describing: v)
    }

    /// The rule above for any list: `id` names an entry; `merge` (here, as opened, on the page) is an
    /// entry both kept and the page changed.
    static func mergeList<E: Equatable>(_ live: [E], was: [E], now: [E], id: (E) -> String,
                                        merge: (E, E, E) -> E) -> [E] {
        guard was != now else { return live }
        let l = live.map(id), w = was.map(id), n = now.map(id)
        guard Set(l).count == l.count, Set(w).count == w.count, Set(n).count == n.count else { return now }
        let inLive = Set(l), inWas = Set(w), inNow = Set(n)
        var here: [String: E] = [:], before: [String: E] = [:], page: [String: E] = [:]
        for x in live { here[id(x)] = x }
        for x in was { before[id(x)] = x }
        for x in now { page[id(x)] = x }
        // Who orders the list: the page, when it moved entries it kept; else the list as it is here.
        let pageMoved = n.filter(inWas.contains) != w.filter(inNow.contains)
        let (base, other): ([String], [String]) = pageMoved
            ? (n.filter { !inWas.contains($0) || inLive.contains($0) }, l)      // one removed here stays removed
            : (l.filter { !inWas.contains($0) || inNow.contains($0) }, n)       // one removed on the page goes
        var keys = base
        var placed = Set(keys)
        for (i, k) in other.enumerated() where !placed.contains(k) && !inWas.contains(k) {
            // Added on the other side: just before the entry after it there, else last.
            let next = other[(i + 1)...].first { placed.contains($0) }
            keys.insert(k, at: next.flatMap { keys.firstIndex(of: $0) } ?? keys.count)
            placed.insert(k)
        }
        return keys.map { k in
            if let x = here[k], let a = before[k], let b = page[k] { return a == b ? x : merge(x, a, b) }
            return here[k] ?? page[k]!
        }
    }

    // The two tables with a factory list (0.95). No "When" step stored means the factory seven, and no
    // row of a kind (places, people, conditions) means the factory list: a device that changes one
    // stores the whole list, and one that puts it back stores none. Merged as stored, a step changed on
    // each device was the page's whole seven (the other device's change lost), and a list the page put
    // back to the factory's was "every entry deleted" — the other device's new entry was left alone, as
    // the whole list. So each is merged as SHOWN (the factory list where none is stored) and stored
    // again by the same rule: nothing when it is the factory's.

    /// The "When" steps: `live` with what the page changed (`from` → `to`), field by field, as shown.
    static func mergePhases(_ live: [Phase], from: [Phase], to: [Phase]) -> [Phase] {
        guard from != to else { return live }
        func shown(_ p: [Phase]) -> [Phase] { p.isEmpty ? DEFAULT_PHASES : p }
        let merged = mergeFields(shown(live), from: shown(from), to: shown(to), id: \.id)
            .stableSorted(compare: { a, b in jsOr(jsSign(a.order - b.order), jsLocaleCompare(a.id, b.id)) })
        return phasesCustomised(merged) ? merged : []
    }

    /// The settings rows, kind by kind: each kind the page changed merged field by field, as shown.
    static func mergeShared(_ live: [SharedRow], from: [SharedRow], to: [SharedRow]) -> [SharedRow] {
        guard from != to else { return live }
        var out = live
        for kind in Set(from.map(\.kind)).union(to.map(\.kind)).sorted() {
            let was = from.filter { $0.kind == kind }, now = to.filter { $0.kind == kind }
            guard was != now else { continue }
            let def = defaultListFor(kind)
            let factory = def.isEmpty ? [] : sharedRowsFrom(kind, json: .array(def))
            func shown(_ rows: [SharedRow]) -> [SharedRow] { rows.isEmpty ? factory : rows }
            let merged = mergeFields(shown(live.filter { $0.kind == kind }), from: shown(was), to: shown(now), id: \.id)
            let sorted = merged.stableSorted(compare: { a, b in jsOr(jsSign(a.order - b.order), jsLocaleCompare(a.id, b.id)) })
            let isFactory = !factory.isEmpty && sorted.count == factory.count
                && zip(sorted, factory).allSatisfy { $0.id == $1.id && $0.name == $1.name && $0.data == $1.data }
            out.removeAll { $0.kind == kind }
            if !isFactory { out.append(contentsOf: merged) }
        }
        return out
    }

    /// The library's facts (`meta`), key by key: one the page changed is merged as a value
    /// (`mergeValue`). His kinds of thing are merged as shown (none stored = the app's twelve).
    static func mergeMeta(_ live: [String: JSONValue], from: [String: JSONValue], to: [String: JSONValue]) -> [String: JSONValue] {
        guard from != to else { return live }
        var out = live
        let factory: [String: JSONValue] = [categoriesKey: .array(CATEGORIES.map(JSONValue.string))]
        for key in Set(from.keys).union(to.keys).sorted() where from[key] != to[key] {
            func shown(_ v: JSONValue?) -> JSONValue? { v ?? factory[key] }
            let merged = mergeValue(shown(live[key]), was: shown(from[key]), now: shown(to[key]))
            out[key] = merged == factory[key] ? nil : merged
        }
        return out
    }

    /// One value the page changed (`was` → `now`), onto `live`: a list as a list (`mergeList`), an
    /// object key by key (the lost-luggage desk: the page's e-mail, the other device's phone), anything
    /// else — or a value missing on either side — the page's.
    static func mergeValue(_ live: JSONValue?, was: JSONValue?, now: JSONValue?) -> JSONValue? {
        guard was != now else { return live }
        guard let l = live, let w = was, let n = now else { return now }
        if l.arrayValue != nil, w.arrayValue != nil, n.arrayValue != nil { return mergeList(l, was: w, now: n) }
        guard var o = l.objectValue, let a = w.objectValue, let b = n.objectValue else { return now }
        for key in Set(a.keys).union(b.keys) where a[key] != b[key] { o[key] = mergeValue(o[key], was: a[key], now: b[key]) }
        return .object(o)
    }
}

extension TripEvent {
    /// Trip settings' Save (0.95, residual of the outside review): the screen's answers as it opened
    /// on the trip (`was`) and as Save writes them (`now`) — only the fields it changed are put onto the
    /// trip as it is now. Until 0.95 Save wrote every field the screen shows, so a name, a place or
    /// dates changed on the other device while the screen was open went back.
    public func takingSettings(from was: TripEvent, to now: TripEvent) -> TripEvent { withPage(from: was, to: now) }

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
