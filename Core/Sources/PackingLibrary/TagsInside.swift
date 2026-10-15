import Foundation
import PackingCore

// No tags inside another bag (0.86) — his yes of 15 Oct 2026: "Yes - no tags inside another bag".
// Packing Stations' Tags asked for a name tag (and an AirTag) on EVERY bag of the trip — a toiletry
// bag packed inside the suitcase too. A bag inside another never goes through the airport on its
// own, so it needs no name tag: Tags now lists only the bags that travel by themselves, and one
// quiet line under the cards names the ones left out. (Spec 07, part 17, "0.86".)
//
// HOW THE APP KNOWS (decided by the build): by the TRIP's own lines, never by the thing alone. A bag
// is inside another on this trip when its OWN line — the line of its thing (by the thing's id when it
// is one of his bags, else by its name), not set aside and not a reminder — is packed in ANOTHER of
// the trip's bags. That line's bag is what he sees on the trip's list (the bag's heading, sorted by
// Into); it comes from the thing's Usually packed in (through the template's row) and follows a
// change to it while the line is open (ThingFollows). A bag with no line of its own on the trip is
// taken to travel by itself: the thing's Usually packed in is NOT read on its own, because every
// thing the app (or the web app) makes starts "Usually packed in: Carry-on / hand luggage" — new
// bags included — so the app cannot tell his choice from the default, and trusting it would drop
// the Day pack (or the suitcase) from Tags on any trip with a carry-on. Nothing new is stored.

extension Library {
    /// The bag each of `bags` (a trip's bags, as its Bags card names them) is packed INSIDE on this
    /// trip — `[bag: the bag it is in]`, both as the trip names them; a bag that travels by itself
    /// is not in it. By its own line on the trip (see above). A ring — A inside B and B inside A —
    /// has nothing outside it: a bag whose chain leads back to itself travels by itself (and so is
    /// asked about); a bag inside a ring's bag is still inside that bag.
    public func bagsInside(_ trip: TripEvent, bags: [String]) -> [String: String] {
        // The trip's bag of a name, as the trip spells it.
        func tripBag(_ name: String) -> String? {
            let key = normName(name)
            return bags.first { $0 == name } ?? bags.first { normName($0) == key }
        }
        let his = self.bags()
        // Each bag's own line, and the OTHER trip bag it is packed in.
        var direct: [String: String] = [:]          // keyed by normName(bag)
        for bag in bags {
            let key = normName(bag)
            guard Library.isRealBag(jsTrim(bag)) else { continue }
            let thing = his.first { normName($0.name) == key }
            let own = trip.entries.first { e in
                guard !Library.isReminder(e), !isSetAside(e) else { return false }
                guard normName(e.name) == key || (thing != nil && e.sourceItemId == thing?.id) else { return false }
                let c = jsTrim(e.container)
                return Library.isRealBag(c) && normName(c) != key && tripBag(c) != nil
            }
            if let own, let outer = tripBag(jsTrim(own.container)) { direct[key] = outer }
        }
        var out: [String: String] = [:]
        for bag in bags {
            let key = normName(bag)
            guard let outer = direct[key] else { continue }
            // Outwards along the chain; back at this bag = a ring.
            var seen: Set<String> = [key]
            var at = outer
            var ring = false
            while true {
                let k = normName(at)
                if k == key { ring = true; break }
                guard seen.insert(k).inserted, let next = direct[k] else { break }
                at = next
            }
            if !ring { out[bag] = outer }
        }
        return out
    }

    /// The bag a trip's bag is packed inside on this trip ("" = it travels by itself, or no such
    /// trip) — what Tags goes by.
    public func bagInside(tripId: String, bag: String) -> String {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return "" }
        let all = dayBags(tripId: tripId)
        guard let name = all.first(where: { normName($0) == normName(bag) }) else { return "" }
        return bagsInside(trip, bags: all)[name] ?? ""
    }
}

extension PackingDay {
    /// The bags Tags asks about: those that travel by themselves — not one packed inside another
    /// bag on this trip (0.86). In the trip's order.
    public var tagged: [Bag] { bags.filter { $0.inside.isEmpty } }

    /// The bags Tags leaves out: each packed inside another bag on this trip. In the trip's order.
    public var insideAnother: [Bag] { bags.filter { !$0.inside.isEmpty } }

    /// The one quiet line under Tags' cards, in his own words — "No tags inside another bag:
    /// Toiletry bag (in the Suitcase), Tech pouch (in the Day pack)." — "" when every bag travels
    /// by itself.
    public var tagsInsideWords: String {
        let inner = insideAnother
        guard !inner.isEmpty else { return "" }
        return "No tags inside another bag: " + inner.map { "\($0.name) (in the \($0.inside))" }.joined(separator: ", ") + "."
    }
}
