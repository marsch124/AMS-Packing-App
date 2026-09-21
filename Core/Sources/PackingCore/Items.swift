// Items — the Item type (catalogue item, resolved template item AND trip entry),
// photo references, "whose it is", the care record, usage stats, `coerceItem`, `newItem`.
// Ported from js/model.js ("Shape guards", "Photo references", "Whose it is", "Constructors").
//
// ONE STRUCT, THREE ROLES — exactly as one JS object shape serves all three, and
// `coerceItem` is applied to all three:
//   • a CATALOGUE item        — the thing itself, once
//   • a RESOLVED item         — the thing as one template sees it (carries `_itemId`,
//                               `_memId` and the `_ov…/_tpl…/_def…` container/phase parts)
//   • a TRIP ENTRY            — the frozen line on a trip (carries `sourceListId`,
//                               `sourceItemId`, `custom`, `checked`, `skipped`, `used`, `_edited`)
//
// OPTIONAL vs DEFAULT. A field `coerceItem` always fills has a plain type and a
// default. A field the JS leaves `undefined` unless something sets it — and whose
// absence MEANS something (`used`, `_ovContainer`, `sourceItemId`…) — is Optional,
// nil standing for `undefined` (and for `null`). The yes/no markers the JS only ever
// tests for truthiness (`checked`, `custom`, `skipped`, `keep`, `_edited`, `_link`)
// are plain Bools. All of those are left OUT of the JSON when false / nil.

import Foundation

// MARK: - Care record

public struct MaintenanceLogEntry: JSONModel, Hashable, Sendable {
    public var date: String
    public var note: String
    public init(date: String = "", note: String = "") { self.date = date; self.note = note }
    public init(json: JSONValue) {
        // `e && e.date` / `e && e.note`: a non-object entry reads as blank.
        self.date = isYMD(json["date"]) ? jsStringOr(json["date"]) : ""
        self.note = jsStringOr(json["note"])
    }
    public var json: JSONValue { ["date": .string(date), "note": .string(note)] }
}

/// A care record: how to look after the physical thing, plus an optional recurring
/// schedule and a log of what was done when. Kept nil unless it holds real content,
/// so the 200+ everyday items (socks, toothpaste) carry no dead weight.
public struct Maintenance: JSONModel, Hashable, Sendable {
    public var notes: String
    public var link: String
    public var intervalDays: Int
    public var lastDone: String
    public var log: [MaintenanceLogEntry]

    public init(notes: String = "", link: String = "", intervalDays: Int = 0, lastDone: String = "",
                log: [MaintenanceLogEntry] = []) {
        self.notes = notes; self.link = link; self.intervalDays = intervalDays
        self.lastDone = lastDone; self.log = log
    }
    /// The cleaned record — an empty one if `normalizeMaintenance` would give null.
    public init(json: JSONValue) { self = normalizeMaintenance(json: json) ?? Maintenance() }
    public var json: JSONValue {
        ["notes": .string(notes), "link": .string(link), "intervalDays": .number(Double(intervalDays)),
         "lastDone": .string(lastDone), "log": .array(log.map { $0.json })]
    }
    var isEmpty: Bool { notes.isEmpty && link.isEmpty && intervalDays == 0 && lastDone.isEmpty && log.isEmpty }
}

/// The value rules of `normalizeMaintenance`, for a record built in memory.
public func normalizeMaintenance(_ m: Maintenance?) -> Maintenance? {
    guard let m = m else { return nil }
    let out = Maintenance(
        notes: m.notes,
        link: m.link,
        intervalDays: m.intervalDays > 0 ? m.intervalDays : 0,
        lastDone: isYMD(m.lastDone) ? m.lastDone : "",
        log: m.log
            .map { MaintenanceLogEntry(date: isYMD($0.date) ? $0.date : "", note: $0.note) }
            .filter { !$0.date.isEmpty }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.date, b.date) })   // oldest first
    )
    return out.isEmpty ? nil : out
}
/// `normalizeMaintenance(m)` for raw JSON: null unless it is an object with real content.
public func normalizeMaintenance(json m: JSONValue?) -> Maintenance? {
    guard let o = m?.objectValue else { return nil }
    var interval = 0
    if let n = o["intervalDays"]?.finiteNumber, n > 0 { interval = jsFloorInt(n) }
    return normalizeMaintenance(Maintenance(
        notes: jsStringOr(o["notes"]),
        link: jsStringOr(o["link"]),
        intervalDays: interval,
        lastDone: jsStringOr(o["lastDone"]),
        log: asArray(o["log"]).map { MaintenanceLogEntry(json: $0) }
    ))
}

