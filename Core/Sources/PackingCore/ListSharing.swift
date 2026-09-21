// ListSharing — a template as a code (QR / link / paste).
// Ported from js/model.js ("Sharing a template").
//
// A template travels the same way a grab list does: everything that decides
// WHAT it contributes and WHEN — its name, cover, group, role, sections, and
// every item with its conditions, flags and placing — packed into a deep link
// (#/l/<code>) that doubles as a QR code. Photos, care records and history are
// deliberately left behind: they describe the physical thing standing in this
// home, not the recipe. Short keys on purpose; every byte makes the QR denser.

import Foundation

public let LIST_SHARE_KIND = "tpl"
public let LIST_SHARE_NAME_MAX = 60
public let LIST_SHARE_ITEMS_MAX = 400

// The yes/no flags ride in one number rather than a dozen keys.
private let LIST_SHARE_FLAGS: [(key: String, bit: Int32)] = [
    ("shortList", 1), ("charging", 2), ("liquid", 4),
    ("restricted", 8), ("perNight", 16), ("consumable", 32),
]

/// `asArray(arr).filter(string).map(clean).filter(Boolean)`
func cleanShareList(_ arr: [JSONValue], _ max: Int = 40) -> [String] {
    cleanShareListUnits(arr, max).map { shareText(cleaned: $0) }.filter { !$0.isEmpty }
}
private func cleanShareListUnits(_ arr: [JSONValue], _ max: Int = 40) -> [[UInt16]] {
    arr.compactMap { $0.stringValue }.map { cleanShareUnits($0, max) }.filter { !$0.isEmpty }
}

// MARK: - What a decoded share holds

/// One item of a shared template, as `decodeListShare` returns it. `section` is the
/// section's NAME here — sections travel by name, so the receiving device can
/// rebuild its own ids.
///
/// `ownedBy` (short key `u`) is "whose it is" — a NAME. Until v186 the web app read
/// the sync layer's `owner` here, and every shared template carried the sender's
/// sign-in address on every item; both ends now pass it through `shareSafeOwner`.
public struct SharedListItem: Equatable, Hashable, Sendable {
    public var name: String
    public var swedish: String
    public var qty: String
    public var category: String
    public var phase: String
    public var container: String
    public var note: String
    public var chargeType: String
    public var section: String
    public var kit: String
    public var storage: String
    public var packer: String
    public var ownedBy: String
    public var itemType: String
    public var weight: Double
    public var seasons: [String]
    public var contexts: [String]
    public var transports: [String]
    public var catering: [String]
    public var weather: [String]
    public var sub: [String]
    public var shortList: Bool
    public var charging: Bool
    public var liquid: Bool
    public var restricted: Bool
    public var perNight: Bool
    public var consumable: Bool

    public init(
        name: String = "", swedish: String = "", qty: String = "", category: String = "", phase: String = "",
        container: String = "", note: String = "", chargeType: String = "", section: String = "", kit: String = "",
        storage: String = "", packer: String = "", ownedBy: String = "", itemType: String = "item", weight: Double = 0,
        seasons: [String] = [], contexts: [String] = [], transports: [String] = [], catering: [String] = [],
        weather: [String] = [], sub: [String] = [],
        shortList: Bool = false, charging: Bool = false, liquid: Bool = false, restricted: Bool = false,
        perNight: Bool = false, consumable: Bool = false
    ) {
        self.name = name; self.swedish = swedish; self.qty = qty; self.category = category; self.phase = phase
        self.container = container; self.note = note; self.chargeType = chargeType; self.section = section
        self.kit = kit; self.storage = storage; self.packer = packer; self.ownedBy = ownedBy
        self.itemType = itemType; self.weight = weight
        self.seasons = seasons; self.contexts = contexts; self.transports = transports; self.catering = catering
        self.weather = weather; self.sub = sub
        self.shortList = shortList; self.charging = charging; self.liquid = liquid; self.restricted = restricted
        self.perNight = perNight; self.consumable = consumable
    }

