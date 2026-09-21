// Shapes — the fixed key sets every entity is written down with (QUESTIONS.md §3,
// §5 of js-answers.mjs).
//
// They work on the JSON form of a model value (`item.json`…), key by key, exactly as
// the JS shapes read a JS object: `o[k] = it[k]`, `str(it[k])`, `!!it[k]`. A key the
// typed model leaves out of its JSON when false / nil (`checked`, `_ovContainer`…) is
// JS `undefined` there too, so the same three rules give the same answer.

import Foundation
import PackingCore

let ITEM_NORMALISED = [
    "seasons", "contexts", "transports", "catering", "weather", "sub", "phase", "category", "itemType",
    "charging", "chargeType", "shortList", "swedish", "stats", "weight", "liquid", "restricted", "perNight",
    "consumable", "section", "kit", "packer", "storage", "photos", "thumb", "maintenance", "color", "size",
    "manufacturer", "model", "ownedBy", "acquired", "price", "currency", "purchaseLink", "expiry", "condition",
    "retired", "retiredReason", "serial", "qtyOwned", "warranty", "capacityL", "maxKg",
]
let ITEM_STRINGS = ["id", "name", "qty", "container", "note", "sourceListId", "sourceItemId"]
let ITEM_BOOLS = ["custom", "checked", "skipped", "_edited", "keep"]
let ITEM_OPT_BOOL = ["used"]
let ITEM_OPT_STR = ["_ovContainer", "_tplContainer", "_defContainer", "_ovPhase", "_defPhase", "_itemId", "_memId"]
let ITEM_KEYS = Set(ITEM_NORMALISED + ITEM_STRINGS + ITEM_BOOLS + ITEM_OPT_BOOL + ITEM_OPT_STR)

let LIST_KEYS: Set<String> = ["id", "name", "emoji", "color", "sections", "group", "role", "transport",
                              "defaultContainer", "builtin", "createdAt", "updatedAt", "items"]
let EVENT_KEYS: Set<String> = ["id", "name", "mode", "activities", "transport", "season", "contexts", "weatherOn",
                               "catering", "startDate", "endDate", "nights", "laundry", "destination", "weather",
                               "geo", "entries", "status", "reviewedAt", "generatedAt", "createdAt", "updatedAt"]
let ACTION_KEYS: Set<String> = ["id", "text", "kind", "itemId", "itemName", "priority", "whenPhase", "whenDate",
                                "done", "doneAt", "createdAt", "updatedAt"]
let KIT_KEYS: Set<String> = ["id", "name", "emoji", "note", "itemIds", "createdAt", "updatedAt"]
let PHASE_KEYS: Set<String> = ["id", "label", "hint", "emoji", "color", "task", "leadDays", "order"]

/// How minted ids and stamps are written down (D3, D4). nil = leave as it is.
struct ShapeMap {
    var id: ((String) -> String)? = nil          // an item's `id` and `_itemId`; a membership's `itemId`
    var mem: ((String) -> String)? = nil         // `_memId`; a membership's `id`
    var section: ((String) -> String)? = nil     // an item's `section`
    var sectionId: ((String) -> String)? = nil   // a list section's `id`
    var listId: ((String) -> String)? = nil
    var dropId = false
    var stamps = false                           // a list's createdAt / updatedAt → "<now>"
}

// A sub-item is a NAME — a string — and is written as it stands. (Contract 1 put a
// taken-apart name back together here; since model v186 the model does that itself.)
func shapeItem(_ it: J?, _ map: ShapeMap = ShapeMap()) -> J {
    guard let it = it, it.objectValue != nil else { return it ?? .null }
    var o: [String: J] = [:]
    for k in ITEM_NORMALISED { if let v = it[k] { o[k] = v } }
    for k in ITEM_STRINGS { o[k] = .string(str(it[k])) }
    for k in ITEM_BOOLS { o[k] = .bool(jsTruthy(it[k])) }
    for k in ITEM_OPT_BOOL { if let b = it[k]?.boolValue { o[k] = .bool(b) } }
    for k in ITEM_OPT_STR { if let s = it[k]?.stringValue { o[k] = .string(s) } }
    if let f = map.id {
        o["id"] = .string(f(str(o["id"])))
        if let x = o["_itemId"] { o["_itemId"] = .string(f(str(x))) }
    }
    if let f = map.mem, let x = o["_memId"] { o["_memId"] = .string(f(str(x))) }
    if let f = map.section { o["section"] = .string(f(str(o["section"]))) }
    if map.dropId { o["id"] = nil }
    return .object(o)
}
func shapeItem(_ it: Item, _ map: ShapeMap = ShapeMap()) -> J { shapeItem(it.json, map) }

/// An entry as a trip bundle carries it: only the keys that are there.
func shapeSlimEntry(_ e: J?) -> J {
    var out: [String: J] = [:]
    for (k, v) in e?.objectValue ?? [:] where ITEM_KEYS.contains(k) { out[k] = v }
    return .object(out)
}

func shapeSection(_ s: J?, _ map: ShapeMap = ShapeMap()) -> J {
    let sid = str(s?["id"])
    return obj(["id": .string(map.sectionId.map { $0(sid) } ?? sid), "name": .string(str(s?["name"]))])
}
func shapeSection(_ s: TemplateSection, _ map: ShapeMap = ShapeMap()) -> J { shapeSection(s.json, map) }