// MARK: - Usage stats

/// Usage learning: how often a building-block item was packed vs actually used —
/// and, since v162, how often it was on the list and never packed at all.
///
/// `skipped` is its own count on purpose. Standing on a list you never pack from
/// is a different fact about an item than being packed and not used, and it is
/// arguably the stronger hint that it does not belong there — so it is counted
/// separately rather than folded into `unused`.
public struct ItemStats: JSONModel, Hashable, Sendable {
    public var packed: Int
    public var used: Int
    public var unused: Int
    public var skipped: Int
    public var lastReviewed: String

    public init(packed: Int = 0, used: Int = 0, unused: Int = 0, skipped: Int = 0, lastReviewed: String = "") {
        self.packed = packed; self.used = used; self.unused = unused; self.skipped = skipped
        self.lastReviewed = lastReviewed
    }
    public init(json: JSONValue) { self = normalizeStats(json: json) }
    public var json: JSONValue {
        ["packed": .number(Double(packed)), "used": .number(Double(used)), "unused": .number(Double(unused)),
         "skipped": .number(Double(skipped)), "lastReviewed": .string(lastReviewed)]
    }
}

// (Not exported by the JS module, so not public here either.)
func normalizeStats(_ s: ItemStats?) -> ItemStats {
    guard let s = s else { return ItemStats() }
    return ItemStats(packed: max(0, s.packed), used: max(0, s.used), unused: max(0, s.unused),
                     skipped: max(0, s.skipped), lastReviewed: s.lastReviewed)
}
func normalizeStats(json s: JSONValue?) -> ItemStats {
    func n(_ v: JSONValue?) -> Int {
        guard let d = v?.finiteNumber, d >= 0 else { return 0 }
        return jsFloorInt(d)
    }
    let o = s?.objectValue ?? [:]
    return ItemStats(packed: n(o["packed"]), used: n(o["used"]), unused: n(o["unused"]), skipped: n(o["skipped"]),
                     lastReviewed: jsStringOr(o["lastReviewed"]))
}

// MARK: - Photo references

// Photos used to be stored inline on the item as `data:image/jpeg;base64,…`
// strings. They are now held once in their own store and referenced by id, so
// an item stays small: reading, writing, backing up or syncing the catalogue no
// longer drags tens of megabytes of JPEG along with it.
//
// `isPhotoRef` is the discriminator both shapes are read through, so a database
// part-way through the migration (or an old backup file) still renders.
public func isPhotoRef(_ s: String?) -> Bool {
    guard let s = s, !s.isEmpty else { return false }
    return !s.hasPrefix("data:")
}
/// The ids on an item, ignoring anything still inline.
public func photoRefs(_ item: Item?) -> [String] { (item?.photos ?? []).filter { isPhotoRef($0) } }
/// The inline `data:` images still on an item — what the migration has to move.
public func inlinePhotos(_ item: Item?) -> [String] { (item?.photos ?? []).filter { $0.hasPrefix("data:") } }
/// Does anything in this collection still carry an inline image?
public func hasInlinePhotos(_ items: [Item]) -> Bool { items.contains { !inlinePhotos($0).isEmpty } }

/// How many photos a single item may hold — keeps the editor tidy and bounds
/// how large an exported/shared trip bundle can grow.
public let MAX_PHOTOS = 5

// MARK: - "Whose it is"

// The field is `ownedBy`, NOT `owner`, and that is load-bearing.
//
// `owner` is a RESERVED property on every synced row: the sync addon stamps the
// signed-in account's address onto it on every single write, and uses it for access
// control. The app used `owner` for its own "whose thing is this" answer, so the two
// collided and every item in the catalogue silently came back owned by an e-mail
// address. Moving the app's answer to `ownedBy` ends the collision for good.
// THIS PACKAGE HAS NO `owner` FIELD ANYWHERE, and never will.

