// Catalogue — the WRITE path of the relational core: decompose an edited (resolved)
// item back into the catalogue, links, the container repair, and the migration
// engine that folds copy-based lists into { items, memberships, templates }.
// Ported from js/model.js ("Write path", "Migrating the old frozen default container
// data", "Migration engine"). The read path is Resolve.swift.
//
// THE RULE THIS FILE EXISTS TO KEEP. A value here means one of three things — the
// ITEM's own default, the TEMPLATE's default, or one MEMBERSHIP's exception — and
// three separate silent data bugs in the web app were a producer writing the right
// value into the wrong one of those. Container resolves
//     exception (membership) → template default → item default
// and every producer below asks `containerOverrideFor` whether an exception is needed.
//
// "UNDEFINED" IN SWIFT. `applyIntrinsic` leaves alone every field that is `undefined`
// on the incoming object. A typed `Item` has no undefined fields, so:
//   • a LINK (`item.link`, JS `_link`) stands for "every intrinsic field but the name
//     is undefined" — exactly what `linkFromResolved` builds in JS;
//   • a partial edit (`{ packer: 'Anna' }`) goes through the `json:` form.
// Field NAMES are walked through `item.json`, because the three lists hold JSON keys.

import Foundation

// MARK: - What a JS caller would see as defined

/// Every key of an item's JSON — except that a link carries no intrinsic field but
/// its name, and no container / phase of its own (all `undefined` in JS).
fileprivate func definedKeys(_ it: Item) -> [String: JSONValue] {
    var o = it.json.objectValue ?? [:]
    if it.link {
        for f in INTRINSIC_FIELDS where f != "name" { o[f] = nil }
        o["container"] = nil
        o["phase"] = nil
    }
    return o
}

// MARK: - applyIntrinsic

/// Push a resolved item's intrinsic edits onto its shared catalog item.
///
/// A field that is `undefined` on the incoming object is LEFT ALONE. That single
/// rule is what makes a partial copy harmless: something that only carries the
/// contextual fields can no longer blank out the item's photos or care record.
/// Clearing a field on purpose still works — the editor sends '' , not undefined.
/// (JS mutates `cat` and returns it; here the updated copy is returned.)
public func applyIntrinsic(_ cat: Item, _ it: Item) -> Item {
    applyIntrinsic(cat, json: .object(definedKeys(it)))
}

/// `applyIntrinsic(cat, it)` for a partial object (`["serial": ""]`): a key that is
/// absent is left alone; one that is present — even null — is written, then coerced.
public func applyIntrinsic(_ cat: Item, json it: JSONValue?) -> Item {
    var o = cat.json.objectValue ?? [:]
    let src = it?.objectValue ?? [:]
    for f in INTRINSIC_FIELDS {
        if let v = src[f] { o[f] = v }
    }
    // The item's own DEFAULT container / phase, only when the caller supplied one.
    for d in DEFAULT_FIELDS {
        if let v = src[d.channel] { o[d.field] = v }
    }
    return Item(json: .object(o))   // = coerceItem(cat)
}

// MARK: - Sections travel by name

/// Carry an item's section from one template to another BY NAME: if the destination
/// has a section called the same thing, use its id; otherwise leave the item
/// unsectioned so it shows under Ungrouped, where it is visible and easy to file.
/// Deliberately does not invent a section in the destination — that would quietly
/// reorganise a list you had arranged by hand.
public func mapSectionAcrossTemplates(_ sectionId: String?, _ fromList: PackList?, _ toList: PackList?) -> String {
    guard let sid = sectionId, !sid.isEmpty else { return "" }
    guard let from = fromList?.sections.first(where: { $0.id == sid }) else { return "" }
    let wanted = normName(from.name)
    return toList?.sections.first(where: { normName($0.name) == wanted })?.id ?? ""
}

// MARK: - Links