    public var json: JSONValue {
        [
            "name": .string(name), "swedish": .string(swedish), "qty": .string(qty), "category": .string(category),
            "phase": .string(phase), "container": .string(container), "note": .string(note),
            "chargeType": .string(chargeType), "section": .string(section), "kit": .string(kit),
            "storage": .string(storage), "packer": .string(packer), "ownedBy": .string(ownedBy),
            "itemType": .string(itemType),
            "weight": .number(weight),
            "seasons": JSONValue(seasons), "contexts": JSONValue(contexts), "transports": JSONValue(transports),
            "catering": JSONValue(catering), "weather": JSONValue(weather), "sub": JSONValue(sub),
            "shortList": .bool(shortList), "charging": .bool(charging), "liquid": .bool(liquid),
            "restricted": .bool(restricted), "perNight": .bool(perNight), "consumable": .bool(consumable),
        ]
    }
}

/// `{ name, emoji, color, group, role, transport, defaultContainer, sections, items }` —
/// what `decodeListShare` returns. `sections` are NAMES.
public struct SharedList: Equatable, Hashable, Sendable {
    public var name: String
    public var emoji: String
    public var color: String
    public var group: String
    public var role: String
    public var transport: String
    public var defaultContainer: String
    public var sections: [String]
    public var items: [SharedListItem]

    public init(name: String = "", emoji: String = "", color: String = "", group: String = "", role: String = "",
                transport: String = "", defaultContainer: String = "", sections: [String] = [],
                items: [SharedListItem] = []) {
        self.name = name; self.emoji = emoji; self.color = color; self.group = group; self.role = role
        self.transport = transport; self.defaultContainer = defaultContainer
        self.sections = sections; self.items = items
    }

    public var json: JSONValue {
        [
            "name": .string(name), "emoji": .string(emoji), "color": .string(color), "group": .string(group),
            "role": .string(role), "transport": .string(transport), "defaultContainer": .string(defaultContainer),
            "sections": JSONValue(sections), "items": .array(items.map { $0.json }),
        ]
    }
}

// MARK: - Encode

/// KEY ORDER (compared byte for byte): top level `k v n x i c g r tp d s`, each item
/// `n f w q c p b o y e k s a u t g se cx tr ca we sb` — every key but `k v n x` and
/// an item's `n` only when it says something.
public func encodeListShare(_ list: PackList?) throws -> String {
    guard let list = list else { throw ShareError("There is no template to share.") }
    let sections = list.sections.filter { !$0.id.isEmpty && !$0.name.isEmpty }
    var sectionName: [String: [UInt16]] = [:]
    for s in sections { sectionName[s.id] = cleanShareUnits(s.name, 40) }

    let items: [OrderedJSON] = list.items.prefix(LIST_SHARE_ITEMS_MAX).compactMap { (it: Item) -> OrderedJSON? in
        let name = cleanShareUnits(it.name, GRAB_SHARE_ITEM_MAX)
        if name.isEmpty { return nil }
        var o: [OrderedJSON.Member] = [.init("n", .js(name))]
        func put(_ k: String, _ v: [UInt16]) { if !v.isEmpty { o.append(.init(k, .js(v))) } }
        func putText(_ k: String, _ v: String) { if !v.isEmpty { o.append(.init(k, .string(v))) } }
        var flags: Int32 = 0
        let on: [String: Bool] = ["shortList": it.shortList, "charging": it.charging, "liquid": it.liquid,
                                  "restricted": it.restricted, "perNight": it.perNight, "consumable": it.consumable]
        for (key, bit) in LIST_SHARE_FLAGS where on[key] == true { flags |= bit }
        if flags != 0 { o.append(.init("f", .number(Double(flags)))) }
        put("w", cleanShareUnits(it.swedish, 60))
        put("q", cleanShareUnits(it.qty, 20))
        putText("c", it.category)
        putText("p", it.phase)
        putText("b", it.container)
        put("o", cleanShareUnits(it.note, 200))
        putText("y", it.chargeType)
        put("e", it.section.isEmpty ? [] : (sectionName[it.section] ?? []))
        put("k", cleanShareUnits(it.kit, 40))
        put("s", cleanShareUnits(it.storage, 60))
        put("a", cleanShareUnits(it.packer, 40))
        // 🚨 `ownedBy`, NEVER `owner`. `owner` belongs to the sync addon and holds the
        // signed-in account's e-mail address; until v186 this line read it, and every
        // shared template carried the sender's address on every item.
        put("u", shareSafeOwnerUnits(it.ownedBy))
        if it.itemType == "reminder" { o.append(.init("t", .number(1))) }
        if it.weight.isFinite && it.weight > 0 { o.append(.init("g", .number(jsRound(it.weight)))) }
        let arrays: [(String, [String])] = [("se", it.seasons), ("cx", it.contexts), ("tr", it.transports),
                                            ("ca", it.catering), ("we", it.weather), ("sb", it.sub)]
        for (short, values) in arrays {
            let arr = cleanShareListUnits(values.map { .string($0) }, short == "sb" ? 60 : 40)
            if !arr.isEmpty { o.append(.init(short, .array(arr.map { .js($0) }))) }
        }
        return .object(o)
    }
    if items.isEmpty { throw ShareError("This template has nothing on it to share.") }

    var obj: [OrderedJSON.Member] = [
        .init("k", .string(LIST_SHARE_KIND)), .init("v", .number(1)),
        .init("n", .js(cleanShareUnits(list.name, LIST_SHARE_NAME_MAX))),
        .init("x", .array(items)),
    ]
    if !list.emoji.isEmpty { obj.append(.init("i", .js(Array(list.emoji.utf16.prefix(4))))) }
    if !list.color.isEmpty { obj.append(.init("c", .js(Array(list.color.utf16.prefix(9))))) }
    if !list.group.isEmpty { obj.append(.init("g", .string(list.group))) }
    if !list.role.isEmpty { obj.append(.init("r", .string(list.role))) }
    if !list.transport.isEmpty { obj.append(.init("tp", .string(list.transport))) }
    if !list.defaultContainer.isEmpty { obj.append(.init("d", .js(cleanShareUnits(list.defaultContainer, 60)))) }
    let secNames = sections.compactMap { sectionName[$0.id] }.filter { !$0.isEmpty }
    if !secNames.isEmpty { obj.append(.init("s", .array(secNames.map { .js($0) }))) }
    return packShare(OrderedJSON.object(obj).text())
}

