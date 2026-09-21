// Kits — reusable bundles of items always packed together.
// Ported from js/model.js ("Kits").
//
// A kit groups small catalog items you never want to pack separately — a charging
// kit, a wash bag, a first-aid pouch. It references its members by their stable
// catalog id, so a kit stays in sync as items are renamed. Adding a kit (to a
// template or a trip) drops in all its members at once, tagged with the kit's NAME
// so the packing list can cluster them under one "pack the whole kit" header.

import Foundation

public let KIT_DEFAULT_EMOJI = "🧰"

public struct Kit: JSONModel, Hashable, Sendable {
    public var id: String
    public var name: String
    public var emoji: String
    public var note: String
    /// Member catalog-item ids, de-duplicated, order preserved.
    public var itemIds: [String]
    public var createdAt: String
    public var updatedAt: String
    /// Any key this package does not know — kept so nothing is lost on a round trip.
    public var extra: [String: JSONValue]

    /// The defaults are `newKit`'s. NOTE this does not coerce — `newKit(…)` does.
    public init(
        id: String = PackingEnv.makeId(),
        name: String = "",
        emoji: String = "",
        note: String = "",
        itemIds: [String] = [],
        createdAt: String = nowISO(),
        updatedAt: String = nowISO(),
        extra: [String: JSONValue] = [:]
    ) {
        self.id = id; self.name = name; self.emoji = emoji; self.note = note; self.itemIds = itemIds
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.extra = extra
    }

    static let knownKeys: Set<String> = ["id", "name", "emoji", "note", "itemIds", "createdAt", "updatedAt"]

    /// `coerceKit(json)`.
    public init(json: JSONValue) {
        let o = json.objectValue ?? [:]
        self.init(
            id: jsLooseText(o["id"]),
            name: jsStringOr(o["name"]),
            emoji: jsStringOr(o["emoji"]),
            note: jsStringOr(o["note"]),
            itemIds: asArray(o["itemIds"]).compactMap { $0.stringValue },
            createdAt: jsStringOr(o["createdAt"]),
            updatedAt: jsStringOr(o["updatedAt"]),
            extra: extraKeys(o, known: Kit.knownKeys)
        )
        self = coerceKit(self)
    }

    public var json: JSONValue {
        var o = extra
        o["id"] = .string(id); o["name"] = .string(name); o["emoji"] = .string(emoji); o["note"] = .string(note)
        o["itemIds"] = JSONValue(itemIds)
        o["createdAt"] = .string(createdAt); o["updatedAt"] = .string(updatedAt)
        return .object(o)
    }
}

/// The value rules of `coerceKit`, for a kit built in memory.
public func coerceKit(_ kit: Kit) -> Kit {
    var k = kit
    k.emoji = jsTrim(k.emoji)
    var seen = Set<String>()
    k.itemIds = k.itemIds.filter { iid in
        if iid.isEmpty || seen.contains(iid) { return false }
        seen.insert(iid)
        return true
    }
    return k
}
/// `coerceKit(k)` for raw JSON. nil when it is not an object.
public func coerceKit(json k: JSONValue?) -> Kit? {
    guard let k = k, k.objectValue != nil else { return nil }
    return Kit(json: k)
}

/// `newKit({ … })` — the same parameters as `Kit.init`, then `coerceKit`.
public func newKit(
    id: String = PackingEnv.makeId(),
    name: String = "",
    emoji: String = "",
    note: String = "",
    itemIds: [String] = [],
    createdAt: String = nowISO(),
    updatedAt: String = nowISO(),
    extra: [String: JSONValue] = [:]
) -> Kit {
    coerceKit(Kit(id: id, name: name, emoji: emoji, note: note, itemIds: itemIds,
                  createdAt: createdAt, updatedAt: updatedAt, extra: extra))
}
/// `newKit(kit)` — coerce a kit already built with `Kit(…)`.
public func newKit(_ kit: Kit) -> Kit { coerceKit(kit) }
/// `newKit(partial)` for a raw JSON partial, laid over the defaults as the JS spreads it.
public func newKit(json partial: JSONValue) -> Kit {
    var o = Kit().json.objectValue ?? [:]
    for (k, v) in partial.objectValue ?? [:] { o[k] = v }
    return Kit(json: .object(o))
}

/// The glyph shown for a kit on the packing list — its own emoji, or a default.
public func kitEmoji(_ kit: Kit?) -> String {
    let e = jsTrim(kit?.emoji ?? "")
    return e.isEmpty ? KIT_DEFAULT_EMOJI : e
}

/// One group from `clusterByKit`: `kit == ""` means a single loose entry.
public struct KitCluster: Equatable, Sendable {
    public var kit: String
    public var entries: [Item]
    public init(kit: String, entries: [Item]) { self.kit = kit; self.entries = entries }
}

/// Split a flat list of entries into kit clusters + loose entries, preserving the
/// original order: a loose entry stays where it is; the first time a kit is seen,
/// its whole run (every entry in THIS list carrying that kit name) is emitted as one
/// cluster at that position. Used to render "🧰 Charging kit" groups on the packing list.
public func clusterByKit(_ entries: [Item]) -> [KitCluster] {
    var out: [KitCluster] = []
    var done = Set<String>()
    for e in entries {
        let k = jsTrim(e.kit)
        if k.isEmpty { out.append(KitCluster(kit: "", entries: [e])); continue }
        if done.contains(k) { continue }
        done.insert(k)
        out.append(KitCluster(kit: k, entries: entries.filter { jsTrim($0.kit) == k }))
    }
    return out
}
