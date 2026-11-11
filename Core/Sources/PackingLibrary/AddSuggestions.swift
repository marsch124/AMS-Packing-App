import Foundation
import PackingCore

// The "＋ Add" field on a trip: while he types, his own things that fit are offered,
// and one tap puts that very thing on the trip.

extension Library {
    /// His own things whose name contains what was typed (case and accents ignored),
    /// leaving out reminders, bags, things "not in use" and anything already on the trip.
    /// Names that START with the text come first, then the rest; A–Z in each; each name once.
    public func addSuggestions(tripId: String, typed: String, limit: Int = 4) -> [Item] {
        let needle = fold(jsTrim(typed))
        guard !needle.isEmpty, limit > 0 else { return [] }
        let entries = trip(tripId)?.entries ?? []
        let onTripIds = Set(entries.compactMap { $0.sourceItemId }.filter { !$0.isEmpty })
        let onTripNames = Set(entries.map { fold(jsTrim($0.name)) })
        let bagIds = Set(bags().map(\.id))
        let bagNames = Set(bags().map { fold($0.name) })

        var starts: [(String, Item)] = [], rest: [(String, Item)] = []
        var seen = Set<String>()
        for it in ownThings() {
            let name = fold(jsTrim(it.name))
            guard !name.isEmpty, name.contains(needle),
                  !Library.isReminder(it), !it.retired,
                  !bagIds.contains(it.id), !bagNames.contains(name),
                  !onTripIds.contains(it.id), !onTripNames.contains(name),
                  seen.insert(name).inserted else { continue }
            if name.hasPrefix(needle) { starts.append((name, it)) } else { rest.append((name, it)) }
        }
        let byName: ((String, Item), (String, Item)) -> Bool = { $0.0 < $1.0 }
        return Array((starts.sorted(by: byName) + rest.sorted(by: byName)).map(\.1).prefix(limit))
    }

    /// Put that very thing on the trip as a line: its bag, its "when", its weight, and
    /// the thing it came from — and what goes with it comes too.
    @discardableResult
    public mutating func addOwnThing(tripId: String, itemId: String) -> Item? {
        guard let thing = items.first(where: { $0.id == itemId }),
              var line = addCustomLine(tripId: tripId, name: thing.name,
                                       container: thing.container, phase: thing.phase),
              let t = trips.firstIndex(where: { $0.id == tripId }),
              let e = trips[t].entries.lastIndex(where: { $0.id == line.id }) else { return nil }
        line.sourceItemId = thing.id
        if !thing.category.isEmpty { line.category = thing.category }
        if !thing.swedish.isEmpty { line.swedish = thing.swedish }
        if !thing.itemType.isEmpty { line.itemType = thing.itemType }
        line.liquid = thing.liquid
        if thing.weight > 0 { line.weight = thing.weight }
        trips[t].entries[e] = line
        bringCompanions(tripId: tripId)
        return line
    }

    private func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