/// Put an EXISTING catalog item into another template.
///
/// The result is a link, not a copy: it names the item by id and carries only the
/// per-list choices, leaving every intrinsic field out (`link == true`) so
/// `applyIntrinsic` passes over them. This is the fix for the bug where joining a
/// second template wrote a half-filled copy over the shared item and erased its
/// photos, care record, purchase details and serial number everywhere at once.
/// `section` (JS `opts.section`) is the section id IN THE DESTINATION template (work
/// it out with `mapSectionAcrossTemplates`); omit it and the item arrives unsectioned.
///
/// The Swift link is what decoding the JS link object gives: `id` and `container`
/// are '' and every intrinsic field holds its blank default — none of them is the
/// source item's, and none of them is ever read while `link` is true.
public func linkFromResolved(_ src: Item?, _ itemId: String, section: String = "") -> Item {
    var o: [String: JSONValue] = [
        "_itemId": .string(itemId),
        "_link": true,
        "name": .string(src?.name ?? ""),
    ]
    if let s = src {
        let from = definedKeys(s)
        for f in CONTEXTUAL_FIELDS {
            if let v = from[f] { o[f] = v }
        }
    }
    o["section"] = .string(section)
    // A new home starts with no exception — it follows the template's default, and
    // failing that the item's own. That is the whole point of a shared default.
    o["_ovContainer"] = ""
    o["_ovPhase"] = ""
    return Item(json: .object(o))
}

// MARK: - The container repair

/// One `itemId → container` pair: a row handed to `containerDefaultsFrom`, and one
/// entry of the Map it answers with.
public struct ContainerRow: Equatable, Hashable, Sendable {
    public var itemId: String
    public var container: String
    public init(itemId: String = "", container: String = "") { self.itemId = itemId; self.container = container }
    public var json: JSONValue { ["itemId": .string(itemId), "container": .string(container)] }
}

/// One `{ id, container }` edit of a plan — and one entry of its `effective` Map
/// (membership id → the container that row shows right now).
public struct ContainerChange: Equatable, Hashable, Sendable {
    public var id: String
    public var container: String
    public init(id: String = "", container: String = "") { self.id = id; self.container = container }
    public var json: JSONValue { ["id": .string(id), "container": .string(container)] }
}

extension Array where Element == ContainerRow {
    /// `map.get(itemId)` — nil for JS `undefined`.
    public func get(_ itemId: String) -> String? { first(where: { $0.itemId == itemId })?.container }
}
extension Array where Element == ContainerChange {
    /// `map.get(id)` — nil for JS `undefined`.
    public func get(_ id: String) -> String? { first(where: { $0.id == id })?.container }
}

/// What `planContainerMigration` answers. `defaults` and `effective` are Maps in JS;
/// here they are ORDERED arrays in the Map's insertion order (their `json` is the
/// `[...map]` form: an array of [key, value] pairs).
public struct ContainerMigrationPlan: Equatable, Sendable {
    /// itemId → the container that item uses most.
    public var defaults: [ContainerRow]
    /// membership id → what that row shows RIGHT NOW.
    public var effective: [ContainerChange]
    public var itemChanges: [ContainerChange]
    public var memChanges: [ContainerChange]
    public init(defaults: [ContainerRow] = [], effective: [ContainerChange] = [],
                itemChanges: [ContainerChange] = [], memChanges: [ContainerChange] = []) {
        self.defaults = defaults; self.effective = effective
        self.itemChanges = itemChanges; self.memChanges = memChanges
    }
    public var json: JSONValue {
        ["defaults": .array(defaults.map { [.string($0.itemId), .string($0.container)] }),
         "effective": .array(effective.map { [.string($0.id), .string($0.container)] }),
         "itemChanges": .array(itemChanges.map { $0.json }),
         "memChanges": .array(memChanges.map { $0.json })]
    }
}

/// A JS `Map<string, V>`: `set` on a key already there replaces the value and KEEPS
/// its original position. "First seen wins a tie" rests on exactly that order.
fileprivate struct OrderedMap<V> {
    private(set) var keys: [String] = []
    private var values: [String: V] = [:]
    func has(_ k: String) -> Bool { values[k] != nil }
    func get(_ k: String) -> V? { values[k] }
    mutating func set(_ k: String, _ v: V) {
        if values[k] == nil { keys.append(k) }
        values[k] = v
    }
    var entries: [(key: String, value: V)] { keys.map { (key: $0, value: values[$0]!) } }
}

