import Foundation
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
// own bag. It keeps its id, whether it was set aside, and its own marks (the way
// home's tick, used up, a maintenance note).

extension Library {
    /// Coming up or under way, and not reviewed: what a change may still reach.
    func tripStillAhead(_ trip: TripEvent, today: String) -> Bool {
        guard !Library.isReviewed(trip) else { return false }
        let start = jsTrim(trip.startDate), end = jsTrim(trip.endDate).isEmpty ? start : jsTrim(trip.endDate)
        return start.isEmpty || end >= today
    }

    /// Today as YYYY-MM-DD where he IS — the date every screen goes by (`Today.local` in
    /// the app). The spec pass (5 Oct 2026): this used the UTC date, so in Sweden, just
    /// after midnight, a trip that ended yesterday still counted as ahead and took a
    /// change to a thing (and one behind UTC skipped a trip ending today).
    /// The time zone "today" is read in — the device's own. A test sets another: the
    /// app-wide default time zone does not move `TimeZone.current`, so a test that only
    /// set that passed in Sweden and failed on GitHub's machines, which run on UTC.
    public static var dayZone: () -> TimeZone = { .current }

    public static func localToday(_ now: Date = PackingEnv.now(), zone: TimeZone = Library.dayZone()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let c = cal.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    /// Bring this thing's open lines on trips still ahead up to date. Returns how
    /// many lines changed.
    @discardableResult
    public mutating func followThing(id: String, today: String = "") -> Int {
        let day = today.isEmpty ? Library.localToday() : today
        var changed = 0
        var lists: [PackList]?
        for t in trips.indices where tripStillAhead(trips[t], today: day) {
            let open = trips[t].entries.indices.filter {
                let e = trips[t].entries[$0]
                return e.sourceItemId == id && !e.checked && !e.custom && !e.edited
            }
            guard !open.isEmpty else { continue }
            if lists == nil { lists = templatesForTrips() }   // a thing inside a kit never gets a line (ThingKits)
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
                // The line's own marks are the trip's, not the thing's (the spec pass,
                // 5 Oct 2026): a way-home tick, used up or maintenance note left on a
                // line that was ticked and then unticked was wiped by the next change to
                // its thing. A fresh line carries no marks of its own, so the old ones stay.
                line.extra = old.extra
                if line != old { trips[t].entries[n] = line; here += 1 }
            }
            if here > 0 { trips[t].updatedAt = nowISO(); changed += here }
        }
        return changed
    }
}
