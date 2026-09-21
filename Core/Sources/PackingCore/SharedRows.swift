// SharedRows — the author-made Settings lists, in ONE shared store.
// Ported from js/model.js ("The five author-made Settings lists, in ONE shared store").
//
// Conditions · Trip presets · Packers · Owners · Storage places (· grab lists, v163).
//
// Until v120 each of these lived in the browser's localStorage, which meant a list
// you AUTHORED on the Mac simply did not exist on the iPhone. That showed up
// differently in each one, and all five were real:
//   • a condition invented on one device reached the other as raw text — the ITEM
//     carries the condition's id, and only the list holds its readable name;
//   • a trip preset saved on one was absent on the other with nothing to hint at it;
//   • a person could be blue here and green there, because only the NAME travels
//     on a trip line and the colour lives in the roster;
//   • owners and storage places self-heal (both are plain text on the item), but
//     “Bedroom wardrobe” describes one house, not one device.
//
// The line drawn, deliberately: LISTS YOU AUTHOR SYNC; HOW A DEVICE LOOKS AND
// BEHAVES DOES NOT.
//
// All share ONE store, and — the part that matters — ONE ROW PER ENTRY rather than
// one row per list. A row is the unit the sync merges, so a person added here and a
// place added there both survive. Holding a whole list in a single record would make
// the last device to save win outright and drop the other's additions without a trace.
//
// The row is deliberately plain:
//   id     `${kind}:${key}` — STABLE, so two devices that add “Garage shelf”
//          independently land on the SAME key and merge instead of doubling it
//          (the 880-item lesson). Never a random id.
//   kind   which of the lists the row belongs to
//   key    its identity within that list: the normalised NAME for the name-keyed
//          lists; for a condition, its own slug id
//   name   the display spelling
//   order  position, for the lists where order is something you set
//   data   everything else, NESTED — so no field of ours can ever collide with the
//          `owner` and `realmId` properties the sync addon reserves for itself.
//          See what that collision cost in v117: 422 items stamped with an e-mail.
//
// 🚨 NOTHING IS EVER SEEDED INTO THIS STORE. The factory conditions, the factory
// people and the standard storage places live in the CODE; a kind with no rows
// means “use the defaults”, and your first real edit is what writes rows. v118
// seeded factory phases into shared data using stable ids and they landed exactly
// on top of Martin's customised rows and replaced them — stable ids prevent
// duplication precisely BY overwriting. Same mechanism, so: never seed.
//
// 🚨 'grab' (v163) is a SIXTH KIND IN THIS EXISTING TABLE, and that is the whole
// point of doing it this way. A synced table of its own would have walked straight
// back into the v120 fault: a device already syncing does a new table's one first
// full download whenever it next connects, and if the table is empty at that moment
// it downloads nothing and records the table as done for ever. New ROWS in a table
// that is already syncing are ordinary changes — the one thing that has demonstrably
// worked all along (v124).

import Foundation

public let SHARED_KINDS: [String] = ["conditions", "presets", "people", "owners", "places", "grab"]

/// The starter roster. In the CODE only — an account that has never edited its Packers
/// stores no rows at all, and both devices show these two straight from here.
/// (In JS these are `{ name, color }` with NO id; here the id is "" — give each one
/// `sharedRowId("people", name)` before showing it, as the web app's `loadPeople` does.)
public let DEFAULT_PEOPLE: [Person] = [
    Person(id: "", name: "Martin", color: PERSON_COLORS[0]),
    Person(id: "", name: "Anna", color: PERSON_COLORS[1]),
]

public func sharedRowId(_ kind: String, _ key: String?) -> String { "\(kind):\(normName(key))" }

// MARK: - SharedRow

public struct SharedRow: JSONModel, Hashable, Sendable {
    /// '' = not yet given one: `coerceSharedRow` builds it from the kind and the key.
    public var id: String
    public var kind: String
    public var key: String
    public var name: String
    /// A JS number that is never floored. Not finite = "none given": `coerceSharedRow`
    /// then uses the row's position.
    public var order: Double
    /// Everything else, nested. Always an object.
    public var data: JSONValue

    /// NOTE this does not coerce — `coerceSharedRow(…)` does.
    public init(id: String = "", kind: String = "", key: String = "", name: String = "",
                order: Double = 0, data: JSONValue = .object([:])) {
        self.id = id; self.kind = kind; self.key = key; self.name = name; self.order = order; self.data = data
    }
    /// `coerceSharedRow(json, 0)`. For a position other than 0 use `coerceSharedRow(json:_:)`.
    public init(json: JSONValue) { self = coerceSharedRow(json: json, 0) }