/// Work out the whole container repair as a PLAN, without touching anything.
///
/// This lives here rather than in the store on purpose: the ordering is subtle and a
/// plain function can be tested. The trap is that a membership with no override
/// falls back to its item's default, so every effective value must be read BEFORE
/// any default is rewritten — read it afterwards and those rows quietly follow the
/// new default, which is the one thing this repair promises never to do.
public func planContainerMigration(_ items: [Item], _ mems: [Membership], _ templates: [PackList] = []) -> ContainerMigrationPlan {
    var itemsById: [String: Item] = [:]
    for i in items { itemsById[i.id] = i }   // `new Map(…)`: a repeated id, the last one wins
    // A template's own default bag is part of how a row resolves, so it must be in
    // hand both when reading the current value and when deciding what to store.
    var tplById: [String: String] = [:]
    for t in templates { tplById[t.id] = templateDefaults(t).container }
    func tplOf(_ m: Membership) -> String { tplById[m.templateId] ?? "" }
    func firstNonEmpty(_ a: String, _ b: String, _ c: String) -> String { !a.isEmpty ? a : (!b.isEmpty ? b : c) }
    // 1. Snapshot what every row shows RIGHT NOW.
    var effective = OrderedMap<String>()
    for m in mems {
        guard let item = itemsById[m.itemId] else { continue }
        effective.set(m.id, firstNonEmpty(m.container, tplOf(m), item.container))
    }
    // 2. Only then decide the new defaults.
    let rows = mems.filter { effective.has($0.id) }
        .map { ContainerRow(itemId: $0.itemId, container: effective.get($0.id) ?? "") }
    let defaults = containerDefaultsFrom(rows)
    var defaultOf: [String: String] = [:]
    for d in defaults { defaultOf[d.itemId] = d.container }
    // 3. And express the change as edits, still touching nothing.
    var itemChanges: [ContainerChange] = []
    for d in defaults {
        if let item = itemsById[d.itemId], item.container != d.container {
            itemChanges.append(ContainerChange(id: d.itemId, container: d.container))
        }
    }
    var memChanges: [ContainerChange] = []
    for m in mems {
        guard let eff = effective.get(m.id) else { continue }
        let want = containerOverrideFor(eff, tplOf(m), defaultOf[m.itemId] ?? "")
        if m.container != want { memChanges.append(ContainerChange(id: m.id, container: want)) }
    }
    return ContainerMigrationPlan(
        defaults: defaults,
        effective: effective.entries.map { ContainerChange(id: $0.key, container: $0.value) },
        itemChanges: itemChanges,
        memChanges: memChanges
    )
}

/// Promote a one-off trip entry into a real catalog item. Unlike a link this DOES
/// create a new item, so it must carry everything the entry has — including any
/// photo taken on the trip, which the old hand-written copier quietly dropped.
public func itemFromEntry(_ entry: Item) -> Item {
    var o = catalogItemFromResolved(entry).json.objectValue ?? [:]
    let src = definedKeys(entry)
    for f in CONTEXTUAL_FIELDS {
        if let v = src[f] { o[f] = v }
    }
    return Item(json: .object(o))
}

// --- Migrating the old "frozen default" container data ---
//
// Before v108 an item's default container was fixed at the moment it was created
// and no screen could change it, so every real choice ended up as a per-list
// override. This picks the container each item uses MOST across its lists and
// makes that its default; the lists that genuinely differ keep an explicit
// exception. Effective containers are unchanged — nothing moves on any list.
//
// Deterministic and idempotent: re-running it on already-migrated data produces
// exactly the same answer, which matters because two synced devices may both run it.
//
/// A Map in JS; here an ORDERED array, one entry per item in first-seen order.
public func containerDefaultsFrom(_ rows: [ContainerRow]) -> [ContainerRow] {
    var tally = OrderedMap<OrderedMap<Int>>()   // itemId -> (container -> count), insertion order breaks ties
    for r in rows {
        if r.itemId.isEmpty { continue }
        var t = tally.get(r.itemId) ?? OrderedMap<Int>()
        t.set(r.container, (t.get(r.container) ?? 0) + 1)
        tally.set(r.itemId, t)
    }
    var out: [ContainerRow] = []
    for (itemId, t) in tally.entries {
        var best = ""
        var bestN = -1
        for (c, n) in t.entries where n > bestN { best = c; bestN = n }   // first-seen wins a tie
        out.append(ContainerRow(itemId: itemId, container: best))
    }
    return out
}

