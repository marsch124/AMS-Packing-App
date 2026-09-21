// Lists — a TEMPLATE (a building-block packing list), its sections and its cover.
// Ported from js/model.js (`normalizeSections`, `coerceList`, `newList`, "Template
// covers", `orderActivities`, `containerNames`).
//
// Called `PackList` because `List` is SwiftUI's; the JS calls it a list throughout.

import Foundation

// MARK: - Sections

/// A template's named, ordered SECTIONS — logical groupings the user defines per
/// template (e.g. a Diving list's "Lights", "Rig", "Regulators"). Each item's
/// membership stores which section id it belongs to.
public struct TemplateSection: JSONModel, Hashable, Sendable {
    public var id: String
    public var name: String
    public init(id: String = PackingEnv.makeId(), name: String = "") { self.id = id; self.name = name }
    /// Type rules only — `normalizeSections` is what drops the unnamed and gives ids.
    public init(json: JSONValue) {
        self.id = jsStringOr(json["id"])
        self.name = jsStringOr(json["name"])
    }
    public var json: JSONValue { ["id": .string(id), "name": .string(name)] }
}

/// Unnamed entries are dropped, a missing id is made up, a repeated id is dropped.
public func normalizeSections(_ arr: [TemplateSection]) -> [TemplateSection] {
    var seen = Set<String>()
    var out: [TemplateSection] = []
    for s in arr {
        let sid = s.id.isEmpty ? PackingEnv.makeId() : s.id
        let name = jsTrim(s.name)
        if name.isEmpty || seen.contains(sid) { continue }
        seen.insert(sid)
        out.append(TemplateSection(id: sid, name: name))
    }
    return out
}
/// `normalizeSections(arr)` for raw JSON.
public func normalizeSections(json arr: JSONValue?) -> [TemplateSection] {
    normalizeSections(asArray(arr).map { TemplateSection(json: $0) })
}
public func newSection(_ name: String = "") -> TemplateSection {
    TemplateSection(id: PackingEnv.makeId(), name: jsTrim(name))
}

// MARK: - PackList

public struct PackList: JSONModel, Hashable, Sendable {
    public var id: String
    public var name: String
    /// Cover glyph ('' = default 📋).
    public var emoji: String
    /// Cover colour ('' = a stable hashed pick from TEMPLATE_COLORS).
    public var color: String
    /// Ordered per-template groupings; [] = ungrouped list.
    public var sections: [TemplateSection]
    /// 'GA' | 'WET' | 'OE' | '' (ungrouped / utility list)
    public var group: String
    /// How the list feeds a trip:
    ///  'base'      → always included on every trip (the common core),
    ///  'transport' → included only when the trip's transport matches `transport`,
    ///  'loose'     → the retired "Loose items" bin; never fed to a trip,
    ///  'container' → the "Containers" catalogue: the bags themselves; never fed to a trip,
    ///  ''          → a normal activity list the user ticks (GA / WET).
    public var role: String
    /// '' | 'Car' | 'Plane' | 'RV' — only meaningful when role == 'transport'.
    public var transport: String
    /// One container for everything in this template ('' = none, items decide for
    /// themselves). It sits BETWEEN the item's own default and the per-list exception.
    public var defaultContainer: String
    /// Shipped with the app (the starter templates, the Containers catalogue).
    public var builtin: Bool
    /// RESOLVED items (in a backup and in everything the rest of the model consumes).
    public var items: [Item]
    public var createdAt: String
    public var updatedAt: String
    /// Any key this package does not know — kept so nothing is lost on a round trip.
    public var extra: [String: JSONValue]

    /// The defaults are `newList`'s. NOTE this does not coerce — `newList(…)` does.
    public init(
        id: String = PackingEnv.makeId(),
        name: String = "",
        emoji: String = "",
        color: String = "",
        sections: [TemplateSection] = [],
        group: String = "",
        role: String = "",
        transport: String = "",
        defaultContainer: String = "",
        builtin: Bool = false,
        items: [Item] = [],
        createdAt: String = nowISO(),
        updatedAt: String = nowISO(),
        extra: [String: JSONValue] = [:]
    ) {
        self.id = id; self.name = name; self.emoji = emoji; self.color = color; self.sections = sections
        self.group = group; self.role = role; self.transport = transport
        self.defaultContainer = defaultContainer; self.builtin = builtin; self.items = items
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.extra = extra
    }

    static let knownKeys: Set<String> = [
        "id", "name", "emoji", "color", "sections", "group", "role", "transport",
        "defaultContainer", "builtin", "items", "createdAt", "updatedAt",
    ]

    /// `coerceList(json)`.
    public init(json: JSONValue) {
        let o = json.objectValue ?? [:]
        self.init(
            id: jsLooseText(o["id"]),
            name: jsLooseText(o["name"]),
            emoji: jsStringOr(o["emoji"]),
            color: jsStringOr(o["color"]),
            sections: asArray(o["sections"]).map { TemplateSection(json: $0) },
            group: jsStringOr(o["group"]),
            role: jsStringOr(o["role"]),
            transport: jsStringOr(o["transport"]),
            defaultContainer: jsStringOr(o["defaultContainer"]),
            builtin: jsTruthy(o["builtin"]),
            items: coerceItems(json: o["items"]),
            createdAt: jsStringOr(o["createdAt"]),
            updatedAt: jsStringOr(o["updatedAt"]),
            extra: extraKeys(o, known: PackList.knownKeys)
        )
        self = coerceList(self)
    }

