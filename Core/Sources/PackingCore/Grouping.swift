// Grouping — a trip's entries grouped for display / export (by When, Where, What,
// section, storage place), and the generic sort & group helpers behind the Care
// tab's "All items" index.
// Ported from js/model.js ("Grouping for display / export", "Generic sort & group helpers").
//
// Where the JS builds a Map and spreads it, the groups here come back as an ARRAY in
// the Map's insertion order (first appearance), then sorted exactly as the JS sorts.

import Foundation

// MARK: - Result shapes

/// `{ phase, entries }` — one group from `entriesByPhase`.
public struct PhaseGroup: Equatable, Sendable {
    public var phase: Phase
    public var entries: [Item]
    public init(phase: Phase, entries: [Item]) { self.phase = phase; self.entries = entries }
    public var json: JSONValue { ["phase": phase.json, "entries": .array(entries.map { $0.json })] }
}
/// `{ container, entries }` — one group from `groupByContainer`.
public struct ContainerGroup: Equatable, Sendable {
    public var container: String
    public var entries: [Item]
    public init(container: String, entries: [Item]) { self.container = container; self.entries = entries }
    public var json: JSONValue { ["container": .string(container), "entries": .array(entries.map { $0.json })] }
}
/// `{ category, entries }` — one group from `groupByCategory`.
public struct CategoryGroup: Equatable, Sendable {
    public var category: String
    public var entries: [Item]
    public init(category: String, entries: [Item]) { self.category = category; self.entries = entries }
    public var json: JSONValue { ["category": .string(category), "entries": .array(entries.map { $0.json })] }
}
/// `{ section, items }` — one group from `groupItemsBySection`. `section == nil` is
/// the trailing bucket of unsectioned items (JS `section: null`).
public struct SectionItemsGroup: Equatable, Sendable {
    public var section: TemplateSection?
    public var items: [Item]
    public init(section: TemplateSection?, items: [Item]) { self.section = section; self.items = items }
    public var json: JSONValue { ["section": section?.json ?? .null, "items": .array(items.map { $0.json })] }
}
/// `{ label, entries }` (and `hint`, only when grouped by When) — what `groupBy`,
/// `groupBySection` and `groupByStorage` return. `hint == nil` is JS `undefined`.
public struct EntryGroup: Equatable, Sendable {
    public var label: String
    public var hint: String?
    public var entries: [Item]
    public init(label: String, hint: String? = nil, entries: [Item]) {
        self.label = label; self.hint = hint; self.entries = entries
    }
    public var json: JSONValue {
        var o: [String: JSONValue] = ["label": .string(label), "entries": .array(entries.map { $0.json })]
        if let h = hint { o["hint"] = .string(h) }
        return .object(o)
    }
}
/// `{ key, label, rows }` — one bucket from `groupRowsBy`.
public struct RowGroup<Row> {
    public var key: String
    public var label: String
    public var rows: [Row]
    public init(key: String, label: String, rows: [Row]) { self.key = key; self.label = label; self.rows = rows }
}
extension RowGroup: Equatable where Row: Equatable {}
extension RowGroup: Sendable where Row: Sendable {}

// MARK: - By phase

/// Group a trip's entries by phase, in timeline order.
///
/// An entry whose phase this device doesn't recognise — set on the other device, or
/// on a phase since removed — gets its OWN group at the end rather than being
/// dropped into "≥1 week ahead". Before phases were editable that fallback was
/// harmless; now it would quietly move things you had filed somewhere else.
public func entriesByPhase(_ entries: [Item]) -> [PhaseGroup] {
    var known: [String: [Item]] = [:]
    for p in PHASES { known[p.id] = [] }
    var strays: [(id: String, entries: [Item])] = []            // unknown phase id → entries, first-seen order
    for e in entries {
        if known[e.phase] != nil { known[e.phase]?.append(e); continue }
        if let i = strays.firstIndex(where: { $0.id == e.phase }) { strays[i].entries.append(e) }
        else { strays.append((id: e.phase, entries: [e])) }
    }
    let knownGroups = PHASES
        .map { PhaseGroup(phase: $0, entries: known[$0.id] ?? []) }
        .filter { !$0.entries.isEmpty }
    let unknown = strays.map { PhaseGroup(phase: phaseOrFallback($0.id), entries: $0.entries) }
    return knownGroups + unknown
}

// MARK: - By container / category

