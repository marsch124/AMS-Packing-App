// Shopping — the pre-trip restock & replace list.
// Ported from js/model.js ("Shopping list (pre-trip restock & replace)").
//
// A buy-list is built on the actions store (kind 'shopping'); these pure helpers
// decide which items should be OFFERED for it and why.

import Foundation

/// How soon before an item's replace-by / expiry date it starts wanting attention.
public let EXPIRY_SOON_DAYS = 30

/// Why an item wants buying, or '' if it doesn't. Most urgent reason wins: an
/// explicit "Needs replacing" beats an already-expired date, which beats an expiring
/// -soon date, which beats a plain consumable that just needs restocking.
public func shoppingReason(_ item: Item?, _ todayISO: String? = nil) -> String {
    guard let item = item else { return "" }
    // Any condition flagged "needs replacing" qualifies — not just the built-in one.
    // The reason string stays fixed so its rank, its chip colour and the buy-list
    // wording don't change with whatever you named the condition.
    if conditionReplaces(item.condition) { return "Needs replacing" }
    if !item.expiry.isEmpty {
        // A date that cannot be read (`daysUntil` → null) raises nothing, as in JS.
        if let d = daysUntil(item.expiry, todayISO) {
            if d < 0 { return "Expired" }
            if d <= EXPIRY_SOON_DAYS { return "Replace soon" }
        }
    }
    if item.consumable { return "Restock" }
    return ""
}

/// One line of `expiringOnTrip`: `{ entry, expiry, alreadyOut, daysLeft }`.
public struct ExpiringEntry: Equatable, Sendable {
    public var entry: Item
    public var expiry: String
    /// Already past its date today (a shopping trip before you leave) — as opposed to
    /// running out DURING the trip (a decision about whether to take it at all).
    public var alreadyOut: Bool
    /// Whole days from today to the date; nil where JS has null (an unreadable date).
    public var daysLeft: Int?
    public init(entry: Item, expiry: String, alreadyOut: Bool, daysLeft: Int?) {
        self.entry = entry; self.expiry = expiry; self.alreadyOut = alreadyOut; self.daysLeft = daysLeft
    }
    public var json: JSONValue {
        ["entry": entry.json, "expiry": .string(expiry), "alreadyOut": .bool(alreadyOut),
         "daysLeft": daysLeft.map { .number(Double($0)) } ?? .null]
    }
}

/// Gear on THIS trip whose replace-by date falls before you get home.
///
/// 🚨 WHY THIS IS SEPARATE FROM shoppingReason. That one asks "should I buy this
/// soon?" and answers against TODAY plus a fixed 30-day window — which is the wrong
/// question the moment a trip has dates on it. Sunscreen expiring in 60 days raises
/// nothing today, and then expires quietly halfway through a trip you leave for in
/// seven weeks. And a three-week trip starting in 25 days takes gear "expiring soon"
/// with it and says nothing about the fortnight it is out of date.
///
/// The trip knows when it ends. That is the date its own gear should be judged
/// against: will this still be good when I need it?
///
/// `alreadyOut` separates the two cases, because they read differently and want
/// different actions.
public func expiringOnTrip(_ entries: [Item], _ endDate: String?, _ todayISO: String? = nil) -> [ExpiringEntry] {
    let end = jsSlice(endDate ?? "", 0, 10)
    if end.isEmpty { return [] }
    let today = todayYMD(todayISO)
    var out: [ExpiringEntry] = []
    var seen = Set<String>()
    for e in entries {
        if e.itemType == "reminder" || e.retired { continue }
        let exp = isYMD(e.expiry) ? e.expiry : ""
        if exp.isEmpty || jsStringLess(end, exp) { continue }   // still good when you get home
        // `e.sourceItemId || e.id`
        let key: String
        if let src = e.sourceItemId, !src.isEmpty { key = src } else { key = e.id }
        if seen.contains(key) { continue }                       // one line per thing, not per template
        seen.insert(key)
        out.append(ExpiringEntry(entry: e, expiry: exp, alreadyOut: jsStringLess(exp, today),
                                 daysLeft: daysUntil(exp, today)))
    }
    return out.stableSorted(compare: { a, b in jsLocaleCompare(a.expiry, b.expiry) })
}

// Sort rank so the buy-list shows the most urgent reasons first.
// (Not exported by the JS module, so not public here either.)
let SHOP_REASON_RANK: [String: Int] = ["Needs replacing": 0, "Expired": 1, "Replace soon": 2, "Restock": 3]

/// One line of `shoppingSuggestions`: `{ item, reason }`.
public struct ShoppingSuggestion: Equatable, Sendable {
    public var item: Item
    public var reason: String
    public init(item: Item, reason: String) { self.item = item; self.reason = reason }
    public var json: JSONValue { ["item": item.json, "reason": .string(reason)] }
}

/// Items worth buying before a trip: consumables, things marked "Needs replacing",
/// and anything past (or near) its replace-by date. Retired ("not in use") items are
/// skipped, as is anything already on the open buy-list (matched by item id). Pass
/// the de-duplicated catalog as `items` and the current actions as `actions`.
public func shoppingSuggestions(_ items: [Item], _ actions: [ActionItem], _ todayISO: String? = nil) -> [ShoppingSuggestion] {
    let onList = Set(actions.filter { $0.kind == "shopping" && !$0.done && !$0.itemId.isEmpty }.map { $0.itemId })
    var out: [ShoppingSuggestion] = []
    for it in items {
        if it.retired { continue }
        if onList.contains(it.id) { continue }
        let reason = shoppingReason(it, todayISO)
        if reason.isEmpty { continue }
        out.append(ShoppingSuggestion(item: it, reason: reason))
    }
    return out.stableSorted(compare: { a, b in
        jsOr((SHOP_REASON_RANK[a.reason] ?? 0) - (SHOP_REASON_RANK[b.reason] ?? 0),
             jsLocaleCompare(a.item.name, b.item.name))
    })
}

/// Open (still-to-buy) items on the shopping list — for the Home nudge + Care card.
public func openShoppingCount(_ actions: [ActionItem]) -> Int {
    actions.filter { $0.kind == "shopping" && !$0.done }.count
}
