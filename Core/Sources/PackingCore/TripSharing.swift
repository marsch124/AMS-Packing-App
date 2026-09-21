// TripSharing — a trip as a file or a link (manual, backend-free).
// Ported from js/model.js ("Trip sharing": `buildTripBundle`, `parseTripBundle`,
// `encodeTripLink`, `decodeTripLink`).
//
// A trip bundle is a single, self-contained event. Its entries are already
// materialised, so nothing external (no building-block lists) is needed to
// rebuild the Total List on the receiving device.

import Foundation

public let TRIP_KIND = "trip"

// Entry fields the receiver never needs: sender-only bookkeeping (ids, source
// links, usage stats, packed/used state). coerceItem restores every other
// default on import, so dropping defaulted fields is lossless.
//
// 🚨 v186: and the two properties the sync addon keeps for itself. A synced trip is
// a synced ROW, and the addon writes the signed-in account's e-mail address into
// `owner` and `realmId` on it — so until v186 every shared trip (link, QR or file)
// carried the sender's address, twice. (A decoded `Item` / `TripEvent` never holds
// them here, but one built in memory can, in `extra`.)
let TRIP_DROP_KEYS: Set<String> = Set(["id", "sourceListId", "sourceItemId", "stats", "checked", "used", "custom"] + SYNC_RESERVED_KEYS)

/// `v === '' || v === false || v === 0 || v == null || (Array.isArray(v) && v.length === 0)`
func isDefaulty(_ v: JSONValue?) -> Bool {
    switch v {
    case nil, .null?: return true
    case .string(let s)?: return s.isEmpty
    case .bool(let b)?: return !b
    case .number(let n)?: return n == 0
    case .array(let a)?: return a.isEmpty
    case .object?: return false
    }
}

// KEY ORDER. `JSON.stringify` writes an object's keys in the order they were first
// set. For an event that is `newEvent`'s literal, then what `coerceEvent` adds; for
// an entry it is `newItem`'s literal, then the trip-only keys. (The web app's own
// trips carry whatever order their history gave them — so the parity contract does
// NOT compare the raw link, only that each side reads the other's. See N1 there.)
private let TRIP_ENTRY_ORDER = ShareKeyOrder(
    keys: [
        "id", "name", "swedish", "qty", "category", "container", "phase", "itemType", "charging", "chargeType",
        "shortList", "seasons", "contexts", "transports", "catering", "weather", "sub", "note", "weight",
        "liquid", "restricted", "perNight", "consumable", "section", "kit", "packer", "storage", "photos",
        "thumb", "maintenance", "color", "size", "manufacturer", "model", "ownedBy", "acquired", "price",
        "currency", "purchaseLink", "expiry", "condition", "retired", "retiredReason", "serial", "qtyOwned",
        "warranty", "capacityL", "maxKg",
        "custom", "checked", "sourceListId", "sourceItemId", "stats", "_edited", "skipped", "keep", "used",
        "_itemId", "_memId", "_link", "_ovContainer", "_tplContainer", "_defContainer", "_ovPhase", "_defPhase",
    ],
    children: [
        "maintenance": ShareKeyOrder(keys: ["notes", "link", "intervalDays", "lastDone", "log"],
                                     children: ["log": ShareKeyOrder(keys: ["date", "note"])]),
        "stats": ShareKeyOrder(keys: ["packed", "used", "unused", "skipped", "lastReviewed"]),
    ]
)
private let TRIP_EVENT_ORDER = ShareKeyOrder(
    keys: [
        "id", "name", "mode", "activities", "transport", "season", "contexts", "weatherOn", "catering",
        "startDate", "endDate", "nights", "laundry", "destination", "weather", "entries", "generatedAt",
        "createdAt", "updatedAt", "status", "reviewedAt", "geo",
    ],
    children: [
        "weather": ShareKeyOrder(keys: ["place", "lat", "lon", "fetchedAt", "daily"],
                                 children: ["daily": ShareKeyOrder(keys: ["date", "code", "tmax", "tmin", "precipProb", "wind"])]),
        "geo": ShareKeyOrder(keys: ["lat", "lon", "place"]),
    ]
)