// MARK: - A new catalogue item, a membership

/// A brand-new catalog item from a resolved item (one the app just added). Its own
/// container / phase become the item's DEFAULTS. Nothing contextual comes along
/// (conditions, kit, section, qty, note live on the membership), and it gets a new id.
public func catalogItemFromResolved(_ it: Item) -> Item {
    let src = definedKeys(it)
    // An `undefined` here still OVERRIDES newItem's default in the JS spread — so a
    // missing container reads as '' afterwards, not as the hand luggage.
    var seed: [String: JSONValue] = [
        "container": src["container"] ?? .null,
        "phase": src["phase"] ?? .null,
        "itemType": src["itemType"] ?? .null,
    ]
    for f in INTRINSIC_FIELDS {
        if let v = src[f] { seed[f] = v }
    }
    // A brand-new item has no exception yet, so its own resolved value IS its default.
    for d in DEFAULT_FIELDS {
        if let v = src[d.channel] { seed[d.field] = v }
    }
    return newItem(json: .object(seed))
}

/// Build/refresh the membership for one resolved item in a template: conditions from
/// the item, overrides only where it differs from the catalog default.
/// (JS mutates `existing` and returns it; here the updated copy is returned.)
public func membershipFromResolved(_ cat: Item, _ templateId: String, _ it: Item,
                                   _ order: Double = 0, _ existing: Membership? = nil) -> Membership {
    var m = existing ?? newMembership(itemId: cat.id, templateId: templateId)
    m.templateId = templateId
    m.itemId = cat.id
    m.order = order
    m.seasons = it.seasons
    m.contexts = it.contexts
    m.transports = it.transports
    m.catering = it.catering
    m.weather = it.weather.filter { WEATHER_CONDITION_IDS.contains($0) }
    // The per-list EXCEPTION ('' = follow the template default, then the item's own).
    // When the caller states it outright (`_ovContainer`, set by every resolve) we
    // store it verbatim. Only a freshly-built item that has never been resolved falls
    // back to inferring one — and inference is exactly what used to freeze the item's
    // default forever, so it is now the rare path, not the normal one.
    if let ov = it.ovContainer {
        m.container = ov
    } else {
        // (a link has no container of its own: `undefined` in JS)
        m.container = containerOverrideFor(it.link ? "" : it.container, it.tplContainer ?? "", cat.container)
    }
    m.section = it.section   // purely per-template — always stored, no catalog default
    m.kit = it.kit           // kit name — contextual per template, always stored, no catalog default
    if let ov = it.ovPhase {
        m.phase = ov
    } else {
        m.phase = (!it.link && it.phase != cat.phase) ? it.phase : ""
    }
    m.itemType = it.itemType != cat.itemType ? it.itemType : ""
    m.qty = it.qty
    m.note = it.note
    return coerceMembership(m)
}

// MARK: - Migration engine: fold copy-based lists into the relational shape

/// Count occurrences; INSERTION order is kept so "first wins" on ties.
fileprivate func _tally(_ values: [String]) -> [(key: String, value: Int)] {
    var m = OrderedMap<Int>()
    for v in values { m.set(v, (m.get(v) ?? 0) + 1) }
    return m.entries
}
/// Most frequent value; ties resolve to the first-seen (stable to source order).
fileprivate func _mostCommon(_ values: [String], _ fallback: String) -> String {
    let present = values.filter { !$0.isEmpty }
    if present.isEmpty { return fallback }
    var best = fallback
    var bestN = -1
    for (v, n) in _tally(present) where n > bestN { best = v; bestN = n }
    return best
}
fileprivate func _firstNonEmpty(_ values: [String]) -> String { values.first(where: { !$0.isEmpty }) ?? "" }