/// `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` on the trimmed text.
public func looksLikeEmail(_ v: String?) -> Bool {
    let s = Array(jsTrim(v ?? "").unicodeScalars)
    guard !s.contains(where: { jsIsWhitespace($0) }) else { return false }
    let ats = s.indices.filter { s[$0] == "@" }
    guard ats.count == 1, let at = ats.first, at > 0 else { return false }
    let domain = Array(s[(at + 1)...])
    guard domain.count >= 3 else { return false }
    // A dot with at least one character on each side of it.
    return domain[1..<(domain.count - 1)].contains(".")
}

/// Turn a sign-in address into the name a person would actually use:
/// "anna.berg@example.com" → "Anna". Takes the part before the @, then its first
/// word (splitting on . _ + -), and capitalises it. Falls back to the whole local
/// part when that first word is too short to be a name ("a.b@…").
public func ownerNameFromEmail(_ addr: String?) -> String {
    let trimmed = jsTrim(addr ?? "")
    let local = trimmed.components(separatedBy: "@").first ?? ""
    if local.isEmpty { return "" }
    let separators = CharacterSet(charactersIn: "._+-")
    let first = local.components(separatedBy: separators).first { !$0.isEmpty } ?? local
    let word = jsLength(first) >= 2 ? first : local
    guard let head = word.unicodeScalars.first else { return "" }
    let rest = String(word.unicodeScalars.dropFirst())
    // `charAt(0)` is one UTF-16 unit: half of an astral character is left as it is.
    let cap = head.value > 0xFFFF ? String(head) : String(head).uppercased()
    return cap + rest
}

// MARK: - Item

public struct Item: JSONModel, Hashable, Sendable {
    // --- identity & wording
    public var id: String
    public var name: String
    /// Original Swedish wording, kept as a subtitle.
    public var swedish: String
    /// Free text ("2", "1 pair"). A JS number is read as its text.
    public var qty: String
    // --- the three grouping dimensions
    public var category: String
    public var container: String
    public var phase: String
    /// 'item' (packable) | 'reminder' (a to-do prompt)
    public var itemType: String
    // --- flags
    public var charging: Bool
    /// How it charges: USB-C / USB-A / Lightning / special… ('' = unspecified)
    public var chargeType: String
    /// Part of the minimal "short home list".
    public var shortList: Bool
    // --- conditions (empty = applies to any)
    public var seasons: [String]
    public var contexts: [String]
    public var transports: [String]
    public var catering: [String]
    /// Weather conditions this item is FOR (empty = not weather-conditional).
    public var weather: [String]
    /// Optional nested sub-items (names).
    public var sub: [String]
    public var note: String
    /// Grams per unit (0 = unknown).
    public var weight: Double
    public var liquid: Bool
    public var restricted: Bool
    public var perNight: Bool
    public var consumable: Bool
    /// On a resolved item a SECTION ID; on a trip line the section's DISPLAY NAME.
    public var section: String
    /// Kit NAME this item is packed as part of ('' = none; contextual, like section).
    public var kit: String
    /// Whose job it is to pack this (person name; '' = anyone).
    public var packer: String
    /// Where the physical item is kept at home (free text).
    public var storage: String
    /// Ids into the photos store (max MAX_PHOTOS); may still hold inline `data:` URLs.
    public var photos: [String]
    /// Small inline thumbnail of the first photo, for list rows.
    public var thumb: String
    public var maintenance: Maintenance?
    public var stats: ItemStats
    // --- descriptive / ownership metadata (all intrinsic to the item)
    public var color: String
    public var size: String
    public var manufacturer: String
    public var model: String
    /// Whose item it is. NEVER called `owner` — see the note above `looksLikeEmail`.
    public var ownedBy: String
    public var acquired: String
    public var price: Double
    public var currency: String
    public var purchaseLink: String
    public var expiry: String
    public var condition: String
    public var retired: Bool
    public var retiredReason: String
    public var serial: String
    public var qtyOwned: Int
    public var warranty: String
    /// Packing capacity in litres (used by containers; 0 = unset).
    public var capacityL: Double
    /// Max load weight in kg (used by containers; 0 = unset).
    public var maxKg: Double
    /// "Keep it" — the Refine screen's answer that stops a prune suggestion for good.
    public var keep: Bool

