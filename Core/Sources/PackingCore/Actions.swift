// Actions — small to-dos, and the buy-list built on the same store.
// Ported from js/model.js ("Actions (to-dos)").
//
// A small to-do, optionally tied to a catalog item (`itemId`) or "loose" (itemId
// ''). Actions live in their OWN store (not on the item), so the central Actions
// list has ONE clean source and a loose action needs no item at all. Ticking
// `done` is permanent on the action — it does not reset per trip.
//
// Called `ActionItem` because `Action` is taken elsewhere.

import Foundation

public let ACTION_PRIORITIES: [IdLabel] = [
    IdLabel(id: "high", label: "High"),
    IdLabel(id: "normal", label: "Normal"),
]
public let ACTION_PRIORITY_IDS: [String] = ACTION_PRIORITIES.map { $0.id }
public func actionPriorityLabel(_ pid: String?) -> String {
    ACTION_PRIORITIES.first { $0.id == pid }?.label ?? "Normal"
}

public struct ActionItem: JSONModel, Hashable, Sendable {
    public var id: String
    public var text: String
    /// 'todo' (Actions tab) | 'shopping' (buy-list on the Care tab)
    public var kind: String
    /// '' = loose (not tied to an item)
    public var itemId: String
    /// Cached item name, for display + orphan fallback.
    public var itemName: String
    public var priority: String
    /// Optional trip phase. Kept as-is even when unrecognised — see `coerceItem`.
    public var whenPhase: String
    /// Optional calendar date (YYYY-MM-DD).
    public var whenDate: String
    public var done: Bool
    /// ISO timestamp when ticked done.
    public var doneAt: String
    public var createdAt: String
    public var updatedAt: String
    /// 🪤 A JS QUIRK KEPT FOR PARITY. `referencedListValues` reads `a.phase` — a key no
    /// real action has (the app writes `whenPhase`), so in practice a to-do never counts
    /// as referring to a phase. Its own test passes `{ phase: 'prep' }`, which is the
    /// only reason this field exists. Left out of the JSON when nil.
    public var phase: String?
    /// Any key this package does not know — kept so nothing is lost on a round trip.
    public var extra: [String: JSONValue]

    /// The defaults are `newAction`'s. NOTE this does not coerce — `newAction(…)` does.
    public init(
        id: String = PackingEnv.makeId(),
        text: String = "",
        kind: String = "todo",
        itemId: String = "",
        itemName: String = "",
        priority: String = "normal",
        whenPhase: String = "",
        whenDate: String = "",
        done: Bool = false,
        doneAt: String = "",
        createdAt: String = nowISO(),
        updatedAt: String = nowISO(),
        phase: String? = nil,
        extra: [String: JSONValue] = [:]
    ) {
        self.id = id; self.text = text; self.kind = kind; self.itemId = itemId; self.itemName = itemName
        self.priority = priority; self.whenPhase = whenPhase; self.whenDate = whenDate
        self.done = done; self.doneAt = doneAt; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.phase = phase; self.extra = extra
    }

    static let knownKeys: Set<String> = [
        "id", "text", "kind", "itemId", "itemName", "priority", "whenPhase", "whenDate",
        "done", "doneAt", "createdAt", "updatedAt", "phase",
    ]

    /// `coerceAction(json)`.
    public init(json: JSONValue) {
        let o = json.objectValue ?? [:]
        // A missing `createdAt` becomes NOW, and a missing `updatedAt` follows it.
        let created = o["createdAt"]?.stringValue ?? nowISO()
        self.init(
            id: jsLooseText(o["id"]),
            text: jsStringOr(o["text"]),
            kind: jsStringOr(o["kind"]),
            itemId: jsStringOr(o["itemId"]),
            itemName: jsStringOr(o["itemName"]),
            priority: jsStringOr(o["priority"]),
            whenPhase: jsStringOr(o["whenPhase"]),
            whenDate: jsStringOr(o["whenDate"]),
            done: jsTruthy(o["done"]),
            doneAt: jsStringOr(o["doneAt"]),
            createdAt: created,
            updatedAt: o["updatedAt"]?.stringValue ?? created,
            phase: o["phase"]?.stringValue,
            extra: extraKeys(o, known: ActionItem.knownKeys)
        )
        self = coerceAction(self)
    }