/// Merge the N copies of one name into a single canonical catalog item. Intrinsic
/// fields are auto-resolved: text/category by majority (first wins ties), booleans
/// by "true if any copy has it" (the safe superset), weight by first known value.
///
/// 🪤 AS IN THE JS, this does NOT carry `consumable`, `packer`, `stats`, `retired`,
/// `retiredReason`, `keep` or any unknown key: a catalogue rebuilt through here
/// (a replace-restore, a snapshot restore) comes back without them. Reproduced on
/// purpose — the parity checker compares answers — and reported to be decided once.
func buildCatalogItem(_ copies: [Item]) -> Item {
    // v188 (web app): EVERY intrinsic field is merged, by a rule per field, and the
    // thing keeps its identity — before that the rebuild (every replace-restore)
    // silently dropped packer, consumable, "not in use", review history and more.
    func anyTrue(_ f: (Item) -> Bool) -> Bool { copies.contains(where: f) }
    func firstPositive(_ f: (Item) -> Double) -> Double { copies.map(f).first(where: { $0 > 0 }) ?? 0 }
    func firstNonEmpty(_ f: (Item) -> String) -> String { _firstNonEmpty(copies.map(f)) }
    // The most common Swedish wording, ties toward the longest.
    let swedishes = copies.map { jsTrim($0.swedish) }.filter { !$0.isEmpty }
    var swedish = ""
    var bestN = -1
    for (v, n) in _tally(swedishes) where n > bestN || (n == bestN && jsLength(v) > jsLength(swedish)) {
        swedish = v; bestN = n
    }
    let longestSub = copies.map { $0.sub }.stableSorted(compare: { a, b in jsSign(Double(b.count - a.count)) }).first ?? []
    // The copy with the most history speaks — not a sum: the copies are ONE thing
    // resolved several times, not several things.
    var stats = ItemStats()
    var richest = -1
    for c in copies {
        let n = c.stats.packed + c.stats.used + c.stats.unused + c.stats.skipped
        if n > richest { stats = c.stats; richest = n }
    }
    let sharedId = _mostCommon(copies.map { $0.id }, "")
    var cat = newItem(
        id: sharedId.isEmpty ? PackingEnv.makeId() : sharedId,
        name: _mostCommon(copies.map { $0.name }, copies.first?.name ?? ""),
        swedish: swedish,
        category: _mostCommon(copies.map { $0.category }, CATEGORY_DEFAULT),
        container: _mostCommon(copies.map { $0.container }, "Carry-on / hand luggage"),   // the DEFAULT
        phase: _mostCommon(copies.map { $0.phase }, defaultPhaseId()),   // the DEFAULT (any id, known here or not)
        itemType: _mostCommon(copies.map { $0.itemType }, "item"),
        charging: anyTrue { $0.charging },
        chargeType: firstNonEmpty { $0.chargeType },
        shortList: anyTrue { $0.shortList },
        // Conditions (incl. weather), note and qty are contextual → they live on the
        // membership, so the catalog item keeps them empty.
        seasons: [], contexts: [], transports: [], catering: [], weather: [],
        sub: longestSub,
        note: "",
        weight: firstPositive { $0.weight },
        liquid: anyTrue { $0.liquid },
        restricted: anyTrue { $0.restricted },
        perNight: anyTrue { $0.perNight },
        consumable: anyTrue { $0.consumable },
        packer: firstNonEmpty { $0.packer },
        storage: firstNonEmpty { $0.storage },
        photos: copies.map { $0.photos }.first(where: { !$0.isEmpty }) ?? [],
        thumb: firstNonEmpty { $0.thumb },
        maintenance: copies.compactMap { $0.maintenance }.first,
        color: firstNonEmpty { $0.color },
        size: firstNonEmpty { $0.size },
        manufacturer: firstNonEmpty { $0.manufacturer },
        model: firstNonEmpty { $0.model },
        ownedBy: firstNonEmpty { $0.ownedBy },
        acquired: firstNonEmpty { $0.acquired },
        price: firstPositive { $0.price },
        currency: firstNonEmpty { $0.currency },
        purchaseLink: firstNonEmpty { $0.purchaseLink },
        expiry: firstNonEmpty { $0.expiry },
        condition: firstNonEmpty { $0.condition },
        retired: anyTrue { $0.retired },
        retiredReason: firstNonEmpty { $0.retiredReason },
        serial: firstNonEmpty { $0.serial },
        qtyOwned: Int(firstPositive { Double($0.qtyOwned) }),
        warranty: firstNonEmpty { $0.warranty },
        capacityL: firstPositive { $0.capacityL },
        maxKg: firstPositive { $0.maxKg }
    )
    cat.stats = stats
    cat.keep = anyTrue { $0.keep }
    return cat
}