    /// Exactly these six keys — `coerceSharedRow` builds a NEW object and keeps nothing else.
    public var json: JSONValue {
        ["id": .string(id), "kind": .string(kind), "key": .string(key), "name": .string(name),
         "order": .number(order), "data": data]
    }
}

/// The value rules of `coerceSharedRow`, for a row built in memory.
public func coerceSharedRow(_ r: SharedRow, _ i: Int = 0) -> SharedRow {
    let kind = SHARED_KINDS.contains(r.kind) ? r.kind : ""
    let key = jsSlice(normName(r.key), 0, 60)
    return SharedRow(
        id: r.id.isEmpty ? sharedRowId(kind, key) : r.id,
        kind: kind,
        key: key,
        name: jsSlice(jsTrim(r.name), 0, 80),
        order: r.order.isFinite ? r.order : Double(i),
        data: r.data.objectValue != nil ? r.data : .object([:])
    )
}

/// `coerceSharedRow(r, i)` for raw JSON — anything that is not an object reads as `{}`.
public func coerceSharedRow(json r: JSONValue?, _ i: Int = 0) -> SharedRow {
    let o = r?.objectValue ?? [:]
    // `Number(o.order)`: undefined is NaN (→ the position), but null and '' are 0.
    let order = jsNumber(o["order"])
    return coerceSharedRow(SharedRow(
        id: jsStringOr(o["id"]),
        kind: jsStringOr(o["kind"]),
        key: jsStringNullish(o["key"]),        // normName does String(s ?? '')
        name: jsStringNullish(o["name"]),
        order: order.isFinite ? order : Double(i),
        data: o["data"] ?? .null
    ), i)
}

/// The rows of one list, in a settled order. The id tiebreak is load-bearing, not
/// tidiness: two devices both append, so two rows genuinely can share an `order`,
/// and without a deterministic second key each device would sort them differently
/// and then write that disagreement back at the other.
public func sharedRowsOfKind(_ rows: [SharedRow], _ kind: String) -> [SharedRow] {
    settleSharedRows(rows.enumerated().map { coerceSharedRow($0.element, $0.offset) }, kind)
}
/// `sharedRowsOfKind(rows, kind)` for raw JSON (rows as they come out of storage).
public func sharedRowsOfKind(json rows: JSONValue?, _ kind: String) -> [SharedRow] {
    settleSharedRows(asArray(rows).enumerated().map { coerceSharedRow(json: $0.element, $0.offset) }, kind)
}
private func settleSharedRows(_ coerced: [SharedRow], _ kind: String) -> [SharedRow] {
    coerced
        .filter { $0.kind == kind && !$0.key.isEmpty && !$0.name.isEmpty }
        .stableSorted(compare: { a, b in jsOr(jsSign(a.order - b.order), jsLocaleCompare(a.id, b.id)) })
}

// MARK: - conditions

// The key is the condition's slug id, but `data.cid` holds it VERBATIM as well:
// that id is stamped on every item, so it has to survive the round trip exactly,
// whatever normalising the key needed.
public func conditionsToRows(_ list: [ItemCondition]) -> [SharedRow] {
    conditionRows(list.map { coerceCondition($0) })
}
/// `conditionsToRows(list)` for raw JSON.
public func conditionsToRows(json list: JSONValue?) -> [SharedRow] {
    conditionRows(asArray(list).map { coerceCondition(json: $0) })
}
private func conditionRows(_ coerced: [ItemCondition]) -> [SharedRow] {
    var seen = Set<String>()
    var out: [SharedRow] = []
    for c in coerced {
        if c.id.isEmpty || c.label.isEmpty || seen.contains(normName(c.id)) { continue }
        seen.insert(normName(c.id))
        out.append(coerceSharedRow(SharedRow(
            kind: "conditions", key: c.id, name: c.label, order: Double(out.count),
            data: ["tone": .string(c.tone), "replace": .bool(c.replace), "cid": .string(c.id)]
        ), out.count))
    }
    return out
}
public func conditionsFromRows(_ rows: [SharedRow]) -> [ItemCondition] {
    sharedRowsOfKind(rows, "conditions").map(conditionFromRow)
}
public func conditionsFromRows(json rows: JSONValue?) -> [ItemCondition] {
    sharedRowsOfKind(json: rows, "conditions").map(conditionFromRow)
}
private func conditionFromRow(_ r: SharedRow) -> ItemCondition {
    // `{ id: r.data.cid || r.key, label: r.name, tone: r.data.tone, replace: r.data.replace }`
    var o: [String: JSONValue] = ["label": .string(r.name)]
    o["id"] = jsTruthy(r.data["cid"]) ? r.data["cid"] : .string(r.key)
    o["tone"] = r.data["tone"]
    o["replace"] = r.data["replace"]
    return coerceCondition(json: .object(o))
}

