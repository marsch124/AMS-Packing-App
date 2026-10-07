import Foundation
import PackingCore

// His bags: the things on the one list whose role is "container".
//
// 🚨 WORDS (his ask, 2026-09-27): the app says BAGS everywhere — never "containers".
// The saved data keeps the web app's names ("container" fields, the list role
// "container", the list called "Containers"): they are the shared format with the
// web app, backups and iCloud, and renaming stored keys is how data gets lost.
// Anything shown to him goes through `shownName` / the word "Bags".
//
// The web app keeps a bag as an ordinary thing on a special "Containers" list, and
// gives it three numbers of its own: what it may carry (maxKg), its size (capacityL)
// and its empty weight (the thing's own `weight`). The trip's Bags card measures a
// bag against maxKg — so this is where a bag GETS a limit.
//
// Bags are joined to things by NAME (`container` is a string), as in the web app.
// So a rename or a delete must carry the name through EVERY field that holds one
// (`renameBagEverywhere`) — or every thing packed in the bag is quietly orphaned
// and its limit stops applying. His choices (2026-09-26): a rename reaches all
// trips, old ones too; a delete first moves its things to a bag he picks.

extension Library {
    /// His bag list (stored as the web app's "Containers" list), if he has one.
    public var bagList: PackList? {
        templates.first { $0.role == CONTAINER_ROLE }
    }

    /// A list's name as he sees it: his bag list is "Bags" (stored as "Containers").
    public func shownName(_ list: PackList) -> String {
        list.role == CONTAINER_ROLE ? "Bags" : list.name
    }

    /// Every bag's weight limit by name — the built-in airline ceilings, overlaid
    /// with the limits he has set on his own bags.
    ///
    /// 🪤 It must be given the RESOLVED lists. `templates` are the lists' shells —
    /// their things live in `memberships` — so `containerLimits(templates)` sees a
    /// bag list with nothing on it and applies none of his limits. The first
    /// Bags card did exactly that; its test caught it. Always ask here.
    public func bagLimits() -> [String: Double] {
        containerLimits(resolvedTemplates())
    }

    /// His bags, in the list's own order.
    public func bags() -> [Item] {
        guard let list = bagList else { return [] }
        return resolvedTemplate(id: list.id)?.items ?? []
    }

    /// Every bag a thing can be "usually packed in": HIS bags — the ones on Your bags,
    /// in that list's order, each once — and nothing else. His word (6 Oct 2026): "No
    /// Triathlon bag in the Bag List … why does it not disappear?" Until 0.64 the web
    /// app's 17 built-in names (`CONTAINERS`) always came first, so a bag he never had,
    /// or had deleted, was still offered. A library with no bags of its own yet is
    /// offered the built-in names, so a first thing still has somewhere to go. ONE
    /// answer for the thing's page, a template's row, the table and Change all.
    /// (`containerNames`, the web app's own answer, stays as it is for the parity check.)
    public func bagNames() -> [String] {
        var seen = Set<String>()
        let mine = bags().map { jsTrim($0.name) }.filter { !$0.isEmpty && seen.insert(normName($0)).inserted }
        return mine.isEmpty ? CONTAINERS : mine
    }

    /// The templates a thing is put on or taken off from its own page and from the
    /// table: every one but his bag list. A thing becomes a bag on Your bags, where a
    /// bag's rules live — the table's "Bags" column made a bag of anything ticked in
    /// it, and unticking a bag dropped it without asking where its things go (the
    /// spec pass, 5 Oct 2026).
    public func templatesForThings() -> [PackList] {
        templates.filter { $0.role != CONTAINER_ROLE }
    }

    /// Set a bag's numbers. Blank or negative is taken as "not set".
    @discardableResult
    public mutating func setBag(id: String, maxKg: Double? = nil, capacityL: Double? = nil,
                                emptyGrams: Double? = nil) -> Bool {
        guard bags().contains(where: { $0.id == id }) else { return false }
        return updateThing(id: id) { bag in
            if let maxKg { bag.maxKg = max(0, maxKg) }
            if let capacityL { bag.capacityL = max(0, capacityL) }
            if let emptyGrams { bag.weight = max(0, emptyGrams) }
        }
    }

    /// A bag, on his bag list — which is made first if he has none.
    ///
    /// A name he already has a BAG by is refused: two bags with one name would be one
    /// bag to every trip, because bags are joined by name. But a THING he already owns
    /// by that name (a toiletry bag he has only ever packed) is not refused — it
    /// becomes a bag. Refusing it would leave him no way to give it a limit, and
    /// making a second thing of the same name is refused by `addThing` anyway.
    @discardableResult
    public mutating func addBag(name: String) -> Item? {
        let wanted = jsTrim(name)
        guard !wanted.isEmpty, !bags().contains(where: { normName($0.name) == normName(wanted) }) else { return nil }
        if bagList == nil {
            saveTemplate(newList(name: CONTAINER_LIST_NAME, role: CONTAINER_ROLE))
        }
        guard let list = bagList else { return nil }
        let bag = items.first { normName($0.name) == normName(wanted) } ?? addThing(name: wanted)
        guard let bag else { return nil }
        setOnTemplate(itemId: bag.id, templateId: list.id, on: true)
        return items.first { $0.id == bag.id }
    }
}