// (Not exported by the JS module, so not public here either.)
// Keys named in `order` come first, in that order; every other key shares rank 999
// and settles by `localeCompare`.
func groupByKey(_ entries: [Item], _ keyFn: (Item) -> String, _ order: [String], _ fallback: String)
    -> [(key: String, entries: [Item])] {
    var groups: [(key: String, entries: [Item])] = []
    for e in entries {
        let raw = keyFn(e)
        let k = raw.isEmpty ? fallback : raw
        if let i = groups.firstIndex(where: { $0.key == k }) { groups[i].entries.append(e) }
        else { groups.append((key: k, entries: [e])) }
    }
    var ord: [String: Int] = [:]
    for (i, c) in order.enumerated() { ord[c] = i }              // a repeated name: the last index wins
    return groups.stableSorted(compare: { a, b in
        jsOr(jsSign(Double((ord[a.key] ?? 999) - (ord[b.key] ?? 999))), jsLocaleCompare(a.key, b.key))
    })
}
public func groupByContainer(_ entries: [Item]) -> [ContainerGroup] {
    groupByKey(entries, { $0.container }, CONTAINERS, "Other").map { ContainerGroup(container: $0.key, entries: $0.entries) }
}
public func groupByCategory(_ entries: [Item]) -> [CategoryGroup] {
    groupByKey(entries, { $0.category }, CATEGORIES, CATEGORY_DEFAULT).map { CategoryGroup(category: $0.key, entries: $0.entries) }
}

// MARK: - A template's items by section

/// Group a template's RESOLVED items by their section id, in the template's own
/// section order, with any unsectioned items in a trailing bucket (section: nil).
/// Empty defined sections are omitted so the list stays tidy. An item whose section
/// id belongs to ANOTHER template falls into the trailing bucket rather than vanishing.
/// Used by the template overview screen.
public func groupItemsBySection(_ items: [Item], _ sections: [TemplateSection]) -> [SectionItemsGroup] {
    var buckets: [String: [Item]] = [:]
    for s in sections { buckets[s.id] = [] }
    var loose: [Item] = []
    for it in items {
        if !it.section.isEmpty, buckets[it.section] != nil { buckets[it.section]?.append(it) } else { loose.append(it) }
    }
    // Walks `sections`, not the buckets — so a section id defined twice is shown
    // twice with the same items, as in JS.
    var out = sections
        .filter { !(buckets[$0.id] ?? []).isEmpty }
        .map { SectionItemsGroup(section: $0, items: buckets[$0.id] ?? []) }
    if !loose.isEmpty { out.append(SectionItemsGroup(section: nil, items: loose)) }
    return out
}

// MARK: - Generic sort & group helpers for browsable catalogues
// Used by the Care tab's "All items" index (and available to any other list that
// grows big enough to need ordering). Both are pure: they take rows plus a
// function that pulls the value out of a row.

/// Sort rows by one field. `valOf(row)` returns the comparable value (nil = undefined).
///   dir  "asc" | "desc"
///   num  compare arithmetically (0 counts as "not recorded")
///   tie  optional comparator for equal values — never flipped, so ties always
///        settle the same friendly way (A–Z by name) in both directions.
/// BLANKS ALWAYS SINK. A sort is for finding the things you HAVE recorded; if
/// "Manufacturer, Z–A" led with 300 items that have no maker, the sort would be
/// useless in one of its two directions.
public func sortRowsBy<Row>(_ rows: [Row], _ valOf: (Row) -> JSONValue?, dir: String = "asc", num: Bool = false,
                            tie: ((Row, Row) -> Int)? = nil) -> [Row] {
    func isBlank(_ v: JSONValue?) -> Bool {
        num ? !(jsNumber(v) > 0) : jsTrim(jsStringNullish(v)).isEmpty
    }
    let flip = dir == "desc" ? -1 : 1
    return rows.stableSorted(compare: { a, b in
        let av = valOf(a), bv = valOf(b)
        let ab = isBlank(av), bb = isBlank(bv)
        if ab != bb { return ab ? 1 : -1 }
        if ab && bb { return tie?(a, b) ?? 0 }
        let c = num
            ? jsSign(jsNumber(av) - jsNumber(bv))
            : jsLocaleCompare(jsStringNullish(av), jsStringNullish(bv), sensitivity: .base)
        if c == 0 { return tie?(a, b) ?? 0 }
        return c * flip
    })
}
/// `sortRowsBy` for a field that is text (`r.it.name || ''`).
public func sortRowsBy<Row>(_ rows: [Row], _ valOf: (Row) -> String, dir: String = "asc", num: Bool = false,
                            tie: ((Row, Row) -> Int)? = nil) -> [Row] {
    sortRowsBy(rows, { (r: Row) -> JSONValue? in .string(valOf(r)) }, dir: dir, num: num, tie: tie)
}
/// `sortRowsBy` for a field that is a number (`r.it.weight || 0`) — pass `num: true`
/// to compare arithmetically, as the JS caller does.
public func sortRowsBy<Row>(_ rows: [Row], _ valOf: (Row) -> Double, dir: String = "asc", num: Bool = false,
                            tie: ((Row, Row) -> Int)? = nil) -> [Row] {
    sortRowsBy(rows, { (r: Row) -> JSONValue? in .number(valOf(r)) }, dir: dir, num: num, tie: tie)
}