/// Is a per-list exception needed to make this row show `effective`?
///
/// The one place that answers this, so every producer agrees. Container resolves
/// exception → template default → item default, so an exception is only redundant
/// when the fallback chain ALREADY lands on the value we want. Comparing against
/// the item default alone (as this used to) drops the exception on any row whose
/// template carries its own default bag — and the row then silently moves to it.
public func containerOverrideFor(_ effective: String?, _ tplDefault: String?, _ itemDefault: String?) -> String {
    let tpl = tplDefault ?? "", own = itemDefault ?? "", eff = effective ?? ""
    let fallback = !tpl.isEmpty ? tpl : own
    return eff == fallback ? "" : eff
}

/// The membership for one original copy: its conditions, plus overrides only where
/// the copy differs from the canonical item's default (kept sparse on purpose).
/// 🪤 As in the JS, the copy's `kit` is NOT carried.
func membershipFromCopy(_ catItem: Item, _ templateId: String, _ copy: Item, _ tplDefault: String = "") -> Membership {
    newMembership(
        itemId: catItem.id,
        templateId: templateId,
        seasons: copy.seasons,
        contexts: copy.contexts,
        transports: copy.transports,
        catering: copy.catering,
        weather: copy.weather,
        container: containerOverrideFor(copy.container, tplDefault, catItem.container),
        section: copy.section,
        kit: copy.kit,   // per-template kit name — dropped here until v188, so a restore emptied every kit
        phase: copy.phase != catItem.phase ? copy.phase : "",
        itemType: copy.itemType != catItem.itemType ? copy.itemType : "",
        qty: copy.qty,
        note: copy.note
    )
}

/// What `buildCatalog` answers: `{ items, memberships, templates }`.
public struct Catalog: Equatable, Sendable {
    public var items: [Item]
    public var memberships: [Membership]
    /// The same lists minus their inline items.
    public var templates: [PackList]
    public init(items: [Item] = [], memberships: [Membership] = [], templates: [PackList] = []) {
        self.items = items; self.memberships = memberships; self.templates = templates
    }
    public var json: JSONValue {
        ["items": .array(items.map { $0.json }),
         "memberships": .array(memberships.map { $0.json }),
         "templates": .array(templates.map { $0.json })]
    }
}

/// One-time migration: turn today's copy-based building-block lists into the
/// relational shape. Returns { items, memberships, templates } where templates are
/// the same lists minus their inline items (they now reference items via
/// memberships). Same-named items (by normName) are merged into one catalog item.
///
/// Ids are made in the JS order — every item first, then list by list its
/// memberships — so a frozen `PackingEnv` numbers both models alike.
public func buildCatalog(_ lists: [PackList]) -> Catalog {
    var groups = OrderedMap<[Item]>()   // normName -> [copies], insertion-ordered
    for l in lists {
        for it in l.items {
            if jsTrim(it.name).isEmpty { continue }
            let k = normName(it.name)
            groups.set(k, (groups.get(k) ?? []) + [it])
        }
    }
    var items: [Item] = []
    var byName: [String: Item] = [:]   // normName -> catalog item
    var taken = Set<String>()          // ids already given out — two names must never share one
    for (k, copies) in groups.entries {
        var cat = buildCatalogItem(copies)
        if taken.contains(cat.id) { cat.id = PackingEnv.makeId() }
        taken.insert(cat.id)
        items.append(cat)
        byName[k] = cat
    }
    var templates: [PackList] = []
    var memberships: [Membership] = []
    for l in lists {
        var t = l
        t.items = []
        templates.append(coerceList(t))
        var order = 0.0
        for it in l.items {
            if jsTrim(it.name).isEmpty { continue }
            guard let cat = byName[normName(it.name)] else { continue }
            // The template's own default bag is part of how this row will resolve, so it
            // has to be taken into account when deciding whether an exception is needed.
            var m = membershipFromCopy(cat, l.id, it, templateDefaults(l).container)
            m.order = order   // preserve the item's position within its template
            order += 1
            memberships.append(m)
        }
    }
    return Catalog(items: items, memberships: memberships, templates: templates)
}
