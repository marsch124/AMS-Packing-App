// DeviceAudit — is this device holding the account's WHOLE copy?
// Ported from js/model.js ("Is this device holding the account's WHOLE copy?").
//
// 🚨 THE FAULT THIS EXISTS TO CATCH, AND WHY IT HAS TO BE FOUND LOCALLY.
//
// When a release adds a synced table, the sync addon gives it one first, full
// download and then records it as done. A device that reaches the new table
// BEFORE the other device has written anything into it downloads nothing,
// records the table as done anyway, and from then on receives only rows that are
// newly CREATED — never an update to a row it has no copy of. So it sits on a
// fraction of the list for ever, and nothing about it looks broken: no error, no
// warning, and the app carries on because it deliberately tolerates a value it
// doesn't recognise. That is how an iPhone held two storage places out of
// seventeen for a fortnight without saying a word.
//
// Two pushes from the healthy device were shipped to cure it (v121, v124). Both
// failed, and the second was PROVEN to reach the server — the rows arrived and
// were ignored, because they were updates to rows that device never had. The only
// thing that worked was pulling: Replace this device with the account copy.
//
// So this does not try to fix it. It tries to NOTICE it, which is the part that
// was missing. No server call is needed, because the evidence is already on the
// device: your items travel with the catalogue and they carry the answers — this
// rucksack is kept in the "Loft", that jacket is "Anna's", this one is "Worn out".
// Those arrived. If your gear points at fifteen storage places and the storage-place
// list has heard of two, the list did not arrive, and the device can work that out
// entirely on its own.
//
// Everything below is pure: no database, no network, no addon internals.

import Foundation

/// The lists whose entries the rest of your data points at. `presets` is
/// deliberately absent: nothing refers to a trip preset, so one going missing
/// leaves no trace to find, and claiming otherwise would be a guess.
public let AUDITABLE_KINDS: [String] = ["places", "owners", "conditions", "people", "phases"]

public let AUDIT_LABELS: [String: String] = [
    "places": "Storage places",
    "owners": "Owners",
    "conditions": "Item conditions",
    "people": "Packers",
    "phases": "When",
]

// How an entry of each list is addressed by the data that points at it. Items
// store a condition's and a phase's ID, not its label — which is exactly why a
// missing one shows up as a slug rather than a name.
// nil = a kind nothing audits. (Not exported by the JS module, so not public here.)
func AUDIT_KEY_OF(_ kind: String) -> ((JSONValue) -> String)? {
    switch kind {
    case "places", "owners":
        // `typeof v === 'string' ? v : (v && v.name) || ''`
        return { v in v.stringValue ?? jsStringOrEmpty(v["name"]) }
    case "people":
        // `(v && typeof v === 'object' ? v.name : v) || ''`
        return { v in auditField(v, "name") }
    case "conditions", "phases":
        return { v in auditField(v, "id") }
    default:
        return nil
    }
}
private func auditField(_ v: JSONValue, _ field: String) -> String {
    switch v {
    case .object(let o): return jsStringOrEmpty(o[field])
    case .array: return ""                       // an array is an object with no such field
    default: return jsStringOrEmpty(v)           // a bare string (or number) stands for itself
    }
}

// MARK: - What the device's own data refers to

/// One remembered spelling: the normalised key and how it was first written.
public struct ReferencedSpelling: Equatable, Hashable, Sendable {
    public var key: String
    public var shown: String
    public init(key: String, shown: String) { self.key = key; self.shown = shown }
}

/// What `referencedListValues` returns. In JS: `{ places: Set, owners: Set, …, display:
/// { places: Map, … } }`, read by kind NAME (`referenced[kind]`) — so it is held by
/// kind here too. A JS Set / Map keeps insertion order; each array below is in that
/// first-seen order, without duplicates.
public struct ReferencedListValues: Equatable, Sendable {
    /// kind → the normalised values referred to (JS: one Set per kind).
    public var values: [String: [String]]
    /// kind → normalised value → the spelling it was first written in (JS: one Map per kind).
    public var display: [String: [ReferencedSpelling]]

    public init(_ values: [String: [String]] = [:], display: [String: [ReferencedSpelling]] = [:]) {
        self.values = values; self.display = display
    }

    /// `referenced[kind]` — [] for a kind it does not hold.
    public subscript(kind: String) -> [String] { values[kind] ?? [] }
    public var places: [String] { self["places"] }
    public var owners: [String] { self["owners"] }
    public var conditions: [String] { self["conditions"] }
    public var people: [String] { self["people"] }
    public var phases: [String] { self["phases"] }

    /// `referenced[kind].has(value)`
    public func has(_ kind: String, _ value: String) -> Bool { self[kind].contains(value) }
    /// `referenced.display[kind].get(key)` — nil when there is none.
    public func shown(_ kind: String, _ key: String) -> String? {
        display[kind]?.first { $0.key == key }?.shown
    }