/// Bucket rows for readability. `keyOf(row)` returns the bucket's name ('' or nil =
/// not set). Buckets named in `order` come first in that order, the rest follow
/// alphabetically, and the "not set" bucket is ALWAYS last — it teaches nothing,
/// so it should never head the page. Row order within a bucket is preserved, so
/// the chosen sort still applies inside each group.
public func groupRowsBy<Row>(_ rows: [Row], _ keyOf: (Row) -> String?, order: [String] = [],
                             emptyLabel: String = "Not set") -> [RowGroup<Row>] {
    var buckets: [(key: String, rows: [Row])] = []
    for r in rows {
        let k = jsTrim(keyOf(r) ?? "")
        if let i = buckets.firstIndex(where: { $0.key == k }) { buckets[i].rows.append(r) }
        else { buckets.append((key: k, rows: [r])) }
    }
    var rank: [String: Int] = [:]
    for (i, o) in order.enumerated() { rank[o.lowercased()] = i }   // a repeated name: the last index wins
    // Number.MAX_SAFE_INTEGER for a bucket `order` does not name.
    func rankOf(_ k: String) -> Int { rank[k.lowercased()] ?? 9_007_199_254_740_991 }
    let sorted = buckets.stableSorted(compare: { a, b in
        if a.key.isEmpty != b.key.isEmpty { return a.key.isEmpty ? 1 : -1 }   // the empty bucket last
        let ra = rankOf(a.key), rb = rankOf(b.key)
        if ra != rb { return ra < rb ? -1 : 1 }
        return jsLocaleCompare(a.key, b.key, sensitivity: .base)
    })
    return sorted.map { RowGroup(key: $0.key, label: $0.key.isEmpty ? emptyLabel : $0.key, rows: $0.rows) }
}

// MARK: - By section name / storage place

/// Group trip ENTRIES by their section NAME (first-appearance order), with the
/// unsectioned remainder in a trailing "Everything else" group. Entries carry a
/// resolved section name, so same-named sections from different templates merge.
public func groupBySection(_ entries: [Item]) -> [EntryGroup] {
    var groups: [EntryGroup] = []                                // name -> entries, in first-seen order
    var loose: [Item] = []
    for e in entries {
        let name = jsTrim(e.section)
        if name.isEmpty { loose.append(e); continue }
        if let i = groups.firstIndex(where: { $0.label == name }) { groups[i].entries.append(e) }
        else { groups.append(EntryGroup(label: name, entries: [e])) }
    }
    if !loose.isEmpty { groups.append(EntryGroup(label: "Everything else", entries: loose)) }
    return groups
}

/// Group entries by WHERE the item is stored at home (its `storage` free-text),
/// alphabetically, with anything without a place set gathered in a trailing group.
/// Lets you round up "everything from the garage" when packing.
public func groupByStorage(_ entries: [Item]) -> [EntryGroup] {
    var groups: [EntryGroup] = []
    var none: [Item] = []
    for e in entries {
        let s = jsTrim(e.storage)
        if s.isEmpty { none.append(e); continue }
        if let i = groups.firstIndex(where: { $0.label == s }) { groups[i].entries.append(e) }
        else { groups.append(EntryGroup(label: s, entries: [e])) }
    }
    var out = groups.stableSorted(compare: { a, b in jsLocaleCompare(a.label, b.label) })
    if !none.isEmpty { out.append(EntryGroup(label: "No place set", entries: none)) }
    return out
}

/// Generic dispatcher used by the UI's group-by toggle:
/// 'category' | 'container' | 'section' | 'stored' | anything else = 'when'.
public func groupBy(_ mode: String, _ entries: [Item]) -> [EntryGroup] {
    if mode == "category" { return groupByCategory(entries).map { EntryGroup(label: $0.category, entries: $0.entries) } }
    if mode == "container" {
        return groupByContainer(entries).map { EntryGroup(label: $0.container.isEmpty ? "Unpacked" : $0.container, entries: $0.entries) }
    }
    if mode == "section" { return groupBySection(entries) }
    if mode == "stored" { return groupByStorage(entries) }
    return entriesByPhase(entries).map { EntryGroup(label: $0.phase.label, hint: $0.phase.hint, entries: $0.entries) }
}