// MARK: - people

public func peopleToRows(_ list: [Person]) -> [SharedRow] {
    peopleRows(list.map { coercePerson($0) })
}
/// `peopleToRows(list)` for raw JSON — an entry that is not an object reads as `{}`.
public func peopleToRows(json list: JSONValue?) -> [SharedRow] {
    peopleRows(asArray(list).map { Person(json: $0) })
}
private func peopleRows(_ coerced: [Person]) -> [SharedRow] {
    var seen = Set<String>()
    var out: [SharedRow] = []
    for p in coerced {
        if p.name.isEmpty || seen.contains(normName(p.name)) { continue }
        seen.insert(normName(p.name))
        out.append(coerceSharedRow(SharedRow(
            kind: "people", key: p.name, name: p.name, order: Double(out.count), data: ["color": .string(p.color)]
        ), out.count))
    }
    return out
}
/// The person's `id` is the ROW's id, so it is the same on both devices — the
/// Settings list addresses its rows by it.
public func peopleFromRows(_ rows: [SharedRow]) -> [Person] {
    sharedRowsOfKind(rows, "people").map(personFromRow)
}
public func peopleFromRows(json rows: JSONValue?) -> [Person] {
    sharedRowsOfKind(json: rows, "people").map(personFromRow)
}
private func personFromRow(_ r: SharedRow) -> Person {
    var o: [String: JSONValue] = ["id": .string(r.id), "name": .string(r.name)]
    o["color"] = r.data["color"]
    return Person(json: .object(o))
}

// MARK: - owners & storage places (name-only lists)

public func namesToRows(_ kind: String, _ names: [String]) -> [SharedRow] {
    nameRows(kind, names)
}
/// `namesToRows(kind, names)` for raw JSON: an entry may be a string or `{ name }`;
/// anything else reads as ''.
public func namesToRows(_ kind: String, json names: JSONValue?) -> [SharedRow] {
    nameRows(kind, asArray(names).map { v in
        // `String(typeof v === 'string' ? v : (v && v.name) || '')`
        if let s = v.stringValue { return s }
        return jsStringOrEmpty(v["name"])
    })
}
private func nameRows(_ kind: String, _ names: [String]) -> [SharedRow] {
    var seen = Set<String>()
    var out: [SharedRow] = []
    for v in names {
        let name = jsTrim(v)
        let key = normName(name)
        if name.isEmpty || seen.contains(key) { continue }
        seen.insert(key)
        out.append(coerceSharedRow(SharedRow(kind: kind, key: key, name: name, order: Double(out.count)), out.count))
    }
    return out
}
/// A–Z. The order the Owners list has always been offered in, and the order every
/// Owner dropdown still uses.
public func namesFromRows(_ rows: [SharedRow], _ kind: String) -> [String] {
    sharedRowsOfKind(rows, kind).map { $0.name }.stableSorted(compare: { a, b in jsLocaleCompare(a, b) })
}
public func namesFromRows(json rows: JSONValue?, _ kind: String) -> [String] {
    sharedRowsOfKind(json: rows, kind).map { $0.name }.stableSorted(compare: { a, b in jsLocaleCompare(a, b) })
}
/// The stored order instead — for Storage places, where since v125 the order is
/// something you arrange yourself. `sharedRowsOfKind` has already sorted by `order`
/// with the id as a tiebreak, so this is simply "don't re-sort it".
public func orderedNamesFromRows(_ rows: [SharedRow], _ kind: String) -> [String] {
    sharedRowsOfKind(rows, kind).map { $0.name }
}
public func orderedNamesFromRows(json rows: JSONValue?, _ kind: String) -> [String] {
    sharedRowsOfKind(json: rows, kind).map { $0.name }
}
/// Owners, most-owned first — the Settings list answers "whose is most of this?"
/// before it answers "where is X in the alphabet". Ties settle A–Z so the order is
/// stable and both devices, counting the same items, agree on it.
/// `counts` is normalised name → number, as the app's `ownerUsage()` builds. (JS takes
/// a Map or a plain object; both are this dictionary.)
public func ownersByUsage(_ names: [String], _ counts: [String: Int] = [:]) -> [String] {
    func at(_ v: String) -> Int { counts[normName(v)] ?? 0 }
    return names.stableSorted(compare: { a, b in jsOr(at(b) - at(a), jsLocaleCompare(a, b)) })
}