    // --- TRIP ENTRY only
    public var sourceListId: String?
    public var sourceItemId: String?
    /// Added by hand on the trip (always kept by `regenerateEntries`).
    public var custom: Bool
    /// Packed.
    public var checked: Bool
    /// Set aside for THIS trip: still on the list, not being packed, out of every count.
    public var skipped: Bool
    /// The post-trip review's answer. nil = not answered (JS `typeof e.used !== 'boolean'`).
    public var used: Bool?
    /// JSON key `_edited` — the user changed this line, so a regenerate must keep it.
    public var edited: Bool

    // --- RESOLVED item only (JSON keys carry a leading underscore)
    /// `_itemId` — the catalogue item this was resolved from.
    public var itemId: String?
    /// `_memId` — the membership it was resolved through ('' = none, a thing on no list).
    public var memId: String?
    /// `_link` — a link into another template: names the item, carries only the per-list
    /// choices. In JS every intrinsic field of a link is `undefined`, which is what makes
    /// `applyIntrinsic` step over it; here that is what this flag says.
    public var link: Bool
    /// `_ovContainer` — this list's exception ('' = none). nil = never resolved.
    public var ovContainer: String?
    /// `_tplContainer` — the template's default ('' = none).
    public var tplContainer: String?
    /// `_defContainer` — the item's own default, true everywhere.
    public var defContainer: String?
    /// `_ovPhase` — this list's phase exception ('' = none). nil = never resolved.
    public var ovPhase: String?
    /// `_defPhase` — the item's own default phase.
    public var defPhase: String?

    /// Any key this package does not know — kept so nothing is lost on a round trip.
    public var extra: [String: JSONValue]

    /// The defaults are `newItem`'s. NOTE this does not coerce — `newItem(…)` does.
    public init(
        id: String = PackingEnv.makeId(),
        name: String = "",
        swedish: String = "",
        qty: String = "",
        category: String = CATEGORY_DEFAULT,
        container: String = "Carry-on / hand luggage",
        phase: String = "week",
        itemType: String = "item",
        charging: Bool = false,
        chargeType: String = "",
        shortList: Bool = false,
        seasons: [String] = [],
        contexts: [String] = [],
        transports: [String] = [],
        catering: [String] = [],
        weather: [String] = [],
        sub: [String] = [],
        note: String = "",
        weight: Double = 0,
        liquid: Bool = false,
        restricted: Bool = false,
        perNight: Bool = false,
        consumable: Bool = false,
        section: String = "",
        kit: String = "",
        packer: String = "",
        storage: String = "",
        photos: [String] = [],
        thumb: String = "",
        maintenance: Maintenance? = nil,
        stats: ItemStats = ItemStats(),
        color: String = "",
        size: String = "",
        manufacturer: String = "",
        model: String = "",
        ownedBy: String = "",
        acquired: String = "",
        price: Double = 0,
        currency: String = "",
        purchaseLink: String = "",
        expiry: String = "",
        condition: String = "",
        retired: Bool = false,
        retiredReason: String = "",
        serial: String = "",
        qtyOwned: Int = 0,
        warranty: String = "",
        capacityL: Double = 0,
        maxKg: Double = 0,
        keep: Bool = false,
        sourceListId: String? = nil,
        sourceItemId: String? = nil,
        custom: Bool = false,
        checked: Bool = false,
        skipped: Bool = false,
        used: Bool? = nil,
        edited: Bool = false,
        itemId: String? = nil,
        memId: String? = nil,
        link: Bool = false,
        ovContainer: String? = nil,
        tplContainer: String? = nil,
        defContainer: String? = nil,
        ovPhase: String? = nil,
        defPhase: String? = nil,
        extra: [String: JSONValue] = [:]
    ) {
        self.id = id; self.name = name; self.swedish = swedish; self.qty = qty
        self.category = category; self.container = container; self.phase = phase; self.itemType = itemType
        self.charging = charging; self.chargeType = chargeType; self.shortList = shortList
        self.seasons = seasons; self.contexts = contexts; self.transports = transports
        self.catering = catering; self.weather = weather; self.sub = sub; self.note = note
        self.weight = weight; self.liquid = liquid; self.restricted = restricted
        self.perNight = perNight; self.consumable = consumable
        self.section = section; self.kit = kit; self.packer = packer; self.storage = storage
        self.photos = photos; self.thumb = thumb; self.maintenance = maintenance; self.stats = stats
        self.color = color; self.size = size; self.manufacturer = manufacturer; self.model = model
        self.ownedBy = ownedBy; self.acquired = acquired; self.price = price; self.currency = currency
        self.purchaseLink = purchaseLink; self.expiry = expiry; self.condition = condition
        self.retired = retired; self.retiredReason = retiredReason; self.serial = serial
        self.qtyOwned = qtyOwned; self.warranty = warranty; self.capacityL = capacityL; self.maxKg = maxKg
        self.keep = keep
        self.sourceListId = sourceListId; self.sourceItemId = sourceItemId
        self.custom = custom; self.checked = checked; self.skipped = skipped; self.used = used
        self.edited = edited
        self.itemId = itemId; self.memId = memId; self.link = link
        self.ovContainer = ovContainer; self.tplContainer = tplContainer; self.defContainer = defContainer
        self.ovPhase = ovPhase; self.defPhase = defPhase
        self.extra = extra
    }

