// CatalogRows — the DATABASE OVERVIEW ("maintenance mode"): one line per real item
// across all templates, with duplicate surfacing — and the flat rows of a trip's
// Total List for a spreadsheet export.
// Ported from js/model.js ("DATABASE OVERVIEW", `totalListRows`).

import Foundation

// MARK: - One line per catalogue item

/// One template a row's item belongs to.
public struct CatalogRowTemplate: Equatable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var role: String
    public init(id: String = "", name: String = "", role: String = "") { self.id = id; self.name = name; self.role = role }
    public var json: JSONValue { ["id": .string(id), "name": .string(name), "role": .string(role)] }
}

/// One line of the overview: `{ id, name, item, templates }`. `id` is the catalogue
/// item's id — or `name:<normName>` for an item that has none.
public struct CatalogRow: Equatable, Sendable {
    public var id: String
    public var name: String
    /// The first resolved copy met (or the catalogue item, for a thing on no list).
    public var item: Item
    /// Every template it belongs to, in the order met; [] = on no list at all.
    public var templates: [CatalogRowTemplate]
    public init(id: String, name: String, item: Item, templates: [CatalogRowTemplate] = []) {
        self.id = id; self.name = name; self.item = item; self.templates = templates
    }
    public var json: JSONValue {
        ["id": .string(id), "name": .string(name), "item": item.json, "templates": .array(templates.map { $0.json })]
    }
}

/// One row per unique catalog item, gathered from the RESOLVED lists. Because a
/// catalog item keeps the SAME id wherever it is resolved, deduping by id collapses
/// the copies a single item shows as across its templates into one line, and gathers
/// every template it belongs to (list id, name and role). Rows are name-sorted.
public func catalogRows(_ lists: [PackList], _ catalog: [Item] = []) -> [CatalogRow] {
    var order: [String] = []               // a JS Map: insertion order
    var byId: [String: CatalogRow] = [:]
    func key(_ it: Item) -> String { it.id.isEmpty ? "name:\(normName(it.name))" : it.id }
    for l in lists {
        for it in l.items {
            if jsTrim(it.name).isEmpty { continue }
            let k = key(it)
            if byId[k] == nil {
                order.append(k)
                byId[k] = CatalogRow(id: k, name: it.name, item: it)
            }
            if byId[k]?.templates.contains(where: { $0.id == l.id }) == false {
                byId[k]?.templates.append(CatalogRowTemplate(id: l.id, name: l.name, role: l.role))
            }
        }
    }
    // (v177) Things on NO template at all. Since the "Loose items" bin was retired
    // they are an ordinary state, not an orphan — and this view claims to show every
    // item — so the catalogue is folded in, each with an empty `templates`.
    for it in catalog {
        if jsTrim(it.name).isEmpty { continue }
        let k = key(it)
        if byId[k] != nil { continue }
        order.append(k)
        byId[k] = CatalogRow(id: k, name: it.name, item: it)
    }
    return order.compactMap { byId[$0] }
        .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
}

// MARK: - Probable duplicates

/// `\p{L}` or `\p{N}` — on a CODE POINT, as the JS regex (flag `u`) sees it. A
/// combining accent is a Mark, so it is neither.
fileprivate func isLetterOrNumber(_ u: Unicode.Scalar) -> Bool {
    switch u.properties.generalCategory {
    case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
         .decimalNumber, .letterNumber, .otherNumber:
        return true
    default:
        return false
    }
}

/// A loose, forgiving key for spotting probable duplicates: normalised name with
/// punctuation dropped, words naively singularised (a trailing -s, but not -ss),
/// and spaces removed — so "Sunglasses", "Sun glasses" and "sunglass" all collapse
/// to one key. Deliberately generous: this only SURFACES pairs for a human to judge,
/// it never merges anything on its own.
///
/// `normName(name).replace(/[^\p{L}\p{N} ]+/gu, ' ').replace(/\s+/g, ' ').trim()`,
/// then per word `w.length > 3 && w.endsWith('s') && !w.endsWith('ss') ? w.slice(0, -1) : w`.
public func dupeKey(_ name: String?) -> String {
    var cleaned = String.UnicodeScalarView()
    for u in normName(name).unicodeScalars {
        cleaned.append((isLetterOrNumber(u) || u == " ") ? u : " ")
    }
    let base = jsTrim(jsCollapseWhitespace(String(cleaned)))
    if base.isEmpty { return "" }
    var out = String.UnicodeScalarView()
    for word in base.unicodeScalars.split(separator: " ", omittingEmptySubsequences: false) {
        var w = Array(word)
        let units = w.reduce(0) { $0 + ($1.value > 0xFFFF ? 2 : 1) }   // `w.length` counts UTF-16 units
        if units > 3, w.count >= 2, w[w.count - 1] == "s", w[w.count - 2] != "s" { w.removeLast() }
        out.append(contentsOf: w)
    }
    return String(out)
}