    public var json: JSONValue {
        var o = extra
        o["id"] = .string(id); o["text"] = .string(text); o["kind"] = .string(kind)
        o["itemId"] = .string(itemId); o["itemName"] = .string(itemName); o["priority"] = .string(priority)
        o["whenPhase"] = .string(whenPhase); o["whenDate"] = .string(whenDate)
        o["done"] = .bool(done); o["doneAt"] = .string(doneAt)
        o["createdAt"] = .string(createdAt); o["updatedAt"] = .string(updatedAt)
        if let p = phase { o["phase"] = .string(p) }
        return .object(o)
    }
}

/// The value rules of `coerceAction`, for an action built in memory.
public func coerceAction(_ action: ActionItem) -> ActionItem {
    var a = action
    a.kind = a.kind == "shopping" ? "shopping" : "todo"
    a.priority = ACTION_PRIORITY_IDS.contains(a.priority) ? a.priority : "normal"
    a.whenPhase = jsSlice(jsTrim(a.whenPhase), 0, 40)
    a.whenDate = isYMD(a.whenDate) ? a.whenDate : ""
    return a
}
/// `coerceAction(a)` for raw JSON. nil when it is not an object.
public func coerceAction(json a: JSONValue?) -> ActionItem? {
    guard let a = a, a.objectValue != nil else { return nil }
    return ActionItem(json: a)
}

// A timing rank used to order the central list: concrete dates first (soonest
// wins), then trip phases in their natural order, then anything untimed.
func actionWhenRank(_ a: ActionItem) -> String {
    if !a.whenDate.isEmpty { return "0-\(a.whenDate)" }
    if !a.whenPhase.isEmpty {
        let n = String(phaseOrder(a.whenPhase))
        return "1-\(n.count < 2 ? "0" + n : n)"
    }
    return "9"
}

/// Sort for the central Actions list: open before done, high before normal,
/// sooner before later, then newest-created first. Negative = `a` first.
public func compareActions(_ a: ActionItem, _ b: ActionItem) -> Int {
    if a.done != b.done { return a.done ? 1 : -1 }
    let pa = a.priority == "high" ? 0 : 1, pb = b.priority == "high" ? 0 : 1
    if pa != pb { return pa - pb }
    let ta = actionWhenRank(a), tb = actionWhenRank(b)
    if ta != tb { return jsStringLess(ta, tb) ? -1 : 1 }
    return jsLocaleCompare(b.createdAt, a.createdAt)
}

/// `newAction({ … })` — the same parameters as `ActionItem.init`, then `coerceAction`.
public func newAction(
    id: String = PackingEnv.makeId(),
    text: String = "",
    kind: String = "todo",
    itemId: String = "",
    itemName: String = "",
    priority: String = "normal",
    whenPhase: String = "",
    whenDate: String = "",
    done: Bool = false,
    doneAt: String = "",
    createdAt: String = nowISO(),
    updatedAt: String = nowISO(),
    phase: String? = nil,
    extra: [String: JSONValue] = [:]
) -> ActionItem {
    coerceAction(ActionItem(id: id, text: text, kind: kind, itemId: itemId, itemName: itemName,
                            priority: priority, whenPhase: whenPhase, whenDate: whenDate, done: done,
                            doneAt: doneAt, createdAt: createdAt, updatedAt: updatedAt, phase: phase, extra: extra))
}
/// `newAction(action)` — coerce an action already built with `ActionItem(…)`.
public func newAction(_ action: ActionItem) -> ActionItem { coerceAction(action) }
/// `newAction(partial)` for a raw JSON partial, laid over the defaults as the JS spreads it.
public func newAction(json partial: JSONValue) -> ActionItem {
    var o = ActionItem().json.objectValue ?? [:]
    for (k, v) in partial.objectValue ?? [:] { o[k] = v }
    return ActionItem(json: .object(o))
}