    /// Every JSON key this type reads or writes (`photo` and the two reserved sync
    /// keys are read-or-ignored and never written).
    static let knownKeys: Set<String> = [
        "id", "name", "swedish", "qty", "category", "container", "phase", "itemType",
        "charging", "chargeType", "shortList", "seasons", "contexts", "transports", "catering",
        "weather", "sub", "note", "weight", "liquid", "restricted", "perNight", "consumable",
        "section", "kit", "packer", "storage", "photos", "photo", "thumb", "maintenance", "stats",
        "color", "size", "manufacturer", "model", "ownedBy", "acquired", "price", "currency",
        "purchaseLink", "expiry", "condition", "retired", "retiredReason", "serial", "qtyOwned",
        "warranty", "capacityL", "maxKg", "keep",
        "sourceListId", "sourceItemId", "custom", "checked", "skipped", "used", "_edited",
        "_itemId", "_memId", "_link", "_ovContainer", "_tplContainer", "_defContainer", "_ovPhase", "_defPhase",
    ]

    /// `coerceItem(json)`: wrong type → the default, exactly as the web app reads it.
    /// NOTE a field the JSON does not carry gets `coerceItem`'s answer ('' for the
    /// container), NOT `newItem`'s default — use `newItem(json:)` for that.
    public init(json: JSONValue) {
        let o = json.objectValue ?? [:]
        func str(_ k: String) -> String { jsStringOr(o[k]) }
        func optStr(_ k: String) -> String? { o[k]?.stringValue }
        func num(_ k: String) -> Double { o[k]?.finiteNumber ?? 0 }
        func flag(_ k: String) -> Bool { jsTruthy(o[k]) }

        self.init(id: jsLooseText(o["id"]), container: jsLooseText(o["container"]), phase: str("phase"))
        name = jsLooseText(o["name"])
        swedish = str("swedish")
        qty = jsLooseText(o["qty"])
        category = str("category")
        itemType = str("itemType")
        charging = flag("charging")
        chargeType = str("chargeType")
        shortList = flag("shortList")
        seasons = asStringArray(o["seasons"])
        contexts = asStringArray(o["contexts"])
        transports = asStringArray(o["transports"])
        catering = asStringArray(o["catering"])
        weather = asStringArray(o["weather"])
        sub = asStringArray(o["sub"])
        note = jsLooseText(o["note"])
        weight = num("weight")
        liquid = flag("liquid")
        restricted = flag("restricted")
        perNight = flag("perNight")
        consumable = flag("consumable")
        section = str("section")
        kit = str("kit")
        packer = str("packer")
        storage = str("storage")
        // `photos` holds REFERENCES (ids into the photos store). A legacy single
        // `photo` string is folded in and then dropped.
        var pics = asArray(o["photos"]).compactMap { $0.stringValue }.filter { !$0.isEmpty }
        if pics.isEmpty, let legacy = o["photo"]?.stringValue, !legacy.isEmpty { pics = [legacy] }
        photos = pics
        thumb = str("thumb")
        maintenance = normalizeMaintenance(json: o["maintenance"])
        stats = normalizeStats(json: o["stats"])
        color = str("color")
        size = str("size")
        manufacturer = str("manufacturer")
        model = str("model")
        // A legacy `owner` written before v117 is adopted here so an old backup file
        // still carries its owners across, but an address the sync stamped there is
        // ignored: it was never a name anyone typed.
        if let own = o["ownedBy"]?.stringValue {
            ownedBy = own
        } else if let legacy = o["owner"]?.stringValue, !looksLikeEmail(legacy) {
            ownedBy = legacy
        } else {
            ownedBy = ""
        }
        acquired = str("acquired")
        price = num("price")
        currency = str("currency")
        purchaseLink = str("purchaseLink")
        expiry = str("expiry")
        condition = str("condition")
        retired = flag("retired")
        retiredReason = str("retiredReason")
        serial = str("serial")
        if let q = o["qtyOwned"]?.finiteNumber, q >= 0 { qtyOwned = jsFloorInt(q) } else { qtyOwned = 0 }
        warranty = str("warranty")
        capacityL = num("capacityL")
        maxKg = num("maxKg")
        keep = flag("keep")

        sourceListId = optStr("sourceListId")
        sourceItemId = optStr("sourceItemId")
        custom = flag("custom")
        checked = flag("checked")
        skipped = flag("skipped")
        used = o["used"]?.boolValue
        edited = flag("_edited")

        itemId = optStr("_itemId")
        memId = optStr("_memId")
        link = flag("_link")
        ovContainer = optStr("_ovContainer")
        tplContainer = optStr("_tplContainer")
        defContainer = optStr("_defContainer")
        ovPhase = optStr("_ovPhase")
        defPhase = optStr("_defPhase")

        extra = extraKeys(o, known: Item.knownKeys)
        self = coerceItem(self)
    }

