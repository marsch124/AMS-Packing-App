// Memberships — the TYPE that links one catalogue item to one template, and the three
// field lists that say which half of an item belongs where.
// Ported from js/model.js ("RELATIONAL CORE"). Only the shape and its constructor
// live here; resolving, the catalogue and the migration engine are a later section.
//
// Three layers, each owning its own properties:
//   1. ITEM        — the thing itself: name, swedish, category, flags, weight,
//                    photos, home storage, care, default container, default phase.
//   2. MEMBERSHIP  — item ↔ template: the relation. Holds the CONDITIONS that decide
//                    when the item is included (seasons / contexts / transports /
//                    catering / weather), plus OPTIONAL overrides of container / phase /
//                    itemType / qty / note (blank = use the item's default).
//   3. TRIP LINE   — item ↔ event: the frozen packing-list snapshot (an `Item` in
//                    `TripEvent.entries`).

import Foundation

/// A Membership links one catalog item to one template. Conditions describe WHEN
/// the item applies on a trip; overrides are '' / [] when the item's own default
/// should be used (so a membership stays tiny unless it genuinely differs).
public struct Membership: JSONModel, Hashable, Sendable {
    public var id: String
    public var itemId: String
    public var templateId: String
    public var seasons: [String]
    public var contexts: [String]
    public var transports: [String]
    public var catering: [String]
    /// Conditional-gear tags (contextual, per template).
    public var weather: [String]
    /// '' = use the template default, then the item's own.
    public var container: String
    /// Section id within THIS template ('' = none).
    public var section: String
    /// Kit NAME this item is packed as part of ('' = none); contextual per template.
    public var kit: String
    /// '' = use item default; unknown ids kept (see `coerceItem`).
    public var phase: String
    /// 'item' | 'reminder' | '' (= use item default)
    public var itemType: String
    public var qty: String
    public var note: String
    /// Item position within its template. A JS number that is never floored.
    public var order: Double
    /// Any key this package does not know — kept so nothing is lost on a round trip.
    public var extra: [String: JSONValue]

    /// The defaults are `newMembership`'s. NOTE this does not coerce — `newMembership(…)` does.
    public init(
        id: String = PackingEnv.makeId(),
        itemId: String = "",
        templateId: String = "",
        seasons: [String] = [],
        contexts: [String] = [],
        transports: [String] = [],
        catering: [String] = [],
        weather: [String] = [],
        container: String = "",
        section: String = "",
        kit: String = "",
        phase: String = "",
        itemType: String = "",
        qty: String = "",
        note: String = "",
        order: Double = 0,
        extra: [String: JSONValue] = [:]
    ) {
        self.id = id; self.itemId = itemId; self.templateId = templateId
        self.seasons = seasons; self.contexts = contexts; self.transports = transports
        self.catering = catering; self.weather = weather
        self.container = container; self.section = section; self.kit = kit; self.phase = phase
        self.itemType = itemType; self.qty = qty; self.note = note; self.order = order
        self.extra = extra
    }

    static let knownKeys: Set<String> = [
        "id", "itemId", "templateId", "seasons", "contexts", "transports", "catering", "weather",
        "container", "section", "kit", "phase", "itemType", "qty", "note", "order",
    ]

    /// `coerceMembership(json)`.
    public init(json: JSONValue) {
        let o = json.objectValue ?? [:]
        // `typeof m.qty === 'string' ? m.qty : (m.qty ? String(m.qty) : '')`
        let qty: String = o["qty"]?.stringValue ?? (jsTruthy(o["qty"]) ? (o["qty"]?.jsString ?? "") : "")
        self.init(
            id: jsLooseText(o["id"]),
            itemId: jsLooseText(o["itemId"]),
            templateId: jsLooseText(o["templateId"]),
            seasons: asStringArray(o["seasons"]),
            contexts: asStringArray(o["contexts"]),
            transports: asStringArray(o["transports"]),
            catering: asStringArray(o["catering"]),
            weather: asStringArray(o["weather"]),
            container: jsStringOr(o["container"]),
            section: jsStringOr(o["section"]),
            kit: jsStringOr(o["kit"]),
            phase: jsStringOr(o["phase"]),
            itemType: jsStringOr(o["itemType"]),
            qty: qty,
            note: jsStringOr(o["note"]),
            order: o["order"]?.finiteNumber ?? 0,
            extra: extraKeys(o, known: Membership.knownKeys)
        )
        self = coerceMembership(self)
    }

