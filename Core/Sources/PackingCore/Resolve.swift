// Resolve — the READ path of the relational core: rebuild today's item shape from
// ONE catalogue item plus ONE membership, so the rest of the model (trip building,
// editors, review…) keeps consuming plain lists of items.
// Ported from js/model.js (`resolveMembership` … `resolveTemplate`).
//
// 🪤 The same item can sit on ONE template more than once (with a different "When"),
// and every resolved copy carries the CATALOGUE item's id. Whoever needs to tell the
// rows of a template apart keys them by MEMBERSHIP id, never by item id. The web
// app's store stamps `_itemId` / `_memId` on each resolved item after calling
// `resolveMembership` (db.js `resolveOne`); the functions here do not, exactly as
// the JS ones do not — only `resolveItemAlone` sets them.

import Foundation

/// A template's own defaults, in the shape `resolveMembership` wants
/// (currently just a default container; '' = none).
public struct TemplateDefaults: Equatable, Hashable, Sendable {
    public var container: String
    public init(container: String = "") { self.container = container }
    public var json: JSONValue { ["container": .string(container)] }
}

/// Rebuild a today-shaped item (as a template would hold it) from a catalog item
/// plus one membership: the membership's conditions replace the item's, and any
/// override wins over the item's default. The result is byte-compatible with what
/// the rest of the app already consumes (buildTotalEntries, editors, review…).
/// `tplDefaults` carries the owning template's own defaults (currently just a
/// default container), so a template can say "everything in here goes in the hiking
/// backpack" once instead of on all 84 items.
///
/// Container resolves in three steps, most specific first:
///   1. the per-list EXCEPTION on this membership,
///   2. the TEMPLATE's default container,
///   3. the ITEM's own default — the thing that is true everywhere else.
/// The parts are handed back alongside the answer (`ovContainer` / `tplContainer`
/// / `defContainer`) so the editor can show which one is actually in force, and so
/// a later save can put each part back where it came from.
public func resolveMembership(_ item: Item, _ m: Membership, _ tplDefaults: TemplateDefaults? = nil) -> Item {
    let base = coerceItem(item)
    let mm = coerceMembership(m)
    let tplContainer = tplDefaults?.container ?? ""
    var r = base
    r.seasons = mm.seasons
    r.contexts = mm.contexts
    r.transports = mm.transports
    r.catering = mm.catering
    r.weather = mm.weather
    r.container = !mm.container.isEmpty ? mm.container : (!tplContainer.isEmpty ? tplContainer : base.container)
    r.ovContainer = mm.container      // this list's exception ('' = none)
    r.tplContainer = tplContainer     // the template's default ('' = none)
    r.defContainer = base.container   // the item's own default — true everywhere
    r.section = mm.section            // per-template section id ('' = none); not an item default
    r.kit = mm.kit                    // per-template kit name ('' = none); not an item default
    r.phase = !mm.phase.isEmpty ? mm.phase : base.phase
    r.ovPhase = mm.phase
    r.defPhase = base.phase
    r.itemType = !mm.itemType.isEmpty ? mm.itemType : base.itemType
    r.qty = !mm.qty.isEmpty ? mm.qty : base.qty
    r.note = !mm.note.isEmpty ? mm.note : base.note
    return coerceItem(r)
}

/// An item with NO template behind it, in the shape the editor expects (v175).
///
/// 🚨 WHY THIS EXISTS. An item has always lived once in the catalogue, but every
/// VIEW of one was built by walking the templates — so a thing belonging to no
/// template could not be seen at all, and had to be parked in a fake list called
/// "Loose items". A thing you own does not need a list to exist. This resolves the
/// catalogue item against an EMPTY membership, so the same editor can open it:
/// every per-template answer comes back blank, every answer that belongs to the
/// item itself comes back as its own.
public func resolveItemAlone(_ cat: Item) -> Item {
    var it = resolveMembership(cat, newMembership(itemId: cat.id, templateId: ""))
    it.itemId = cat.id
    it.memId = ""
    return it
}

/// Every resolved item for a template, in membership order. A membership whose item
/// is not in the catalogue is skipped. (A repeated id in `catalog`: the last one wins,
/// as `new Map(…)` has it.)
public func resolveTemplateItems(_ template: PackList, _ catalog: [Item], _ memberships: [Membership]) -> [Item] {
    var itemsById: [String: Item] = [:]
    for i in catalog { itemsById[i.id] = i }
    return resolveTemplateItems(template, itemsById, memberships)
}

/// The form for a caller that already holds the catalogue by id (JS: `catalog instanceof Map`).
public func resolveTemplateItems(_ template: PackList, _ itemsById: [String: Item], _ memberships: [Membership]) -> [Item] {
    func ord(_ m: Membership) -> Double { m.order.isNaN ? 0 : m.order }   // `m.order || 0`
    let mine = memberships
        .filter { $0.templateId == template.id }
        .stableSorted(compare: { a, b in jsSign(ord(a) - ord(b)) })   // preserve item order within the template
    let tplDefaults = templateDefaults(template)
    var out: [Item] = []
    for m in mine {
        guard let item = itemsById[m.itemId] else { continue }
        out.append(resolveMembership(item, m, tplDefaults))
    }
    return out
}

/// A template's own defaults, in the shape resolveMembership wants.
public func templateDefaults(_ list: PackList?) -> TemplateDefaults {
    TemplateDefaults(container: list?.defaultContainer ?? "")
}

/// A template rebuilt into today's list shape (id/name/group/role/… + resolved
/// items) — the bridge that lets existing list-consuming code run unchanged.
public func resolveTemplate(_ template: PackList, _ catalog: [Item], _ memberships: [Membership]) -> PackList {
    var l = template
    l.items = resolveTemplateItems(template, catalog, memberships)
    return coerceList(l)
}
public func resolveTemplate(_ template: PackList, _ itemsById: [String: Item], _ memberships: [Membership]) -> PackList {
    var l = template
    l.items = resolveTemplateItems(template, itemsById, memberships)
    return coerceList(l)
}