    fileprivate mutating func add(_ kind: String, _ v: String?) {
        // `typeof v === 'string' ? v.trim() : ''`
        let raw = jsTrim(v ?? "")
        let t = normName(raw)
        if t.isEmpty { return }
        if !(values[kind] ?? []).contains(t) { values[kind, default: []].append(t) }
        if shown(kind, t) == nil { display[kind, default: []].append(ReferencedSpelling(key: t, shown: raw)) }
    }
    fileprivate static func empty() -> ReferencedListValues {
        var out = ReferencedListValues()
        for k in AUDITABLE_KINDS { out.values[k] = []; out.display[k] = [] }
        return out
    }

    public var json: JSONValue {
        var o: [String: JSONValue] = [:]
        for (k, v) in values { o[k] = JSONValue(v) }
        var d: [String: JSONValue] = [:]
        for (k, pairs) in display { d[k] = .array(pairs.map { [.string($0.key), .string($0.shown)] }) }
        o["display"] = .object(d)
        return .object(o)
    }
}

/// Every value this device's own data refers to, per list, normalised — plus, in
/// `display`, the spelling it was actually written in. Comparing has to normalise
/// ("Loft" and "loft" are one place), but SHOWING him a normalised key would put
/// "basement / cellar" on screen where his items say "Basement / cellar". A list of
/// what is missing is only useful if he recognises the entries in it.
public func referencedListValues(lists: [PackList] = [], events: [TripEvent] = [],
                                 actions: [ActionItem] = []) -> ReferencedListValues {
    var out = ReferencedListValues.empty()
    for l in lists {
        for it in l.items {
            out.add("places", it.storage)
            out.add("owners", it.ownedBy)
            out.add("people", it.packer)   // since v133 an item carries a standing packer of its own
            out.add("conditions", it.condition)
            out.add("phases", it.phase)
        }
    }
    // Trip entries are self-contained copies, so they carry the same answers even
    // for gear that has since left the catalogue.
    for ev in events {
        for e in ev.entries {
            out.add("places", e.storage)
            out.add("people", e.packer)
            out.add("phases", e.phase)
        }
    }
    // 🪤 `a.phase`, NOT `a.whenPhase` — the key the JS reads, which no real action
    // carries. Kept for parity; see the note on `ActionItem.phase`.
    for a in actions { out.add("phases", a.phase) }
    return out
}

/// `referencedListValues({ lists, events, actions })` for raw JSON — reads the fields
/// AS THEY STAND (no `coerceItem`: a blank phase stays blank rather than becoming the
/// default), and steps over junk exactly as the JS does.
public func referencedListValues(json arg: JSONValue?) -> ReferencedListValues {
    var out = ReferencedListValues.empty()
    for l in asArray(arg?["lists"]) {
        for it in asArray(l["items"]) where it.truthy {
            out.add("places", it["storage"]?.stringValue)
            out.add("owners", it["ownedBy"]?.stringValue)
            out.add("people", it["packer"]?.stringValue)
            out.add("conditions", it["condition"]?.stringValue)
            out.add("phases", it["phase"]?.stringValue)
        }
    }
    for ev in asArray(arg?["events"]) {
        for e in asArray(ev["entries"]) where e.truthy {
            out.add("places", e["storage"]?.stringValue)
            out.add("people", e["packer"]?.stringValue)
            out.add("phases", e["phase"]?.stringValue)
        }
    }
    for a in asArray(arg?["actions"]) where a.truthy { out.add("phases", a["phase"]?.stringValue) }
    return out
}

// MARK: - One list against what points at it

/// What `auditList` returns: `{ kind, used, listed, missing, missingLabels }`.
public struct ListAudit: Equatable, Sendable {
    public var kind: String
    /// How many distinct values the device's data refers to.
    public var used: Int
    /// How many distinct entries the list in force holds.
    public var listed: Int
    /// Referred to but not listed — normalised keys, sorted.
    public var missing: [String]
    /// The same, in the spelling his own data uses (the key itself where none is known).
    public var missingLabels: [String]
    public init(kind: String, used: Int = 0, listed: Int = 0, missing: [String] = [], missingLabels: [String] = []) {
        self.kind = kind; self.used = used; self.listed = listed
        self.missing = missing; self.missingLabels = missingLabels
    }
    public var json: JSONValue {
        ["kind": .string(kind), "used": .number(Double(used)), "listed": .number(Double(listed)),
         "missing": JSONValue(missing), "missingLabels": JSONValue(missingLabels)]
    }
}