    public var json: JSONValue {
        var o = extra
        o["id"] = .string(id); o["itemId"] = .string(itemId); o["templateId"] = .string(templateId)
        o["seasons"] = JSONValue(seasons); o["contexts"] = JSONValue(contexts)
        o["transports"] = JSONValue(transports); o["catering"] = JSONValue(catering)
        o["weather"] = JSONValue(weather)
        o["container"] = .string(container); o["section"] = .string(section); o["kit"] = .string(kit)
        o["phase"] = .string(phase); o["itemType"] = .string(itemType); o["qty"] = .string(qty)
        o["note"] = .string(note); o["order"] = .number(order)
        return .object(o)
    }
}

/// The value rules of `coerceMembership`, for a membership built in memory.
public func coerceMembership(_ membership: Membership) -> Membership {
    var m = membership
    m.weather = m.weather.filter { WEATHER_CONDITION_IDS.contains($0) }
    m.phase = jsSlice(jsTrim(m.phase), 0, 40)   // '' = use item default; unknown ids kept
    m.itemType = (m.itemType == "item" || m.itemType == "reminder") ? m.itemType : ""
    m.order = m.order.isFinite ? m.order : 0
    return m
}
/// `coerceMembership(m)` for raw JSON. nil when it is not an object.
public func coerceMembership(json m: JSONValue?) -> Membership? {
    guard let m = m, m.objectValue != nil else { return nil }
    return Membership(json: m)
}

/// `newMembership({ … })` — the same parameters as `Membership.init`, then `coerceMembership`.
public func newMembership(
    id: String = PackingEnv.makeId(),
    itemId: String = "",
    templateId: String = "",
    seasons: [String] = [],
    contexts: [String] = [],
    transports: [String] = [],
    catering: [String] = [],
    weather: [String] = [],
    container: String = "",
    section: String = "",
    kit: String = "",
    phase: String = "",
    itemType: String = "",
    qty: String = "",
    note: String = "",
    order: Double = 0,
    extra: [String: JSONValue] = [:]
) -> Membership {
    coerceMembership(Membership(id: id, itemId: itemId, templateId: templateId, seasons: seasons,
                                contexts: contexts, transports: transports, catering: catering,
                                weather: weather, container: container, section: section, kit: kit,
                                phase: phase, itemType: itemType, qty: qty, note: note, order: order, extra: extra))
}
/// `newMembership(m)` — coerce a membership already built with `Membership(…)`.
public func newMembership(_ membership: Membership) -> Membership { coerceMembership(membership) }
/// `newMembership(partial)` for a raw JSON partial, laid over the defaults as the JS spreads it.
public func newMembership(json partial: JSONValue) -> Membership {
    var o = Membership().json.objectValue ?? [:]
    for (k, v) in partial.objectValue ?? [:] { o[k] = v }
    return Membership(json: .object(o))
}

// MARK: - Which half of an item belongs where

/// Every field that belongs to the PHYSICAL OBJECT rather than to one template.
/// This list is the single source of truth, used both to push edits onto the shared
/// item (`applyIntrinsic`) and to carry an item between templates (`linkFields`).
/// Keeping one list is deliberate: the two used to be written out by hand
/// separately, they drifted, and a partial copy silently erased photos, the care
/// record and every purchase detail off the shared item. Add new item-level fields
/// HERE and both sides stay correct for free.
/// (These are the JSON keys — the same names as the `Item` properties.)
public let INTRINSIC_FIELDS: [String] = [
    "name", "swedish", "category", "charging", "chargeType", "liquid", "restricted",
    "perNight", "consumable", "shortList", "weight", "storage", "packer", "sub",
    "photos", "thumb", "maintenance", "stats",
    "color", "size", "manufacturer", "model", "ownedBy", "acquired", "price", "currency",
    "purchaseLink", "expiry", "condition", "retired", "retiredReason", "keep", "serial",
    "qtyOwned", "warranty", "capacityL", "maxKg",
]

/// Container and phase are intrinsic too, but they reach the catalog through their
/// OWN channel (`_defContainer` / `_defPhase` — `Item.defContainer` / `Item.defPhase`)
/// rather than through the resolved value, because the resolved value may be a
/// per-list exception or a template default. Writing `it.container` onto the item
/// would let "in Hiking, use the hiking backpack" leak out and become the answer
/// everywhere. An ordered list of pairs, because JS walks it in this order.
public let DEFAULT_FIELDS: [(field: String, channel: String)] = [
    (field: "container", channel: "_defContainer"),
    (field: "phase", channel: "_defPhase"),
]

/// The contextual (per-template) half of an item — everything that is allowed to
/// differ between two lists that share the same physical object.
/// NOTE `section` is deliberately NOT here. A section is `{id, name}` belonging to
/// ONE template, so copying the id into another template stores an id that means
/// nothing there. It travels by NAME instead, via `mapSectionAcrossTemplates`.
public let CONTEXTUAL_FIELDS: [String] = [
    "seasons", "contexts", "transports", "catering", "weather",
    "kit", "qty", "note", "itemType",
]
