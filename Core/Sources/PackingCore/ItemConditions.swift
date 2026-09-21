// ItemConditions — a simple wear/lifecycle rating (optional item metadata).
// Ported from js/model.js ("Item condition").
//
// The four below are what the app ships with, but the list is EDITABLE: you can
// rename, reorder, add and remove conditions in Settings. Two behaviours that used
// to be hardwired to the id 'retire' are now properties of whichever condition you
// point them at, so a condition you invent can do the same job:
//
//   tone     '' | 'warn' | 'danger'  — whether (and how loudly) the item row badges it
//   replace  true                    — this means "needs replacing": it raises the
//                                      badge as a replace prompt and feeds the
//                                      shopping list's suggestions
//
// `DEFAULT_ITEM_CONDITIONS` is the factory setting, kept so Settings can offer a
// reset and so a device with nothing stored still behaves exactly as before.

import Foundation

public struct ItemCondition: JSONModel, Hashable, Sendable {
    public var id: String
    public var label: String
    public var tone: String
    public var replace: Bool

    public init(id: String = "", label: String = "", tone: String = "", replace: Bool = false) {
        self.id = id; self.label = label; self.tone = tone; self.replace = replace
    }
    public init(json: JSONValue) { self = coerceCondition(json: json) }
    public var json: JSONValue {
        ["id": .string(id), "label": .string(label), "tone": .string(tone), "replace": .bool(replace)]
    }
}

public let DEFAULT_ITEM_CONDITIONS: [ItemCondition] = [
    ItemCondition(id: "new", label: "New", tone: "", replace: false),
    ItemCondition(id: "good", label: "Good", tone: "", replace: false),
    ItemCondition(id: "worn", label: "Worn", tone: "warn", replace: false),
    ItemCondition(id: "retire", label: "Needs replacing", tone: "danger", replace: true),
]
public let CONDITION_TONES: [IdLabel] = [
    IdLabel(id: "", label: "No badge"),
    IdLabel(id: "warn", label: "Amber badge"),
    IdLabel(id: "danger", label: "Red badge"),
]
let CONDITION_TONE_IDS: [String] = CONDITION_TONES.map { $0.id }

// The live list, and its ids — module-level state, mirrored from the JS ON PURPOSE.
// Replaced only through `setItemConditions`. Tests that change them restore the defaults.
public private(set) var ITEM_CONDITIONS: [ItemCondition] = DEFAULT_ITEM_CONDITIONS
public private(set) var ITEM_CONDITION_IDS: [String] = DEFAULT_ITEM_CONDITIONS.map { $0.id }

/// The value rules of `coerceCondition`, for a condition built in memory.
public func coerceCondition(_ c: ItemCondition) -> ItemCondition {
    ItemCondition(
        id: jsSlice(jsTrim(c.id), 0, 40),
        label: jsSlice(jsTrim(c.label), 0, 60),
        tone: CONDITION_TONE_IDS.contains(c.tone) ? c.tone : "",
        replace: c.replace
    )
}
/// `coerceCondition(c)` for raw JSON — anything that is not an object reads as `{}`.
public func coerceCondition(json c: JSONValue?) -> ItemCondition {
    let o = c?.objectValue ?? [:]
    return coerceCondition(ItemCondition(
        id: jsStringOrEmpty(o["id"]),
        label: jsStringOrEmpty(o["label"]),
        tone: jsStringOr(o["tone"]),
        replace: jsTruthy(o["replace"])
    ))
}

/// A new condition earns its id from its name (so it reads sensibly in a backup),
/// falling back to a timestamp when the name is all punctuation. `taken` are ids
/// already in use, which the new one must not collide with.
public func newCondition(_ label: String, _ taken: [String] = []) -> ItemCondition {
    let base = jsSlug(label)
    var candidate = base.isEmpty ? "cond-\(jsBase36(jsDateNow()))" : base
    var n = 2
    while taken.contains(candidate) {
        candidate = "\(base.isEmpty ? "cond" : base)-\(n)"
        n += 1
    }
    return ItemCondition(id: candidate, label: jsSlice(jsTrim(label), 0, 60), tone: "", replace: false)
}

/// Install a condition list. Anything unusable (no id, no label, a duplicate id) is
/// dropped; an empty result falls back to the factory four rather than leaving the
/// app with no conditions at all.
@discardableResult
public func setItemConditions(_ list: [ItemCondition]) -> [ItemCondition] {
    installConditions(list.map { coerceCondition($0) })
}
/// `setItemConditions` for raw JSON (stored rows, or a test written the JS way).
@discardableResult
public func setItemConditions(json list: JSONValue?) -> [ItemCondition] {
    installConditions(asArray(list).map { coerceCondition(json: $0) })
}

private func installConditions(_ coerced: [ItemCondition]) -> [ItemCondition] {
    var seen = Set<String>()
    let clean = coerced.filter { c in
        if c.id.isEmpty || c.label.isEmpty || seen.contains(c.id) { return false }
        seen.insert(c.id)
        return true
    }
    let next = clean.isEmpty ? DEFAULT_ITEM_CONDITIONS : clean
    ITEM_CONDITIONS = next
    ITEM_CONDITION_IDS = next.map { $0.id }
    return ITEM_CONDITIONS
}

public func itemCondition(_ idv: String?) -> ItemCondition? { ITEM_CONDITIONS.first { $0.id == idv } }

/// The display label for a condition id ('' → '' — an unrated item says nothing).
/// An id this device doesn't know (set on another device, or on a condition since
/// removed) is shown as itself rather than vanishing.
public func itemConditionLabel(_ idv: String?) -> String {
    if let c = itemCondition(idv) { return c.label }
    return idv ?? ""
}
public func conditionTone(_ idv: String?) -> String { itemCondition(idv)?.tone ?? "" }
/// Does this condition mean "needs replacing"? Drives the replace badge and the
/// shopping list. Was hardwired to the id 'retire' until conditions became editable.
public func conditionReplaces(_ idv: String?) -> Bool { itemCondition(idv)?.replace ?? false }