// A sub-item is a NAME — a string. Until v186 slimEntry ran each one through
// itself, and a string taken apart key by key is {"0":"a","1":"b"}, which the
// receiving trip then showed as "[object Object]". This reads both shapes: a
// string as it stands, and one of those objects put back together, so a link
// sent before the fix still opens properly.
// (An old bundle spells an emoji as two lone halves; they arrive parked — see
// `shareParkLoneSurrogates` — and are joined back into the emoji here.)
func subName(_ s: JSONValue?) -> String {
    func joined(_ part: (Int) -> JSONValue?) -> String {
        var units: [UInt16] = []
        var i = 0
        while let piece = part(i)?.stringValue { units.append(contentsOf: shareUnparkedUnits(piece)); i += 1 }
        return shareStringDroppingLoneSurrogates(units)
    }
    switch s {
    case .string(let str)?: return shareStringDroppingLoneSurrogates(shareUnparkedUnits(str))
    case .object(let o)?:
        if let name = o["name"]?.stringValue { return shareStringDroppingLoneSurrogates(shareUnparkedUnits(name)) }
        return joined { o[String($0)] }
    case .array(let a)?: return joined { a.indices.contains($0) ? a[$0] : nil }
    default: return ""
    }
}

/// Shrink an entry to just its non-default, receiver-relevant fields. This keeps
/// shared links small enough to travel as a URL (a full entry is ~4x larger).
func slimEntry(_ e: Item) -> OrderedJSON {
    let o = e.json.objectValue ?? [:]
    var out: [OrderedJSON.Member] = []
    for k in shareOrderedKeys(o, order: TRIP_ENTRY_ORDER) {
        let v = o[k]
        if TRIP_DROP_KEYS.contains(k) { continue }
        if k == "sub" {
            let names = asArray(v).map { subName($0) }.filter { !$0.isEmpty }
            if !names.isEmpty { out.append(.init("sub", .array(names.map { .string($0) }))) }
            continue
        }
        if k == "ownedBy" {   // a name, never an address
            let who = shareSafeOwnerUnits(v?.stringValue)
            if !who.isEmpty { out.append(.init("ownedBy", .js(who))) }
            continue
        }
        if k == "itemType" && v == .string("item") { continue }   // restored by coerceItem
        if isDefaulty(v) { continue }                               // restored by coerceItem
        out.append(.init(k, OrderedJSON(v ?? .null, order: TRIP_ENTRY_ORDER.children[k])))
    }
    return .object(out)
}

private func slimEvent(_ event: TripEvent) -> OrderedJSON {
    var o = event.json.objectValue ?? [:]
    for k in SYNC_RESERVED_KEYS { o[k] = nil }   // the account's address — see TRIP_DROP_KEYS
    return .object(shareOrderedKeys(o, order: TRIP_EVENT_ORDER).map { k in
        if k == "entries" { return .init(k, .array(event.entries.map { slimEntry($0) })) }
        return .init(k, OrderedJSON(o[k] ?? .null, order: TRIP_EVENT_ORDER.children[k]))
    })
}

/// `{ app, kind, version, exportedAt, event }` — what `buildTripBundle` returns.
public struct TripBundle: Equatable, Sendable {
    public let app: String
    public let kind: String
    public let version: Int
    public let exportedAt: String
    /// The event with slimmed entries, its keys in JS order.
    public let event: OrderedJSON

    init(event: TripEvent, exportedAt: String) {
        self.app = "ams-packing-list"
        self.kind = TRIP_KIND
        self.version = 1
        self.exportedAt = exportedAt
        self.event = slimEvent(event)
    }

    /// The whole bundle as plain JSON (no key order) — what the parity checker compares.
    public var json: JSONValue { ordered.value }

    /// The bundle with its keys in order, as it travels.
    public var ordered: OrderedJSON {
        .object([
            .init("app", .string(app)), .init("kind", .string(kind)), .init("version", .number(Double(version))),
            .init("exportedAt", .string(exportedAt)), .init("event", event),
        ])
    }
    /// `JSON.stringify(bundle)` — or `JSON.stringify(bundle, null, 2)`, which is what
    /// the app saves as a file.
    public func text(pretty: Bool = false) -> String { ordered.text(pretty: pretty) }
}

public func buildTripBundle(_ event: TripEvent, whenISO: String = nowISO()) -> TripBundle {
    TripBundle(event: event, exportedAt: whenISO)
}
/// The JS form, for a trip that may not be there: `if (!event) throw …`.
public func buildTripBundle(_ event: TripEvent?, whenISO: String = nowISO()) throws -> TripBundle {
    guard let event = event else { throw ShareError("No trip to share.") }
    return TripBundle(event: event, exportedAt: whenISO)
}

private let notATrip = ShareError("This does not look like a shared AMS trip.")