// MARK: - Decode

private let notATemplate = ShareError("This is not an AMS Packing template link or code.")

/// `flags & bit` — JS turns the number into a 32-bit integer first (ToInt32).
private func jsToInt32(_ d: Double) -> Int32 {
    guard d.isFinite else { return 0 }
    let m = d.rounded(.towardZero).truncatingRemainder(dividingBy: 4_294_967_296)
    return Int32(truncatingIfNeeded: Int64(m))
}

/// Accepts a bare code, a whole link carrying #/l/<code>, or anything with such
/// a link pasted inside it. Throws on anything that isn't a shared template.
public func decodeListShare(_ text: String?) throws -> SharedList {
    var payload = jsTrim(text ?? "")
    if let m = sharePayload(in: payload, marker: "#/l/") { payload = m }
    let obj: JSONValue
    do { obj = try JSONValue.parse(try unpackShare(payload)) } catch { throw notATemplate }
    guard obj.objectValue != nil || obj.arrayValue != nil, obj["k"]?.stringValue == LIST_SHARE_KIND else { throw notATemplate }

    func clean(_ v: JSONValue?, _ max: Int) -> String { cleanShareText(jsStringNullish(v), max) }
    let items: [SharedListItem] = asArray(obj["x"]).compactMap { (o: JSONValue) -> SharedListItem? in
        guard o.objectValue != nil else { return nil }
        let name = clean(o["n"], GRAB_SHARE_ITEM_MAX)
        if name.isEmpty { return nil }
        let flags = jsToInt32(o["f"]?.finiteNumber ?? 0)
        var weight = 0.0
        if let g = o["g"]?.finiteNumber, g > 0 { weight = jsRound(g) }
        func flag(_ key: String) -> Bool {
            guard let bit = LIST_SHARE_FLAGS.first(where: { $0.key == key })?.bit else { return false }
            return flags & bit != 0
        }
        return SharedListItem(
            name: name,
            swedish: clean(o["w"], 60),
            qty: clean(o["q"], 20),
            category: jsStringOr(o["c"]),
            phase: jsStringOr(o["p"]),
            container: jsStringOr(o["b"]),
            note: clean(o["o"], 200),
            chargeType: jsStringOr(o["y"]),
            section: clean(o["e"], 40),
            kit: clean(o["k"], 40),
            storage: clean(o["s"], 60),
            packer: clean(o["a"], 40),
            ownedBy: shareSafeOwner(jsStringNullish(o["u"])),   // a code made before v186 may hold an address here — it stops at the door
            itemType: o["t"] == .number(1) ? "reminder" : "item",
            weight: weight,
            seasons: cleanShareList(asArray(o["se"])), contexts: cleanShareList(asArray(o["cx"])),
            transports: cleanShareList(asArray(o["tr"])), catering: cleanShareList(asArray(o["ca"])),
            weather: cleanShareList(asArray(o["we"])), sub: cleanShareList(asArray(o["sb"]), 60),
            shortList: flag("shortList"), charging: flag("charging"), liquid: flag("liquid"),
            restricted: flag("restricted"), perNight: flag("perNight"), consumable: flag("consumable")
        )
    }
    let kept = Array(items.prefix(LIST_SHARE_ITEMS_MAX))
    if kept.isEmpty { throw ShareError("The shared template is empty.") }
    return SharedList(
        name: clean(obj["n"], LIST_SHARE_NAME_MAX),
        emoji: jsSlice(jsStringOr(obj["i"]), 0, 4),
        color: jsStringOr(obj["c"]),
        group: jsStringOr(obj["g"]),
        role: jsStringOr(obj["r"]),
        transport: jsStringOr(obj["tp"]),
        defaultContainer: clean(obj["d"], 60),
        sections: cleanShareList(asArray(obj["s"])),
        items: kept
    )
}