    public var json: JSONValue {
        var o = extra
        o["id"] = .string(id); o["name"] = .string(name); o["swedish"] = .string(swedish); o["qty"] = .string(qty)
        o["category"] = .string(category); o["container"] = .string(container); o["phase"] = .string(phase)
        o["itemType"] = .string(itemType); o["charging"] = .bool(charging); o["chargeType"] = .string(chargeType)
        o["shortList"] = .bool(shortList)
        o["seasons"] = JSONValue(seasons); o["contexts"] = JSONValue(contexts); o["transports"] = JSONValue(transports)
        o["catering"] = JSONValue(catering); o["weather"] = JSONValue(weather); o["sub"] = JSONValue(sub)
        o["note"] = .string(note); o["weight"] = .number(weight)
        o["liquid"] = .bool(liquid); o["restricted"] = .bool(restricted); o["perNight"] = .bool(perNight)
        o["consumable"] = .bool(consumable)
        o["section"] = .string(section); o["kit"] = .string(kit); o["packer"] = .string(packer)
        o["storage"] = .string(storage); o["photos"] = JSONValue(photos); o["thumb"] = .string(thumb)
        o["maintenance"] = maintenance?.json ?? .null
        o["stats"] = stats.json
        o["color"] = .string(color); o["size"] = .string(size); o["manufacturer"] = .string(manufacturer)
        o["model"] = .string(model); o["ownedBy"] = .string(ownedBy); o["acquired"] = .string(acquired)
        o["price"] = .number(price); o["currency"] = .string(currency); o["purchaseLink"] = .string(purchaseLink)
        o["expiry"] = .string(expiry); o["condition"] = .string(condition); o["retired"] = .bool(retired)
        o["retiredReason"] = .string(retiredReason); o["serial"] = .string(serial)
        o["qtyOwned"] = .number(Double(qtyOwned)); o["warranty"] = .string(warranty)
        o["capacityL"] = .number(capacityL); o["maxKg"] = .number(maxKg)
        // Everything below is left out unless it says something.
        if keep { o["keep"] = true }
        if let v = sourceListId { o["sourceListId"] = .string(v) }
        if let v = sourceItemId { o["sourceItemId"] = .string(v) }
        if custom { o["custom"] = true }
        if checked { o["checked"] = true }
        if skipped { o["skipped"] = true }
        if let v = used { o["used"] = .bool(v) }
        if edited { o["_edited"] = true }
        if let v = itemId { o["_itemId"] = .string(v) }
        if let v = memId { o["_memId"] = .string(v) }
        if link { o["_link"] = true }
        if let v = ovContainer { o["_ovContainer"] = .string(v) }
        if let v = tplContainer { o["_tplContainer"] = .string(v) }
        if let v = defContainer { o["_defContainer"] = .string(v) }
        if let v = ovPhase { o["_ovPhase"] = .string(v) }
        if let v = defPhase { o["_defPhase"] = .string(v) }
        return .object(o)
    }
}

