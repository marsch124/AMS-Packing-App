// GrabSharing — a workout grab list as a code (QR / link / paste).
// Ported from js/model.js ("Sharing a grab list").
//
// A workout grab list travels as a compact code: its name, doodle and colour
// plus the item names, base64url-encoded into a deep link (#/g/<code>) that the
// receiving app offers for import. Short keys on purpose — the same code is
// drawn as a QR, and every byte makes it denser. Icon and tone are carried as
// the keys the app stores; the receiver checks them against its own gallery
// and falls back to the target button's factory look for anything unknown.

import Foundation

public let GRAB_SHARE_KIND = "grab"
public let GRAB_SHARE_NAME_MAX = 14    // matches the list-name field
public let GRAB_SHARE_ITEM_MAX = 60    // matches the item-name field
public let GRAB_SHARE_ITEMS_MAX = 100

/// `{ name, icon, tone, items }` — what `decodeGrabShare` returns, and what
/// `encodeGrabShare` takes.
public struct GrabShare: Equatable, Hashable, Sendable {
    public var name: String
    public var icon: String
    public var tone: String
    public var items: [String]
    public init(name: String = "", icon: String = "", tone: String = "", items: [String] = []) {
        self.name = name; self.icon = icon; self.tone = tone; self.items = items
    }
    public var json: JSONValue {
        ["name": .string(name), "icon": .string(icon), "tone": .string(tone), "items": JSONValue(items)]
    }
}

func cleanGrabUnits(_ v: String, _ max: Int) -> [UInt16] { cleanShareUnits(v, max) }
func cleanGrabName(_ v: String, _ max: Int) -> String { cleanShareText(v, max) }

/// Trimmed, blanks and repeats (whatever their case) dropped, capped in length and
/// in number. Anything that is not a string is stepped over. Kept as UTF-16 units so
/// the encoded text matches the web app's even when the cut lands inside an emoji.
func cleanGrabItems(_ arr: [JSONValue]) -> [[UInt16]] {
    var out: [[UInt16]] = []
    var seen = Set<String>()
    for raw in arr {
        guard let s = raw.stringValue else { continue }
        let name = cleanGrabUnits(s, GRAB_SHARE_ITEM_MAX)
        let key = shareStringDroppingLoneSurrogates(name).lowercased()
        if name.isEmpty || seen.contains(key) { continue }
        seen.insert(key)
        out.append(name)
        if out.count >= GRAB_SHARE_ITEMS_MAX { break }
    }
    return out
}

private func encodeGrabShare(name: String, icon: String, tone: String, rawItems: [JSONValue]) throws -> String {
    let list = cleanGrabItems(rawItems)
    if list.isEmpty { throw ShareError("This list has nothing on it to share.") }
    var obj: [OrderedJSON.Member] = [
        .init("k", .string(GRAB_SHARE_KIND)), .init("v", .number(1)),
        .init("n", .js(cleanGrabUnits(name, GRAB_SHARE_NAME_MAX))),
        .init("x", .array(list.map { .js($0) })),
    ]
    if !icon.isEmpty { obj.append(.init("i", .string(icon))) }
    if !tone.isEmpty { obj.append(.init("c", .string(tone))) }
    return packShare(OrderedJSON.object(obj).text())
}

public func encodeGrabShare(name: String = "", icon: String = "", tone: String = "", items: [String] = []) throws -> String {
    try encodeGrabShare(name: name, icon: icon, tone: tone, rawItems: items.map { .string($0) })
}
public func encodeGrabShare(_ share: GrabShare) throws -> String {
    try encodeGrabShare(name: share.name, icon: share.icon, tone: share.tone, items: share.items)
}
/// `encodeGrabShare({ … })` for raw JSON with junk in it: `items` that are not
/// strings are stepped over, a name that is a number is its text.
public func encodeGrabShare(json share: JSONValue?) throws -> String {
    try encodeGrabShare(name: jsStringNullish(share?["name"]),
                        icon: jsStringOrEmpty(share?["icon"]),
                        tone: jsStringOrEmpty(share?["tone"]),
                        rawItems: asArray(share?["items"]))
}

private let notAGrabList = ShareError("This is not an AMS Packing grab-list link or code.")

/// Accepts a bare code, a whole link carrying #/g/<code>, or anything with such
/// a link pasted somewhere inside it. Throws on anything that isn't a grab list.
public func decodeGrabShare(_ text: String?) throws -> GrabShare {
    var payload = jsTrim(text ?? "")
    if let m = sharePayload(in: payload, marker: "#/g/") { payload = m }
    let obj: JSONValue
    do { obj = try JSONValue.parse(try unpackShare(payload)) } catch { throw notAGrabList }
    guard obj.objectValue != nil || obj.arrayValue != nil, obj["k"]?.stringValue == GRAB_SHARE_KIND else { throw notAGrabList }
    let items = cleanGrabItems(asArray(obj["x"])).map { shareText(cleaned: $0) }
    if items.isEmpty { throw ShareError("The shared list is empty.") }
    return GrabShare(
        name: cleanGrabName(jsStringNullish(obj["n"]), GRAB_SHARE_NAME_MAX),
        icon: jsStringOr(obj["i"]),
        tone: jsStringOr(obj["c"]),
        items: items
    )
}
