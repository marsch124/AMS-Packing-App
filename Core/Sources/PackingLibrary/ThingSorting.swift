import Foundation
import PackingCore

// Sorting the things table by more than one column — his ask, 4 Oct 2026: "a nested
// sorting functionality … sorting on travel as a top sort criterion and then
// sorting on section as an under criterion." Up to three levels; each one only
// decides between things the levels above it call equal, and the name settles the
// rest.
//
// A template sorts two ways: by being on it (on it first), and by its sections in
// the template's own order ("Travel · section"). So Travel, then Travel · section,
// lists the things on Travel section by section, and everything else after.

/// One level of the order: which column, and which way round.
public struct SortLevel: Equatable, Sendable, Codable {
    public var key: String
    public var descending: Bool
    public init(key: String, descending: Bool = false) { self.key = key; self.descending = descending }
}

/// The levels a table holds at most.
public let SORT_LEVELS_MAX = 3

extension Library {
    /// One comparable value per thing and column. nil = blank: a blank goes LAST
    /// whichever way the level runs — the gaps belong at the end, because the point
    /// of sorting by a column here is usually to fill it in.
    public func sortValue(_ thing: Item, key: String, memberships byThing: [String: [Membership]]) -> String? {
        let mine = byThing[thing.id] ?? []
        if key == "name" { return normName(thing.name) }
        if let path = Library.textFields[key] {
            let text = normName(thing[keyPath: path])
            return text.isEmpty ? nil : text
        }
        if let path = Library.flagFields[key] { return thing[keyPath: path] ? "0" : "1" }
        switch key {
        case "weight":
            let grams = packedWeight(thing)      // a kit with what is inside it (ThingKits)
            return grams > 0 ? String(format: "%012.2f", grams) : nil
        case "listQty":
            guard mine.count == 1, let n = Double(jsTrim(mine[0].qty)) else { return nil }
            return String(format: "%012.2f", n)
        case "listSection":
            guard mine.count == 1, let list = templates.first(where: { $0.id == mine[0].templateId }),
                  let section = list.sections.first(where: { $0.id == mine[0].section }) else { return nil }
            return normName(section.name)
        default:
            if key.hasPrefix("list:") {
                let listId = String(key.dropFirst(5))
                return mine.contains { $0.templateId == listId } ? "0" : "1"
            }
            if key.hasPrefix("section:") {
                // The template's own section order; on it without a section comes
                // after its sections; not on it at all is blank.
                let listId = String(key.dropFirst(8))
                guard let list = templates.first(where: { $0.id == listId }) else { return nil }
                let here = mine.filter { $0.templateId == listId }
                guard !here.isEmpty else { return nil }
                let place = here.map { m in list.sections.firstIndex { $0.id == m.section } ?? list.sections.count }.min()!
                return String(format: "%04d", place)
            }
            return nil
        }
    }

    /// The things in the order the levels say.
    public func sortThings(_ things: [Item], by levels: [SortLevel]) -> [Item] {
        let byThing = Dictionary(grouping: memberships, by: \.itemId)
        let keyed = things.map { thing in
            (thing, levels.prefix(SORT_LEVELS_MAX).map { sortValue(thing, key: $0.key, memberships: byThing) }, normName(thing.name))
        }
        // Compared the way Your things and the templates compare names (å, ä, ö, é
        // in their proper places), not by code point: the table put "Éclair" after
        // "Zip" while every other screen put it after "Apple" (the spec pass, 5 Oct
        // 2026). Numbers are zero-padded, so they compare the same either way.
        let sorted = keyed.sorted { a, b in
            for (n, level) in levels.prefix(SORT_LEVELS_MAX).enumerated() {
                let x = a.1[n], y = b.1[n]
                switch (x, y) {
                case (nil, nil): continue
                case (nil, _): return false
                case (_, nil): return true
                case let (x?, y?):
                    let c = jsLocaleCompare(x, y, sensitivity: .base)
                    if c == 0 { continue }
                    return level.descending ? c > 0 : c < 0
                }
            }
            let byName = jsLocaleCompare(a.2, b.2, sensitivity: .base)
            return byName != 0 ? byName < 0 : a.2 < b.2      // "a" and "á": one fixed order
        }
        return sorted.map(\.0)
    }
}