// MARK: - trip presets

/// A saved trip recipe as the Settings list holds it: `{ id, name, createdAt, config }`.
/// `config` stays free-form JSON (what `presetConfigFromEvent` builds); `.null` = none.
public struct TripPreset: JSONModel, Hashable, Sendable {
    public var id: String
    public var name: String
    public var createdAt: String
    public var config: JSONValue

    public init(id: String = "", name: String = "", createdAt: String = "", config: JSONValue = .null) {
        self.id = id; self.name = name; self.createdAt = createdAt; self.config = config
    }
    /// Type rules only, as `presetsToRows` reads a preset: `String(p.name || '')`,
    /// `String(p.createdAt || '')`, the config as it stands.
    public init(json: JSONValue) {
        self.init(id: jsStringOr(json["id"]), name: jsStringOrEmpty(json["name"]),
                  createdAt: jsStringOrEmpty(json["createdAt"]), config: json["config"] ?? .null)
    }
    public var json: JSONValue {
        ["id": .string(id), "name": .string(name), "createdAt": .string(createdAt), "config": config]
    }
}

// Keyed by the normalised NAME, which quietly gives “Save as preset” the same
// replace-the-same-name behaviour it always had: the second save lands on the
// first one's key.
public func presetsToRows(_ list: [TripPreset]) -> [SharedRow] {
    var seen = Set<String>()
    var out: [SharedRow] = []
    for p in list {
        let name = jsTrim(p.name)
        // `!p.config`: a preset with no config is not a preset. (`{}` IS one — truthy.)
        if name.isEmpty || !p.config.truthy || seen.contains(normName(name)) { continue }
        seen.insert(normName(name))
        out.append(coerceSharedRow(SharedRow(
            kind: "presets", key: name, name: name, order: Double(out.count),
            data: ["config": p.config, "createdAt": .string(p.createdAt)]
        ), out.count))
    }
    return out
}
/// `presetsToRows(list)` for raw JSON.
public func presetsToRows(json list: JSONValue?) -> [SharedRow] {
    presetsToRows(asArray(list).map { TripPreset(json: $0) })
}
public func presetsFromRows(_ rows: [SharedRow]) -> [TripPreset] {
    sharedRowsOfKind(rows, "presets").compactMap(presetFromRow)
}
public func presetsFromRows(json rows: JSONValue?) -> [TripPreset] {
    sharedRowsOfKind(json: rows, "presets").compactMap(presetFromRow)
}
private func presetFromRow(_ r: SharedRow) -> TripPreset? {
    guard let config = r.data["config"], config.truthy else { return nil }
    // `r.data.createdAt || ''` — JS would hand a non-string through as it is; here it
    // reads as its text. (`presetsToRows` only ever writes a string.)
    return TripPreset(id: r.id, name: r.name, createdAt: jsStringOrEmpty(r.data["createdAt"]), config: config)
}

// MARK: - workout grab lists (v163)

/// One Home grab button as the Settings list holds it: `{ id, items, label, icon, tone }`.
public struct GrabList: JSONModel, Hashable, Sendable {
    /// The button's code id ('bike', 'run-out').
    public var id: String
    public var items: [String]
    public var label: String
    public var icon: String
    public var tone: String

    public init(id: String = "", items: [String] = [], label: String = "", icon: String = "", tone: String = "") {
        self.id = id; self.items = items; self.label = label; self.icon = icon; self.tone = tone
    }
    /// Type rules only, as `grabToRows` reads one: `String(g.id || '')`, only the
    /// strings among `items`, and '' for a label / icon / tone that is not a string.
    public init(json: JSONValue) {
        self.init(id: jsStringOrEmpty(json["id"]),
                  items: asArray(json["items"]).compactMap { $0.stringValue },
                  label: jsStringOr(json["label"]), icon: jsStringOr(json["icon"]), tone: jsStringOr(json["tone"]))
    }
    public var json: JSONValue {
        ["id": .string(id), "items": JSONValue(items), "label": .string(label),
         "icon": .string(icon), "tone": .string(tone)]
    }
}