// MARK: - Renaming, deleting, and what a bag knows

extension Library {
    /// Every field that names a bag, from `old` to `new`: things' own bag, each
    /// list row's exception, each list's default bag, every trip line (its bag and
    /// the three it remembers), and what each trip keeps about the bag — the scale
    /// reading and the photos of it packed. "" as `new` leaves them with no bag.
    mutating func renameBagEverywhere(from old: String, to new: String) {
        let o = normName(old)
        guard !o.isEmpty else { return }
        func swap(_ s: inout String) { if !s.isEmpty && normName(s) == o { s = new } }
        func swapOpt(_ s: inout String?) { if var v = s { swap(&v); s = v } }
        for n in items.indices { swap(&items[n].container) }
        for n in memberships.indices { swap(&memberships[n].container) }
        for n in templates.indices { swap(&templates[n].defaultContainer) }
        var dropped: [String] = []
        for t in trips.indices {
            // Asked BEFORE the lines move: did the new name already carry things of
            // its own on this trip? Then this is two bags made one, not a new name.
            let joinsAnother = !new.isEmpty && trips[t].entries.contains { $0.container == new }
            for e in trips[t].entries.indices {
                swap(&trips[t].entries[e].container)
                swapOpt(&trips[t].entries[e].ovContainer)
                swapOpt(&trips[t].entries[e].tplContainer)
                swapOpt(&trips[t].entries[e].defContainer)
            }
            dropped += moveBagNotes(trip: t, from: o, to: new, joinsAnother: joinsAnother)
        }
        // A photo pushed out by the three-photo limit goes the way `removeBagPhoto`
        // sends one: its record too, unless something else still shows it.
        for id in dropped where !photoInUse(id) { photos.removeAll { $0.id == id } }
    }

    /// What one trip keeps about a bag BY ITS NAME — the luggage scale's reading
    /// (`weighed`) and the photos of it packed (`bagPhotos`) — moved from every key
    /// that is the old name (as `normName` sees it) to the new one. Until 3 Oct 2026
    /// a rename left them under the old name: nothing was deleted, but the trip's
    /// reading and photos silently vanished from view.
    ///
    /// Both are kept under the name the trip's Bags card shows (`bagLoads`), so a
    /// line with NO bag is "Other" there — the photos of a bag deleted with "no bag"
    /// follow its things to "Other" ("Not in a bag" on the way home).
    ///
    /// Photos: where the new name already has its own (two bags made one, by a rename
    /// or by a delete that moves the things into another bag), its own come first,
    /// then the moved ones, up to three — the most a bag shows. The ids beyond that
    /// are returned, for the caller to let go. A photo is still a true picture of how
    /// those things went in, wherever they are now said to be.
    ///
    /// The scale reading is different: it is what ONE bag weighed, with what was in it
    /// then, and once kept it is the weight the bag is judged by (over its limit or
    /// not). So it goes along only where the bag is simply renamed — the new name had
    /// neither a reading nor things of its own on that trip (`joinsAnother`). Where
    /// two bags became one, the bag kept keeps its own reading, or none: handed the
    /// other bag's, it would be judged by a weight that never included its own things.
    /// With "no bag" the reading goes too: "Other" is loose things, never weighed as one.
    private mutating func moveBagNotes(trip t: Int, from o: String, to new: String, joinsAnother: Bool) -> [String] {
        let target = new.isEmpty ? "Other" : new
        func movable(_ keys: Dictionary<String, JSONValue>.Keys) -> [String] {
            keys.filter { $0 != target && normName($0) == o }.sorted()
        }
        if var scale = trips[t].extra[WEIGHED_KEY]?.objectValue, !movable(scale.keys).isEmpty {
            var goesAlong = !new.isEmpty && !joinsAnother && (scale[target]?.finiteNumber ?? 0) <= 0
            for key in movable(scale.keys) {
                let reading = scale.removeValue(forKey: key)
                if goesAlong, let g = reading?.finiteNumber, g > 0 { scale[target] = reading; goesAlong = false }
            }
            trips[t].extra[WEIGHED_KEY] = scale.isEmpty ? nil : .object(scale)
        }
        var dropped: [String] = []
        if var shots = trips[t].extra[BAG_PHOTOS_KEY]?.objectValue, !movable(shots.keys).isEmpty {
            var ids = Library.bagPhotoIds(shots[target])
            for key in movable(shots.keys) {
                for id in Library.bagPhotoIds(shots.removeValue(forKey: key)) where !ids.contains(id) {
                    if ids.count < BAG_PHOTOS_MAX { ids.append(id) } else { dropped.append(id) }
                }
            }
            shots[target] = ids.isEmpty ? nil : .array(ids.map(JSONValue.string))
            trips[t].extra[BAG_PHOTOS_KEY] = shots.isEmpty ? nil : .object(shots)
        }
        return dropped
    }