/// A field `coerceItem` never touches (`id`, `name`, `qty`, `container`, `note`): a
/// string is itself, a number is its text (an old numeric `qty`), anything else is ''.
func jsLooseText(_ v: JSONValue?) -> String {
    switch v {
    case .string(let s)?: return s
    case .number(let n)?: return jsNumberToString(n)
    default: return ""
    }
}

// MARK: - coerceItem

/// The value rules of `coerceItem`, for an item built in memory. (JS mutates and
/// returns the same object; here the cleaned copy is returned.)
public func coerceItem(_ item: Item) -> Item {
    var it = item
    it.weather = it.weather.filter { WEATHER_CONDITION_IDS.contains($0) }   // conditional-gear tags
    // Any non-empty phase id is KEPT, even one this device doesn't recognise. Phases
    // are editable and they SYNC, so a whitelist here would silently retag an item
    // the moment one device read a phase the other had just added — and unlike a
    // condition, a phase decides where the thing appears on the packing list. Only a
    // missing phase falls back to the default.
    let ph = jsTrim(it.phase)
    it.phase = ph.isEmpty ? defaultPhaseId() : jsSlice(ph, 0, 40)
    if it.category.isEmpty { it.category = CATEGORY_DEFAULT }
    it.itemType = it.itemType == "reminder" ? "reminder" : "item"
    it.chargeType = CHARGE_TYPE_IDS.contains(it.chargeType) ? it.chargeType : ""   // only meaningful when charging
    it.stats = normalizeStats(it.stats)
    it.weight = (it.weight.isFinite && it.weight >= 0) ? it.weight : 0   // grams per unit, 0 = unknown
    // During the one-time photo migration this array may still hold inline `data:`
    // URLs from before the split, so both shapes are tolerated here and
    // `isPhotoRef()` tells them apart.
    it.photos = it.photos.filter { !$0.isEmpty }
    if it.photos.count > MAX_PHOTOS { it.photos = Array(it.photos.prefix(MAX_PHOTOS)) }
    it.maintenance = normalizeMaintenance(it.maintenance)   // care record, or nil when unused
    it.acquired = isYMD(it.acquired) ? it.acquired : ""
    it.price = (it.price.isFinite && it.price >= 0) ? it.price : 0   // 0 = unset
    it.expiry = isYMD(it.expiry) ? it.expiry : ""
    // Any non-empty condition id is KEPT, even one this device doesn't recognise.
    // Conditions are editable and live per-device, so a whitelist here would silently
    // erase a condition set on the other device the first time this one saved the item.
    it.condition = jsSlice(jsTrim(it.condition), 0, 40)
    it.retiredReason = RETIRE_REASON_IDS.contains(it.retiredReason) ? it.retiredReason : ""   // only meaningful when retired
    it.qtyOwned = max(0, it.qtyOwned)   // 0 = unset
    it.warranty = isYMD(it.warranty) ? it.warranty : ""
    it.capacityL = (it.capacityL.isFinite && it.capacityL >= 0) ? it.capacityL : 0
    it.maxKg = (it.maxKg.isFinite && it.maxKg >= 0) ? it.maxKg : 0
    return it
}

/// `coerceItem(it)` for raw JSON. nil when it is not an object (JS hands a
/// non-object straight back; every caller then skips it).
public func coerceItem(json it: JSONValue?) -> Item? {
    guard let it = it, it.objectValue != nil else { return nil }
    return Item(json: it)
}