    public var json: JSONValue {
        var o = extra
        o["id"] = .string(id); o["name"] = .string(name); o["emoji"] = .string(emoji); o["color"] = .string(color)
        o["sections"] = .array(sections.map { $0.json })
        o["group"] = .string(group); o["role"] = .string(role); o["transport"] = .string(transport)
        o["defaultContainer"] = .string(defaultContainer); o["builtin"] = .bool(builtin)
        o["items"] = .array(items.map { $0.json })
        o["createdAt"] = .string(createdAt); o["updatedAt"] = .string(updatedAt)
        return .object(o)
    }
}

/// The value rules of `coerceList`, for a list built in memory.
public func coerceList(_ list: PackList) -> PackList {
    var l = list
    l.items = l.items.map { coerceItem($0) }
    l.sections = normalizeSections(l.sections)                 // ordered per-template groupings ([] = none)
    l.group = GROUP_IDS.contains(l.group) ? l.group : ""        // '' = ungrouped / utility list
    l.role = ["base", "transport", "loose", "container"].contains(l.role) ? l.role : ""
    l.transport = TRANSPORTS.contains(l.transport) ? l.transport : ""
    // Cover: an optional emoji + colour. Both '' = fall back to the default glyph /
    // a stable hashed colour, so an un-customised template still looks distinct.
    let e = jsTrim(l.emoji)
    l.emoji = e.isEmpty ? "" : jsSlice(e, 0, 4)
    l.color = isHexColor(l.color) ? l.color : ""
    return l
}
/// `coerceList(l)` for raw JSON. nil when it is not an object.
public func coerceList(json l: JSONValue?) -> PackList? {
    guard let l = l, l.objectValue != nil else { return nil }
    return PackList(json: l)
}

/// `newList({ … })` — the same parameters as `PackList.init`, then `coerceList`.
public func newList(
    id: String = PackingEnv.makeId(),
    name: String = "",
    emoji: String = "",
    color: String = "",
    sections: [TemplateSection] = [],
    group: String = "",
    role: String = "",
    transport: String = "",
    defaultContainer: String = "",
    builtin: Bool = false,
    items: [Item] = [],
    createdAt: String = nowISO(),
    updatedAt: String = nowISO(),
    extra: [String: JSONValue] = [:]
) -> PackList {
    coerceList(PackList(id: id, name: name, emoji: emoji, color: color, sections: sections, group: group,
                        role: role, transport: transport, defaultContainer: defaultContainer,
                        builtin: builtin, items: items, createdAt: createdAt, updatedAt: updatedAt, extra: extra))
}
/// `newList(list)` — coerce a list already built with `PackList(…)`.
public func newList(_ list: PackList) -> PackList { coerceList(list) }
/// `newList(partial)` for a raw JSON partial, laid over the defaults as the JS spreads it.
public func newList(json partial: JSONValue) -> PackList {
    var o = PackList().json.objectValue ?? [:]
    for (k, v) in partial.objectValue ?? [:] { o[k] = v }
    return PackList(json: .object(o))
}

// MARK: - Template covers

public func listEmoji(_ list: PackList?) -> String {
    let e = jsTrim(list?.emoji ?? "")
    return e.isEmpty ? TEMPLATE_DEFAULT_EMOJI : e
}

/// The cover colour for a template: its own colour if set, else a stable hashed
/// pick from the palette keyed on the template id (falls back to the name), so
/// every template reads as a distinct colour before anyone customises it.
public func listColor(_ list: PackList?) -> String {
    if let c = list?.color, isHexColor(c) { return c }
    let key = (list?.id.isEmpty == false) ? (list?.id ?? "") : (list?.name ?? "")
    return TEMPLATE_COLORS[Int(jsHash31(key) % UInt32(TEMPLATE_COLORS.count))]
}

/// `for (…) hsh = (hsh * 31 + key.charCodeAt(i)) >>> 0` — over UTF-16 units, wrapping
/// at 32 bits. Shared by `listColor` and `personColor`.
public func jsHash31(_ key: String) -> UInt32 {
    var h: UInt32 = 0
    for u in key.utf16 { h = h &* 31 &+ UInt32(u) }
    return h
}

// MARK: - Ordering activities, container names

/// The order activities are offered in inside a group (see ACTIVITY_ORDER): the named
/// ones first, in that order; anything else after them, alphabetically.
public func orderActivities(_ groupId: String?, _ lists: [PackList]) -> [PackList] {
    guard let wanted = ACTIVITY_ORDER[groupId ?? ""] else { return lists }
    var rank: [String: Int] = [:]
    for (i, n) in wanted.enumerated() { rank[normName(n)] = i }
    func at(_ l: PackList) -> Int { rank[normName(l.name)] ?? Int.max }
    return lists.stableSorted(compare: { a, b in
        let ra = at(a), rb = at(b)
        if ra != rb { return ra < rb ? -1 : 1 }
        return jsLocaleCompare(a.name, b.name)
    })
}

/// The names offered in an item's "Container" (where it's packed) dropdown: the
/// hardcoded defaults MERGED with any real container records the user has created
/// (so a newly-added "Osprey 40" bag shows up as a packing destination too), in a
/// stable order — defaults first, then extra container names, de-duplicated.
public func containerNames(_ lists: [PackList] = []) -> [String] {
    var seen = Set(CONTAINERS.map { $0.lowercased() })
    var extra: [String] = []
    for l in lists where l.role == CONTAINER_ROLE {
        for it in l.items {
            let n = jsTrim(it.name)
            if !n.isEmpty && !seen.contains(n.lowercased()) { seen.insert(n.lowercased()); extra.append(n) }
        }
    }
    return CONTAINERS + extra
}