    /// Is anything packed in this bag — a thing's own bag, a list row's or a list's
    /// default, or a line on any trip? A bag nothing names can simply go.
    public func bagIsUsed(name: String) -> Bool {
        let k = normName(name)
        guard !k.isEmpty else { return false }
        func hit(_ s: String?) -> Bool { normName(s ?? "") == k }
        return items.contains { hit($0.container) }
            || memberships.contains { hit($0.container) }
            || templates.contains { hit($0.defaultContainer) }
            || trips.contains { $0.entries.contains { hit($0.container) || hit($0.ovContainer) || hit($0.tplContainer) || hit($0.defContainer) } }
    }

    /// The lists (not his bag list) a bag also sits on AS A THING — the Day pack he
    /// packs on Travel. Deleting such a bag asks whether it goes from those too.
    public func listsHoldingBag(id: String) -> [String] {
        templates.filter { t in t.role != CONTAINER_ROLE && memberships.contains { $0.itemId == id && $0.templateId == t.id } }
            .map(\.name)
    }

    /// Delete a bag. Everything that names it — things, list rows and trip lines —
    /// moves to `moveTo` first (his choice), another of his bags; or, with "", to
    /// NO bag (his ask, 2026-09-27: "an alternative… to not choose… do not use
    /// another bag"). The bag leaves his bag list; the THING goes too
    /// unless it is also packed on a list of his.
    ///
    /// `completely`: also off every list, and the thing is gone (his choice each
    /// time, 2026-09-27 — "I thought it would just be a deleted bag").
    /// What each trip kept about the bag goes where its things go (see `moveBagNotes`):
    /// its photos to the bag he picks, or with no bag to the things left without one.
    /// Its scale reading goes along only to a bag that had nothing of its own on that
    /// trip; otherwise that bag keeps its own reading, or none.
    @discardableResult
    public mutating func deleteBag(id: String, moveTo: String, completely: Bool = false) -> Bool {
        guard let list = bagList, let bag = bags().first(where: { $0.id == id }) else { return false }
        let target = jsTrim(moveTo)
        let others = bags().filter { $0.id != id }
        // Its pockets go with it: a thing or line moved to another bag is in that bag,
        // not in a pocket the other bag may not have (0.69).
        if target.isEmpty || others.contains(where: { normName($0.name) == normName(target) }) {
            forgetPockets(ofBag: bag.name)
        }
        if target.isEmpty {
            renameBagEverywhere(from: bag.name, to: "")
        } else {
            guard let to = others.first(where: { normName($0.name) == normName(target) }) else { return false }
            renameBagEverywhere(from: bag.name, to: to.name)
        }
        setOnTemplate(itemId: id, templateId: list.id, on: false)
        if completely || !memberships.contains(where: { $0.itemId == id }) {
            _ = deleteThing(id: id, evenABag: true)
        }
        return true
    }

    /// One trip a bag went on, and how heavy it was.
    public struct BagTrip: Equatable, Sendable {
        public var tripId: String
        public var name: String
        /// "2026-09-21" — the trip's first day, or the day it was made.
        public var date: String
        public var grams: Double
        public var limitKg: Double
        public var over: Bool
    }

    /// What a bag's page shows: the things that usually go in it (their own bag,
    /// or a list's exception), and the trips it went on, newest first.
    public struct BagFacts: Equatable, Sendable {
        public var things: [Item]
        public var trips: [BagTrip]
        public var heaviest: BagTrip? { trips.max { $0.grams < $1.grams } }
    }

    public func bagFacts(name: String) -> BagFacts {
        let key = normName(name)
        var ids = Set<String>()
        for it in items where normName(it.container) == key { ids.insert(it.id) }
        for m in memberships where normName(m.container) == key { ids.insert(m.itemId) }
        let bagIds = Set(bags().map(\.id))
        let things = items.filter { ids.contains($0.id) && !bagIds.contains($0.id) }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
        let limits = bagLimits()
        var went: [BagTrip] = []
        for t in trips {
            guard let load = bagLoads(linesWithKitWeights(t.entries), qtyNights(t), limits).first(where: { normName($0.container) == key }),
                  load.grams > 0 else { continue }
            let date = t.startDate.isEmpty ? String(t.createdAt.prefix(10)) : t.startDate
            went.append(BagTrip(tripId: t.id, name: t.name, date: date, grams: load.grams, limitKg: load.limitKg, over: load.over))
        }
        return BagFacts(things: things, trips: went.stableSorted(compare: { a, b in a.date > b.date ? -1 : (a.date < b.date ? 1 : 0) }))
    }
}