// An entry as it may come IN. The bundle is somebody else's text — possibly made
// by an app from before v186 — so the door is guarded on this side as well: the
// sync addon's two properties are dropped (they hold the SENDER's address, and a
// row claiming to be theirs is one the receiver's own sync would never carry
// across), "whose it is" is kept only when it is a name, and sub-items that an
// old app took apart are put back together.
func incomingEntry(_ e: JSONValue) -> JSONValue {
    var o: [String: JSONValue]
    switch e {
    case .object(let x): o = x
    case .array(let a):              // `{ ...array }` — its elements under their indexes
        o = [:]
        for (i, v) in a.enumerated() { o[String(i)] = v }
    default: return e
    }
    let who = o["ownedBy"]?.stringValue != nil ? o["ownedBy"] : o["owner"]   // `owner` was the app's own field before v117
    for k in SYNC_RESERVED_KEYS { o[k] = nil }
    o["ownedBy"] = .string(shareSafeOwner(jsStringNullish(who)))
    if let sub = o["sub"] { o["sub"] = JSONValue(asArray(sub).map { subName($0) }.filter { !$0.isEmpty }) }
    return .object(o)
}

/// Parse a trip bundle (from a file or a link) and return a fresh, importable
/// event: new id + timestamps, review state reset, so importing never clobbers
/// an existing event and the receiver starts from a clean, unpacked list.
///
/// Text that is not JSON throws the same "does not look like…" error (JS throws the
/// engine's own SyntaxError there, with the engine's own words).
public func parseTripBundle(_ data: String) throws -> TripEvent {
    let obj: JSONValue
    do { obj = try shareParseJSON(data, keepParked: true) } catch { throw notATrip }
    return try parseTripBundle(json: obj)
}

/// `parseTripBundle(obj)` for a bundle that is already parsed.
public func parseTripBundle(json obj: JSONValue?) throws -> TripEvent {
    guard let obj = obj, obj["kind"]?.stringValue == TRIP_KIND, let raw = obj["event"], raw.truthy else { throw notATrip }
    // `{ ...obj.event, entries: … }` — whatever `event` is, what comes out is an object.
    var o = raw.objectValue ?? [:]
    let entries = asArray(o["entries"]).map { incomingEntry($0) }
    // JS: `reidEntries` sets `.id` on every entry, which THROWS (a TypeError) on one
    // that is a string, a number or null. Refused here with the model's own words.
    guard entries.allSatisfy({ $0.objectValue != nil }) else { throw notATrip }
    o["entries"] = .array(entries)
    for k in SYNC_RESERVED_KEYS { o[k] = nil }
    var ev = TripEvent(json: shareDropParked(.object(o)))
    ev.id = id()
    ev.status = "active"
    ev.reviewedAt = ""
    ev.createdAt = nowISO()
    ev.updatedAt = ev.createdAt
    // Give every entry a fresh unique id — slimmed bundles carry none, and the UI
    // keys expand/remove/review on entry.id. (Sub-items are plain names; they have
    // no id to give.)
    ev.entries = ev.entries.map { e in
        var e = e
        e.id = id()
        e.checked = false
        e.used = nil
        return e
    }
    return ev
}

/// `parseTripBundle(buildTripBundle(ev))` — a bundle that never left this device.
public func parseTripBundle(_ bundle: TripBundle) throws -> TripEvent {
    try parseTripBundle(json: bundle.json)
}

// Encode a trip as a self-contained deep link fragment: #/t/<code>, the code
// squeezed by `packShare`. Returns nil when even the squeezed payload is too
// large to travel reliably as a link — callers fall back to a file share.
//
// The ceiling is generous because the limit that bites is the messaging app in
// the middle, not the browser: Safari swallows some 80 000 characters, and the
// apps people actually paste links into carry tens of thousands. Compressed, a
// week away with three activities lands around 12 000.
public let TRIP_LINK_MAX = 30000

public func encodeTripLink(_ event: TripEvent, whenISO: String = nowISO()) -> String? {
    let frag = "#/t/" + packShare(buildTripBundle(event, whenISO: whenISO).text())
    return frag.utf16.count > TRIP_LINK_MAX ? nil : frag
}
/// The JS form, for a trip that may not be there (throws "No trip to share.").
public func encodeTripLink(_ event: TripEvent?, whenISO: String = nowISO()) throws -> String? {
    guard let event = event else { throw ShareError("No trip to share.") }
    return encodeTripLink(event, whenISO: whenISO)
}

public func decodeTripLink(_ data: String?) throws -> TripEvent {
    try parseTripBundle(try unpackShare(data))
}
