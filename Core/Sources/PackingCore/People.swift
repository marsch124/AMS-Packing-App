// People — the Packers roster (who packs what).
// Ported from js/model.js ("Packers (who packs what)").
//
// Called "People" in the UI until v133; the internal key stays `people`, because
// rows have synced under that name since v120 and renaming it would strand them.
// A small managed roster of people (name + colour). An assignment stores the
// person's NAME on the trip line, so it's self-describing and survives a shared
// trip even on a device without the roster; the colour is only for display.

import Foundation

public let PERSON_COLORS: [String] = ["#3b82f6", "#a855f7", "#22c55e", "#f59e0b", "#ef4444", "#06b6d4", "#ec4899", "#84cc16"]

public struct Person: JSONModel, Hashable, Sendable {
    public var id: String
    public var name: String
    public var color: String
    /// Any key this package does not know — kept so nothing is lost on a round trip.
    public var extra: [String: JSONValue]

    /// The defaults are `newPerson`'s. NOTE this does not coerce — `newPerson(…)` does.
    public init(id: String = PackingEnv.makeId(), name: String = "", color: String = PERSON_COLORS[0],
                extra: [String: JSONValue] = [:]) {
        self.id = id; self.name = name; self.color = color; self.extra = extra
    }

    static let knownKeys: Set<String> = ["id", "name", "color"]

    /// `coercePerson(json)`: a name that is not a string is '', a colour that is not a
    /// hex colour is the first of the palette, and a missing id is made up.
    public init(json: JSONValue) {
        let o = json.objectValue ?? [:]
        // The id is read WITHOUT a default here, so a new one is only made (by the
        // value rules below) when it is really missing — as in JS.
        self.init(id: jsStringOr(o["id"]), name: jsStringOr(o["name"]), color: jsStringOr(o["color"]),
                  extra: extraKeys(o, known: Person.knownKeys))
        self = coercePerson(self)
    }

    public var json: JSONValue {
        var o = extra
        o["id"] = .string(id); o["name"] = .string(name); o["color"] = .string(color)
        return .object(o)
    }
}

/// The value rules of `coercePerson`, for a person built in memory.
public func coercePerson(_ person: Person) -> Person {
    var p = person
    p.name = jsTrim(p.name)
    p.color = isHexColor(p.color) ? p.color : PERSON_COLORS[0]
    if p.id.isEmpty { p.id = PackingEnv.makeId() }
    return p
}
/// `coercePerson(p)` for raw JSON. nil when it is not an object (JS hands the junk back).
public func coercePerson(json p: JSONValue?) -> Person? {
    guard let p = p, p.objectValue != nil else { return nil }
    return Person(json: p)
}

/// `newPerson({ … })` — the same parameters as `Person.init`, then `coercePerson`.
public func newPerson(id: String = PackingEnv.makeId(), name: String = "", color: String = PERSON_COLORS[0],
                      extra: [String: JSONValue] = [:]) -> Person {
    coercePerson(Person(id: id, name: name, color: color, extra: extra))
}
/// `newPerson(person)` — coerce a person already built with `Person(…)`.
public func newPerson(_ person: Person) -> Person { coercePerson(person) }
/// `newPerson(partial)` for a raw JSON partial, laid over the defaults as the JS spreads it.
public func newPerson(json partial: JSONValue) -> Person {
    var o = Person().json.objectValue ?? [:]
    for (k, v) in partial.objectValue ?? [:] { o[k] = v }
    return Person(json: .object(o))
}

/// A stable colour for a person NAME: the roster's colour if known, else a hashed
/// palette pick, so even a name from an imported trip (no roster entry) reads
/// consistently. Returns '' for a blank name.
public func personColor(_ name: String?, _ people: [Person] = []) -> String {
    let n = normName(name)
    if n.isEmpty { return "" }
    if let hit = people.first(where: { normName($0.name) == n }), !hit.color.isEmpty { return hit.color }
    // `hsh = (hsh * 31 + n.charCodeAt(i)) >>> 0` over UTF-16 units: UInt32 wrap-around.
    var hsh: UInt32 = 0
    for unit in n.utf16 { hsh = hsh &* 31 &+ UInt32(unit) }
    return PERSON_COLORS[Int(hsh % UInt32(PERSON_COLORS.count))]
}

/// Distinct packer names actually used across entries, in first-seen order.
public func assignedPeople(_ entries: [Item]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for e in entries {
        let n = jsTrim(e.packer)
        if n.isEmpty || seen.contains(normName(n)) { continue }
        seen.insert(normName(n))
        out.append(n)
    }
    return out
}

/// One block of `groupByPacker`: `{ packer, entries }` — `packer == ""` is the
/// unassigned remainder.
public struct PackerGroup: Equatable, Sendable {
    /// The name as written on the first entry seen for this person.
    public var packer: String
    public var entries: [Item]
    public init(packer: String, entries: [Item]) { self.packer = packer; self.entries = entries }
    public var json: JSONValue { ["packer": .string(packer), "entries": .array(entries.map { $0.json })] }
}

/// Split entries by who packs them — the sub-grouping Packing Mode puts INSIDE each
/// bag, so two people packing the same suitcase each get their own short block.
///
/// `order` is the roster (Settings → Packers) so the blocks come out in the order
/// you arranged your people in, not the alphabet — the person you are is then always
/// in the same place on every screen. A name in use but not on the roster (from a
/// shared trip) follows, A–Z, and the unassigned remainder is ALWAYS last: it is the
/// pile still to be divided, so it should never head the list.
///
/// The entries' own order is preserved within each block, so whatever the caller had
/// already sorted by still holds.
public func groupByPacker(_ entries: [Item], _ order: [String] = []) -> [PackerGroup] {
    var rank: [String: Int] = [:]
    for (i, n) in order.enumerated() {
        let k = normName(n)
        if !k.isEmpty && rank[k] == nil { rank[k] = i }
    }
    // JS holds a Map (normalised name → group); `keys` keeps its insertion order.
    var keys: [String] = []
    var groups: [String: PackerGroup] = [:]
    var none: [Item] = []
    for e in entries {
        let raw = jsTrim(e.packer)
        if raw.isEmpty { none.append(e); continue }
        let k = normName(raw)
        if groups[k] == nil { groups[k] = PackerGroup(packer: raw, entries: []); keys.append(k) }
        groups[k]?.entries.append(e)
    }
    var known: [(key: String, group: PackerGroup)] = []
    var strays: [(key: String, group: PackerGroup)] = []
    for k in keys {
        guard let g = groups[k] else { continue }
        if rank[k] != nil { known.append((k, g)) } else { strays.append((k, g)) }
    }
    known = known.stableSorted(compare: { a, b in (rank[a.key] ?? 0) - (rank[b.key] ?? 0) })
    strays = strays.stableSorted(compare: { a, b in jsLocaleCompare(a.group.packer, b.group.packer, sensitivity: .base) })
    var out = (known + strays).map { $0.group }
    if !none.isEmpty { out.append(PackerGroup(packer: "", entries: none)) }
    return out
}