func shapeList(_ l: J?, _ map: ShapeMap = ShapeMap()) -> J {
    guard let l = l, l.objectValue != nil else { return l ?? .null }
    let lid = str(l["id"])
    return obj([
        "id": .string(map.listId.map { $0(lid) } ?? lid), "name": .string(str(l["name"])),
        "emoji": l["emoji"], "color": l["color"],
        "sections": .array(asArr(l["sections"]).map { shapeSection($0, map) }),
        "group": l["group"], "role": l["role"], "transport": l["transport"], "defaultContainer": l["defaultContainer"],
        "builtin": .bool(jsTruthy(l["builtin"])),
        "createdAt": .string(map.stamps ? NOWMARK : str(l["createdAt"])),
        "updatedAt": .string(map.stamps ? NOWMARK : str(l["updatedAt"])),
        "items": .array(asArr(l["items"]).map { shapeItem($0, map) }),
    ])
}
func shapeList(_ l: PackList, _ map: ShapeMap = ShapeMap()) -> J { shapeList(l.json, map) }

/// `minted`: the event's id is written "<id>" and its two stamps "<now>" (JS: `{ eventId: true, stamps: true }`).
func shapeEvent(_ e: J?, minted: Bool = false, entryShape: (J) -> J = { shapeItem($0) }) -> J {
    guard let e = e, e.objectValue != nil else { return e ?? .null }
    return obj([
        "id": .string(minted ? ID : str(e["id"])), "name": .string(str(e["name"])), "mode": e["mode"],
        "activities": e["activities"],
        "transport": .string(str(e["transport"])), "season": .string(str(e["season"])), "contexts": e["contexts"],
        "weatherOn": e["weatherOn"],
        "catering": .string(str(e["catering"])), "startDate": .string(str(e["startDate"])), "endDate": e["endDate"],
        "nights": e["nights"],
        "laundry": e["laundry"], "destination": e["destination"], "weather": e["weather"], "geo": e["geo"],
        "entries": .array(asArr(e["entries"]).map(entryShape)),
        "status": e["status"], "reviewedAt": e["reviewedAt"], "generatedAt": .string(str(e["generatedAt"])),
        "createdAt": .string(minted ? NOWMARK : str(e["createdAt"])),
        "updatedAt": .string(minted ? NOWMARK : str(e["updatedAt"])),
    ])
}
func shapeEvent(_ e: TripEvent) -> J { shapeEvent(e.json) }
/// An event the model minted (a parsed bundle, a decoded link): ids and stamps as markers.
func importedEventShape(_ e: TripEvent) -> J {
    shapeEvent(e.json, minted: true, entryShape: { shapeItem($0, ShapeMap(id: { _ in ID })) })
}

func shapeAction(_ a: J?) -> J {
    obj([
        "id": .string(str(a?["id"])), "text": a?["text"], "kind": a?["kind"], "itemId": a?["itemId"],
        "itemName": a?["itemName"], "priority": a?["priority"], "whenPhase": a?["whenPhase"],
        "whenDate": a?["whenDate"], "done": a?["done"], "doneAt": a?["doneAt"],
        "createdAt": a?["createdAt"], "updatedAt": a?["updatedAt"],
    ])
}
func shapeAction(_ a: ActionItem) -> J { shapeAction(a.json) }

func shapeKit(_ k: J?) -> J {
    obj([
        "id": .string(str(k?["id"])), "name": k?["name"], "emoji": k?["emoji"], "note": k?["note"],
        "itemIds": k?["itemIds"], "createdAt": k?["createdAt"], "updatedAt": k?["updatedAt"],
    ])
}
func shapeKit(_ k: Kit) -> J { shapeKit(k.json) }

func shapePhase(_ p: Phase?) -> J {
    guard let p = p else { return .null }
    return pick(p.json, ["id", "label", "hint", "emoji", "color", "task", "leadDays", "order"])
}
func shapeCondition(_ c: ItemCondition?) -> J {
    guard let c = c else { return .null }
    return pick(c.json, ["id", "label", "tone", "replace"])
}
func shapePerson(_ p: Person, minted: Bool = false) -> J {
    let j = p.json
    return obj(["id": .string(minted ? ID : str(j["id"])), "name": j["name"], "color": j["color"]])
}
func shapeMembership(_ m: Membership, _ map: ShapeMap = ShapeMap()) -> J {
    let j = m.json
    let mid = str(j["id"]), iid = str(j["itemId"])
    return obj([
        "id": .string(map.mem.map { $0(mid) } ?? mid), "itemId": .string(map.id.map { $0(iid) } ?? iid),
        "templateId": .string(str(j["templateId"])),
        "seasons": j["seasons"], "contexts": j["contexts"], "transports": j["transports"], "catering": j["catering"],
        "weather": j["weather"],
        "container": j["container"], "section": j["section"], "kit": j["kit"], "phase": j["phase"],
        "itemType": j["itemType"], "qty": j["qty"], "note": j["note"], "order": j["order"],
    ])
}
func shapeRow(_ r: SharedRow) -> J { pick(r.json, ["id", "kind", "key", "name", "order", "data"]) }

// The identifying tuples used inside grouping results (§3.6).
func entryRef(_ e: Item) -> String { [e.sourceItemId ?? "", e.name, e.container, e.phase].joined(separator: "|") }
func buildRef(_ e: Item) -> String { "\(e.sourceListId ?? "")|\(entryRef(e))" }
func itemRef(_ it: Item) -> String { "\(it.id)|\(it.name)" }
func refs(_ xs: [Item]) -> J { jstrings(xs.map(entryRef)) }
