import PackingCore

// His decision on test I.7 (1 Oct 2026): a change to a THING — its bag, weight,
// place, name — reaches the trips he has already made, but only where nothing
// has been decided yet: trips coming up or under way (not reviewed, not over),
// and on them only lines not ticked, not added by hand and not changed on the
// trip itself. Ticked lines, trip-edited lines and finished trips keep what
// they were packed with.
//
// A line is rebuilt the way a new trip would build it — from the template it
// came from, so a bag chosen for that one template still wins over the thing's
// own bag. It keeps its id and whether it was set aside.

extension Library {
    /// Coming up or under way, and not reviewed: what a change may still reach.
    func tripStillAhead(_ trip: TripEvent, today: String) -> Bool {
        guard trip.status != "done", trip.reviewedAt.isEmpty else { return false }
        let start = jsTrim(trip.startDate), end = jsTrim(trip.endDate).isEmpty ? start : jsTrim(trip.endDate)
        return start.isEmpty || end >= today
    }

    /// Bring this thing's open lines on trips still ahead up to date. Returns how
    /// many lines changed.
    @discardableResult
    public mutating func followThing(id: String, today: String = "") -> Int {
        let day = today.isEmpty ? String(nowISO().prefix(10)) : today
        var changed = 0
        var lists: [PackList]?
        for t in trips.indices where tripStillAhead(trips[t], today: day) {
            let open = trips[t].entries.indices.filter {
                let e = trips[t].entries[$0]
                return e.sourceItemId == id && !e.checked && !e.custom && !e.edited
            }
            guard !open.isEmpty else { continue }
            if lists == nil { lists = resolvedTemplates() }
            let fresh = buildTotalEntries(trips[t], lists ?? []).filter { $0.sourceItemId == id }
            var used = Set<Int>()
            var here = 0
            for n in open {
                let old = trips[t].entries[n]
                guard let k = fresh.indices.first(where: { !used.contains($0) && fresh[$0].sourceListId == old.sourceListId })
                        ?? fresh.indices.first(where: { !used.contains($0) }) else { continue }
                used.insert(k)
                var line = fresh[k]
                line.id = old.id
                line.checked = old.checked
                line.skipped = old.skipped
                line.used = old.used
                if line != old { trips[t].entries[n] = line; here += 1 }
            }
            if here > 0 { trips[t].updatedAt = nowISO(); changed += here }
        }
        return changed
    }
}