// One row per Home button. The key is the button's code id ('bike', 'run-out'),
// which is stable and shipped, so two devices editing the same button land on the
// same row and merge instead of doubling — and `data.gid` carries it VERBATIM,
// exactly as a condition carries its `cid`, because `sharedRowId` normalises the
// key and 'run-out' must survive the round trip character for character.
//
// A button you have never edited has NO ROW. That is deliberate and it is the
// v118 rule: the factory six live in the code, and an account with no grab rows
// means "use the defaults" rather than "the lists are empty".
public func grabToRows(_ list: [GrabList]) -> [SharedRow] {
    var seen = Set<String>()
    var out: [SharedRow] = []
    for g in list {
        let gid = jsTrim(g.id)
        // 🪤 `seen` holds the id AS WRITTEN while the row id is normalised, so 'Bike'
        // and 'bike' build two rows with one id. Kept as the JS has it.
        if gid.isEmpty || seen.contains(gid) { continue }
        seen.insert(gid)
        let items = g.items.filter { !jsTrim($0).isEmpty }.map { jsSlice(jsTrim($0), 0, 80) }
        let label = jsSlice(jsTrim(g.label), 0, 24)
        out.append(coerceSharedRow(SharedRow(
            kind: "grab", key: gid, name: label.isEmpty ? gid : label, order: Double(out.count),
            data: ["gid": .string(gid), "items": JSONValue(items), "label": .string(label),
                   "icon": .string(g.icon), "tone": .string(g.tone)]
        ), out.count))
    }
    return out
}
/// `grabToRows(list)` for raw JSON — a bare string is not a grab list.
public func grabToRows(json list: JSONValue?) -> [SharedRow] {
    grabToRows(asArray(list).map { GrabList(json: $0) })
}
public func grabFromRows(_ rows: [SharedRow]) -> [GrabList] {
    sharedRowsOfKind(rows, "grab").compactMap(grabFromRow)
}
public func grabFromRows(json rows: JSONValue?) -> [GrabList] {
    sharedRowsOfKind(json: rows, "grab").compactMap(grabFromRow)
}
private func grabFromRow(_ r: SharedRow) -> GrabList? {
    guard let gid = r.data["gid"], gid.truthy else { return nil }
    return GrabList(
        id: gid.jsString,   // `r.data.gid` as it stands; `grabToRows` only ever writes a string
        items: asArray(r.data["items"]).compactMap { $0.stringValue }.filter { !jsTrim($0).isEmpty },
        label: jsStringOr(r.data["label"]),
        icon: jsStringOr(r.data["icon"]),
        tone: jsStringOr(r.data["tone"])
    )
}

// MARK: - whichever of the six it is

/// One list → its rows, whichever of the six it is. The list is a different shape
/// for each kind, so it arrives as JSON (a typed list: `.array(list.map { $0.json })`,
/// or call the kind's own `…ToRows`).
public func sharedRowsFrom(_ kind: String, json list: JSONValue?) -> [SharedRow] {
    if kind == "conditions" { return conditionsToRows(json: list) }
    if kind == "people" { return peopleToRows(json: list) }
    if kind == "presets" { return presetsToRows(json: list) }
    if kind == "grab" { return grabToRows(json: list) }
    if kind == "owners" || kind == "places" { return namesToRows(kind, json: list) }
    return []
}
/// The factory list for a kind, or [] where there isn't one (nobody ships you a
/// trip preset, and the owners list is derived from your own data).
/// conditions → `{ id, label, tone, replace }` · people → `{ name, color }` · places → strings.
public func defaultListFor(_ kind: String) -> [JSONValue] {
    if kind == "conditions" { return DEFAULT_ITEM_CONDITIONS.map { $0.json } }
    if kind == "people" { return DEFAULT_PEOPLE.map { ["name": .string($0.name), "color": .string($0.color)] } }
    if kind == "places" { return DEFAULT_STORAGE_LOCATIONS.map { .string($0) } }
    return []
}
/// Is this list still exactly what the app ships? The one question that decides
/// whether a list is worth writing into shared data at all — see the seeding note
/// at the top of this file.
public func isFactoryList(_ kind: String, json list: JSONValue?) -> Bool {
    let def = defaultListFor(kind)
    if def.isEmpty { return false }
    let a = sharedRowsFrom(kind, json: list)
    let b = sharedRowsFrom(kind, json: .array(def))
    if a.count != b.count { return false }
    // JS compares `JSON.stringify(r.data)`, where key ORDER counts — but both sides
    // are built by the same `…ToRows` code, so their keys are always in the same
    // order and hold only strings and booleans: comparing the values is the same answer.
    return zip(a, b).allSatisfy { r, d in r.id == d.id && r.name == d.name && r.data == d.data }
}
/// `isFactoryList(kind, list)` for a list already held as JSON values.
public func isFactoryList(_ kind: String, _ list: [JSONValue]) -> Bool { isFactoryList(kind, json: .array(list)) }