/// One group of look-alike rows: `{ key, exact, rows }`.
public struct DuplicateGroup: Equatable, Sendable {
    public var key: String
    /// Every member has the identical normalised name (a true stored duplicate).
    public var exact: Bool
    public var rows: [CatalogRow]
    public init(key: String, exact: Bool, rows: [CatalogRow]) { self.key = key; self.exact = exact; self.rows = rows }
    public var json: JSONValue { ["key": .string(key), "exact": .bool(exact), "rows": .array(rows.map { $0.json })] }
}

/// Groups of overview rows that look like duplicates of each other (2+ distinct
/// catalog items sharing a dupeKey). `exact` marks a group whose members share an
/// identical normalised name (a true stored duplicate) as opposed to a near-match.
/// Groups are name-sorted for a stable display order.
public func duplicateGroups(_ rows: [CatalogRow]) -> [DuplicateGroup] {
    var order: [String] = []               // a JS Map: insertion order
    var map: [String: [CatalogRow]] = [:]
    for r in rows {
        let k = dupeKey(r.name)
        if k.isEmpty { continue }
        if map[k] == nil { order.append(k) }
        map[k, default: []].append(r)
    }
    var out: [DuplicateGroup] = []
    for k in order {
        guard let group = map[k], group.count >= 2 else { continue }
        let names = Set(group.map { normName($0.name) })
        out.append(DuplicateGroup(key: k, exact: names.count == 1, rows: group))
    }
    return out.stableSorted(compare: { a, b in
        jsLocaleCompare(a.rows.first?.name ?? "", b.rows.first?.name ?? "", sensitivity: .base)
    })
}

/// The row ids caught in any duplicate group — lets the table highlight them.
/// A Set in JS; here the ids in the Set's INSERTION order, each once.
public func duplicateIds(_ rows: [CatalogRow]) -> [String] {
    var seen = Set<String>()
    var ids: [String] = []
    for g in duplicateGroups(rows) {
        for r in g.rows where !seen.contains(r.id) {
            seen.insert(r.id)
            ids.append(r.id)
        }
    }
    return ids
}

// MARK: - Spreadsheet rows

/// One row of the flat spreadsheet export. The field names ARE the column headings,
/// capitals and all, exactly as the JS object has them.
public struct TotalListRow: Equatable, Hashable, Sendable {
    public var Phase: String
    public var Container: String
    public var Item: String
    public var Qty: String
    /// 'yes' | ''
    public var Packed: String
    public var Note: String
    public init(Phase: String = "", Container: String = "", Item: String = "", Qty: String = "",
                Packed: String = "", Note: String = "") {
        self.Phase = Phase; self.Container = Container; self.Item = Item
        self.Qty = Qty; self.Packed = Packed; self.Note = Note
    }
    public var json: JSONValue {
        ["Phase": .string(Phase), "Container": .string(Container), "Item": .string(Item),
         "Qty": .string(Qty), "Packed": .string(Packed), "Note": .string(Note)]
    }
}

/// Rows for a flat spreadsheet export: one row per Total-List entry, in
/// timeline -> container order. (`lists` is unused, as in the JS.)
public func totalListRows(_ event: TripEvent, _ lists: [PackList]? = nil) -> [TotalListRow] {
    _ = lists
    var rows: [TotalListRow] = []
    for g in entriesByPhase(event.entries) {
        for cg in groupByContainer(g.entries) {
            for e in cg.entries {
                rows.append(TotalListRow(
                    Phase: g.phase.label,
                    Container: e.container,
                    Item: e.name,
                    Qty: e.qty,
                    Packed: e.checked ? "yes" : "",
                    Note: e.note
                ))
            }
        }
    }
    return rows
}