/// `asArray(v).map(coerceItem)` — entries that are not objects are dropped (JS keeps
/// the junk in the array and every reader steps over it).
func coerceItems(json v: JSONValue?) -> [Item] { asArray(v).compactMap { coerceItem(json: $0) } }

// MARK: - newItem

/// `newItem({ … })` — the same parameters as `Item.init`, then `coerceItem`.
public func newItem(
    id: String = PackingEnv.makeId(),
    name: String = "",
    swedish: String = "",
    qty: String = "",
    category: String = CATEGORY_DEFAULT,
    container: String = "Carry-on / hand luggage",
    phase: String = "week",
    itemType: String = "item",
    charging: Bool = false,
    chargeType: String = "",
    shortList: Bool = false,
    seasons: [String] = [],
    contexts: [String] = [],
    transports: [String] = [],
    catering: [String] = [],
    weather: [String] = [],
    sub: [String] = [],
    note: String = "",
    weight: Double = 0,
    liquid: Bool = false,
    restricted: Bool = false,
    perNight: Bool = false,
    consumable: Bool = false,
    section: String = "",
    kit: String = "",
    packer: String = "",
    storage: String = "",
    photos: [String] = [],
    thumb: String = "",
    maintenance: Maintenance? = nil,
    stats: ItemStats = ItemStats(),
    color: String = "",
    size: String = "",
    manufacturer: String = "",
    model: String = "",
    ownedBy: String = "",
    acquired: String = "",
    price: Double = 0,
    currency: String = "",
    purchaseLink: String = "",
    expiry: String = "",
    condition: String = "",
    retired: Bool = false,
    retiredReason: String = "",
    serial: String = "",
    qtyOwned: Int = 0,
    warranty: String = "",
    capacityL: Double = 0,
    maxKg: Double = 0,
    keep: Bool = false,
    sourceListId: String? = nil,
    sourceItemId: String? = nil,
    custom: Bool = false,
    checked: Bool = false,
    skipped: Bool = false,
    used: Bool? = nil,
    edited: Bool = false,
    itemId: String? = nil,
    memId: String? = nil,
    link: Bool = false,
    ovContainer: String? = nil,
    tplContainer: String? = nil,
    defContainer: String? = nil,
    ovPhase: String? = nil,
    defPhase: String? = nil,
    extra: [String: JSONValue] = [:]
) -> Item {
    coerceItem(Item(
        id: id, name: name, swedish: swedish, qty: qty, category: category, container: container,
        phase: phase, itemType: itemType, charging: charging, chargeType: chargeType, shortList: shortList,
        seasons: seasons, contexts: contexts, transports: transports, catering: catering, weather: weather,
        sub: sub, note: note, weight: weight, liquid: liquid, restricted: restricted, perNight: perNight,
        consumable: consumable, section: section, kit: kit, packer: packer, storage: storage,
        photos: photos, thumb: thumb, maintenance: maintenance, stats: stats, color: color, size: size,
        manufacturer: manufacturer, model: model, ownedBy: ownedBy, acquired: acquired, price: price,
        currency: currency, purchaseLink: purchaseLink, expiry: expiry, condition: condition,
        retired: retired, retiredReason: retiredReason, serial: serial, qtyOwned: qtyOwned,
        warranty: warranty, capacityL: capacityL, maxKg: maxKg, keep: keep,
        sourceListId: sourceListId, sourceItemId: sourceItemId, custom: custom, checked: checked,
        skipped: skipped, used: used, edited: edited, itemId: itemId, memId: memId, link: link,
        ovContainer: ovContainer, tplContainer: tplContainer, defContainer: defContainer,
        ovPhase: ovPhase, defPhase: defPhase, extra: extra
    ))
}

/// `newItem(item)` — coerce an item already built with `Item(…)`.
public func newItem(_ item: Item) -> Item { coerceItem(item) }

/// `newItem(partial)` for a raw JSON partial: laid over `newItem`'s defaults exactly
/// as the JS spreads it, THEN coerced. (So a `partial` with a legacy `owner` does not
/// reach `ownedBy` — the default `ownedBy: ''` is already there, as in JS.)
public func newItem(json partial: JSONValue) -> Item {
    var o = Item().json.objectValue ?? [:]
    for (k, v) in partial.objectValue ?? [:] { o[k] = v }
    return Item(json: .object(o))
}