/// One list, compared against what points at it. `inForce` is the list the app is
/// actually showing — stored rows, or the code's defaults where there are none —
/// because an entry supplied by the defaults is not missing, it is just not stored.
/// Its entries are strings or objects depending on the kind, so it arrives as JSON.
public func auditList(_ kind: String, _ referenced: ReferencedListValues?, json inForce: JSONValue?) -> ListAudit {
    let used = referenced?[kind] ?? []
    guard let keyOf = AUDIT_KEY_OF(kind) else { return ListAudit(kind: kind, used: used.count) }
    var have = Set<String>()
    for v in asArray(inForce) {
        let k = normName(keyOf(v))
        if !k.isEmpty { have.insert(k) }
    }
    // `.sort()` with no comparator: by UTF-16 unit, NOT localeCompare.
    let missing = used.filter { !have.contains($0) }.stableSorted(by: { a, b in jsStringLess(a, b) })
    // A condition and a phase are referred to by their id, so what shows here is a
    // slug — which is the honest answer: that IS what the item is pointing at.
    let labels = missing.map { k -> String in
        if let s = referenced?.shown(kind, k), !s.isEmpty { return s }
        return k
    }
    return ListAudit(kind: kind, used: used.count, listed: have.count, missing: missing, missingLabels: labels)
}

// MARK: - The verdict

/// A stray or two is ORDINARY and must never raise an alarm: remove a storage
/// place you have stopped using and the items still standing in it keep the old
/// name on purpose, so the place goes on being offered. What is not ordinary is a
/// list that has heard of less than it has forgotten.
public let AUDIT_STRAY_TOLERANCE = 2

/// The lists the app is actually showing, one per audited kind — the typed form of
/// the JS `inForce` object.
public struct ListsInForce: Equatable, Sendable {
    public var places: [String]
    public var owners: [String]
    public var conditions: [ItemCondition]
    public var people: [Person]
    public var phases: [Phase]
    public init(places: [String] = [], owners: [String] = [], conditions: [ItemCondition] = [],
                people: [Person] = [], phases: [Phase] = []) {
        self.places = places; self.owners = owners; self.conditions = conditions
        self.people = people; self.phases = phases
    }
    public var json: JSONValue {
        ["places": JSONValue(places), "owners": JSONValue(owners),
         "conditions": .array(conditions.map { $0.json }), "people": .array(people.map { $0.json }),
         "phases": .array(phases.map { $0.json })]
    }
}

/// What `auditDeviceLists` returns: `{ level, lists, gappy, broken, missingTotal }`.
public struct DeviceListAudit: Equatable, Sendable {
    /// 'off' | 'ok' | 'suspect' | 'broken'
    public var level: String
    /// Every audited list, always — so Settings can show the detail even when 'off'.
    public var lists: [ListAudit]
    public var gappy: [ListAudit]
    public var broken: [ListAudit]
    public var missingTotal: Int
    public init(level: String, lists: [ListAudit], gappy: [ListAudit], broken: [ListAudit], missingTotal: Int) {
        self.level = level; self.lists = lists; self.gappy = gappy; self.broken = broken
        self.missingTotal = missingTotal
    }
    public var json: JSONValue {
        ["level": .string(level), "lists": .array(lists.map { $0.json }), "gappy": .array(gappy.map { $0.json }),
         "broken": .array(broken.map { $0.json }), "missingTotal": .number(Double(missingTotal))]
    }
}

/// The verdict.
///
///  off     — nothing to compare against (not syncing, or nothing on the device).
///  ok      — every list accounts for what your gear points at, give or take strays.
///  suspect — one list has more gaps than strays explain. Worth a look.
///  broken  — a list has forgotten at least as much as it remembers. This is the
///            shape of a list that never downloaded, and the shape his iPhone had:
///            2 places listed, 15 unaccounted for.
public func auditDeviceLists(referenced: ReferencedListValues? = nil, inForce: ListsInForce? = nil,
                             signedIn: Bool = false, hasCatalogue: Bool = false) -> DeviceListAudit {
    auditDeviceLists(referenced: referenced, json: inForce?.json, signedIn: signedIn, hasCatalogue: hasCatalogue)
}
/// `auditDeviceLists({ … })` with `inForce` as raw JSON: `{ places: […], owners: […], … }`.
public func auditDeviceLists(referenced: ReferencedListValues?, json inForce: JSONValue?,
                             signedIn: Bool = false, hasCatalogue: Bool = false) -> DeviceListAudit {
    let lists = AUDITABLE_KINDS.map { auditList($0, referenced, json: inForce?[$0]) }
    let gappy = lists.filter { $0.missing.count > AUDIT_STRAY_TOLERANCE }
    let broken = gappy.filter { $0.missing.count >= $0.listed }
    var level = "ok"
    if !signedIn || !hasCatalogue { level = "off" }
    else if !broken.isEmpty { level = "broken" }
    else if !gappy.isEmpty { level = "suspect" }
    return DeviceListAudit(
        level: level,
        lists: lists,
        gappy: level == "off" ? [] : gappy,
        broken: level == "off" ? [] : broken,
        missingTotal: level == "off" ? 0 : gappy.reduce(0) { $0 + $1.missing.count }
    )
}