// MARK: - Import

/// Turn a decoded share into a real template, ready to save: fresh ids
/// throughout, sections rebuilt and each item pointed back at its own section by
/// name. The two system bins (the Loose items holder and the Containers
/// catalogue) can never arrive this way — an imported one becomes an ordinary
/// template — and nothing imported is ever marked built-in.
///
/// `partial` is laid over the result as the JS spreads it (`{ id, createdAt }` when
/// a template is replaced in place). Ids are drawn in the JS order: sections, items,
/// then the list's own — which is drawn even when `partial` brings one.
public func listFromShare(_ shared: SharedList?, partial: JSONValue = [:]) -> PackList {
    let src = shared ?? SharedList()
    let sections = normalizeSections(cleanShareList(src.sections.map { .string($0) }).map { TemplateSection(id: id(), name: $0) })
    var byName: [String: String] = [:]
    for s in sections { byName[s.name.lowercased()] = s.id }
    let role = (src.role == "loose" || src.role == "container") ? "" : src.role
    let name = cleanShareText(src.name, LIST_SHARE_NAME_MAX)
    let items = src.items.map { o in
        newItem(
            name: o.name, swedish: o.swedish, qty: o.qty, category: o.category, container: o.container,
            phase: o.phase, itemType: o.itemType, charging: o.charging, chargeType: o.chargeType,
            shortList: o.shortList, seasons: o.seasons, contexts: o.contexts, transports: o.transports,
            catering: o.catering, weather: o.weather, sub: o.sub, note: o.note, weight: o.weight,
            liquid: o.liquid, restricted: o.restricted, perNight: o.perNight, consumable: o.consumable,
            section: byName[o.section.lowercased()] ?? "", kit: o.kit, packer: o.packer, storage: o.storage,
            ownedBy: o.ownedBy
        )
    }
    let list = newList(
        id: id(),
        name: name.isEmpty ? "Shared template" : name,
        emoji: src.emoji, color: src.color, sections: sections, group: src.group, role: role,
        transport: src.transport, defaultContainer: src.defaultContainer, builtin: false, items: items
    )
    guard let over = partial.objectValue, !over.isEmpty else { return list }
    var o = list.json.objectValue ?? [:]
    for (k, v) in over { o[k] = v }
    return PackList(json: .object(o))
}
