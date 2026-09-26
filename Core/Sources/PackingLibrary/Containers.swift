import Foundation
import PackingCore

// His bags: the things on the one list whose role is "container".
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
    /// The Containers list, if he has one.
    public var containerList: PackList? {
        templates.first { $0.role == CONTAINER_ROLE }
    }

    /// Every bag's weight limit by name — the built-in airline ceilings, overlaid
    /// with the limits he has set on his own bags.
    ///
    /// 🪤 It must be given the RESOLVED lists. `templates` are the lists' shells —
    /// their things live in `memberships` — so `containerLimits(templates)` sees a
    /// Containers list with nothing on it and applies none of his limits. The first
    /// Bags card did exactly that; its test caught it. Always ask here.
    public func bagLimits() -> [String: Double] {
        containerLimits(resolvedTemplates())
    }

    /// His bags, in the list's own order.
    public func bags() -> [Item] {
        guard let list = containerList else { return [] }
        return resolvedTemplate(id: list.id)?.items ?? []
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

    /// A bag, on the Containers list — which is made first if he has none.
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
        if containerList == nil {
            saveTemplate(newList(name: CONTAINER_LIST_NAME, role: CONTAINER_ROLE))
        }
        guard let list = containerList else { return nil }
        let bag = items.first { normName($0.name) == normName(wanted) } ?? addThing(name: wanted)
        guard let bag else { return nil }
        setOnTemplate(itemId: bag.id, templateId: list.id, on: true)
        return items.first { $0.id == bag.id }
    }
}

// MARK: - Renaming, deleting, and what a bag knows

extension Library {
    /// Every field that names a bag, from `old` to `new`: things' own bag, each
    /// list row's exception, each list's default bag, and every trip line (its
    /// bag and the three it remembers). "" as `new` leaves them with no bag.
    mutating func renameBagEverywhere(from old: String, to new: String) {
        let o = normName(old)
        guard !o.isEmpty else { return }
        func swap(_ s: inout String) { if !s.isEmpty && normName(s) == o { s = new } }
        func swapOpt(_ s: inout String?) { if var v = s { swap(&v); s = v } }
        for n in items.indices { swap(&items[n].container) }
        for n in memberships.indices { swap(&memberships[n].container) }
        for n in templates.indices { swap(&templates[n].defaultContainer) }
        for t in trips.indices {
            for e in trips[t].entries.indices {
                swap(&trips[t].entries[e].container)
                swapOpt(&trips[t].entries[e].ovContainer)
                swapOpt(&trips[t].entries[e].tplContainer)
                swapOpt(&trips[t].entries[e].defContainer)
            }
        }
    }

    /// Delete a bag. Its things — and every list row and trip line that names it —
    /// move to `moveTo` first (his choice), which must be another of his bags; ""
    /// only when it is his last bag. The bag leaves the Containers list; the THING
    /// goes too unless it is also packed on a list of his.
    @discardableResult
    public mutating func deleteBag(id: String, moveTo: String) -> Bool {
        guard let list = containerList, let bag = bags().first(where: { $0.id == id }) else { return false }
        let target = jsTrim(moveTo)
        let others = bags().filter { $0.id != id }
        if target.isEmpty {
            guard others.isEmpty else { return false }
        } else {
            guard let to = others.first(where: { normName($0.name) == normName(target) }) else { return false }
            renameBagEverywhere(from: bag.name, to: to.name)
        }
        if target.isEmpty { renameBagEverywhere(from: bag.name, to: "") }
        setOnTemplate(itemId: id, templateId: list.id, on: false)
        if !memberships.contains(where: { $0.itemId == id }) {
            items.removeAll { $0.id == id }
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
            guard let load = bagLoads(t.entries, qtyNights(t), limits).first(where: { normName($0.container) == key }),
                  load.grams > 0 else { continue }
            let date = t.startDate.isEmpty ? String(t.createdAt.prefix(10)) : t.startDate
            went.append(BagTrip(tripId: t.id, name: t.name, date: date, grams: load.grams, limitKg: load.limitKg, over: load.over))
        }
        return BagFacts(things: things, trips: went.stableSorted(compare: { a, b in a.date > b.date ? -1 : (a.date < b.date ? 1 : 0) }))
    }
}
