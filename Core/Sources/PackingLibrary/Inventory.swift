import Foundation
import PackingCore

// The inventory, step 1 (0.115 — his plan and 32 answers of 11 Nov 2026, docs/inventory/plan.md):
// details for each thing, rooms, things that stay at home, a value today, warranty and the Swedish
// three-year complaint right, and totals. Kept in fields the model already had (price, currency,
// acquired, serial, warranty, qtyOwned, model, manufacturer, storage) and, for what is new, in the
// thing's `extra` — so a backup and the web app carry it through untouched.

/// Rooms offered under "Kept at home" after his own places, until he picks one (it then joins his
/// list on Save — nothing is ever seeded). His picks: a Swedish home, plus Car, Cellar and Work.
public let STARTER_ROOMS: [String] = [
    "Hall", "Kitchen", "Living room", "Bedroom", "Office", "Bathroom", "Laundry",
    "Storage", "Garage", "Attic", "Cellar", "Car", "At work",
]

/// Warranty lengths offered as chips, in years (his pick: a length from the bought date).
public let WARRANTY_YEARS: [Int] = [1, 2, 3, 5]

public let STAYS_HOME_KEY = "staysHome"
public let SPOT_KEY = "spot"
public let SHOP_KEY = "shop"
public let VALUE_NOW_KEY = "valueNow"

/// What one thing is worth, counted for the totals.
public struct InventoryTotals: Equatable, Sendable {
    /// Things counted (a set of 6 glasses is one thing).
    public var things = 0
    /// Paid, in kronor: price per piece × how many — SEK things only.
    public var paid = 0.0
    /// Worth today, in kronor — SEK things only.
    public var today = 0.0
    /// Things with a price in a currency the rates do not know, left out of the sums (0.121: a known
    /// foreign currency is counted at today's rate).
    public var otherCurrency = 0
    /// Things with a price in another currency that WERE counted, at today's rates (0.121).
    public var converted = 0
    public init() {}
}

extension Library {
    // MARK: Stays at home

    /// A thing that never travels (sofa, drill, TV): never offered on a trip, a template or ＋ Add.
    public static func staysHome(_ it: Item) -> Bool { it.extra[STAYS_HOME_KEY]?.boolValue == true }
    public static func setStaysHome(_ it: inout Item, _ on: Bool) { it.extra[STAYS_HOME_KEY] = on ? .bool(true) : nil }

    // MARK: Room ▸ spot

    /// Where in the room: "Top shelf", "Box 3" — typed.
    public static func spot(_ it: Item) -> String { it.extra[SPOT_KEY]?.stringValue ?? "" }
    public static func setSpot(_ it: inout Item, _ s: String) {
        let t = jsTrim(s); it.extra[SPOT_KEY] = t.isEmpty ? nil : .string(t)
    }

    /// The rooms "Kept at home" offers: his places, then the starter rooms he does not have yet.
    public func roomChoices() -> [String] {
        let mine = storagePlaces()
        let have = Set(mine.map(normName))
        return mine + STARTER_ROOMS.filter { !have.contains(normName($0)) }
    }

    /// A starter room picked on a page joins his places (on Save) — one he has already is left be.
    public mutating func keepRoom(_ room: String) {
        let clean = jsTrim(room)
        guard !clean.isEmpty, !storagePlaces().contains(where: { normName($0) == normName(clean) }) else { return }
        _ = addChoice("places", clean)
    }

    /// Spots used before in this room, matching what is typed (blank = all), A–Z, each once.
    public func spotSuggestions(room: String, typed: String, limit: Int = 4) -> [String] {
        let r = normName(room), needle = normName(typed)
        var seen = Set<String>(), out: [String] = []
        for it in items where normName(it.storage) == r {
            let s = Library.spot(it), k = normName(s)
            guard !s.isEmpty, k != needle, needle.isEmpty || k.contains(needle), seen.insert(k).inserted else { continue }
            out.append(s)
        }
        return Array(out.sorted { jsLocaleCompare($0, $1) < 0 }.prefix(limit))
    }

    // MARK: Shop

    public static func shop(_ it: Item) -> String { it.extra[SHOP_KEY]?.stringValue ?? "" }
    public static func setShop(_ it: inout Item, _ s: String) {
        let t = jsTrim(s); it.extra[SHOP_KEY] = t.isEmpty ? nil : .string(t)
    }

    /// Shops he used before, matching what is typed, A–Z, each once — never the very words typed.
    public func shopSuggestions(typed: String, limit: Int = 4) -> [String] {
        let needle = normName(typed)
        guard !needle.isEmpty else { return [] }
        var seen = Set<String>(), out: [String] = []
        for it in items {
            let s = Library.shop(it), k = normName(s)
            guard !s.isEmpty, k != needle, k.contains(needle), seen.insert(k).inserted else { continue }
            out.append(s)
        }
        return Array(out.sorted { jsLocaleCompare($0, $1) < 0 }.prefix(limit))
    }

    // MARK: Value today

    /// His own figure for what it is worth now, per piece; nil = not set (the estimate is used).
    public static func valueSet(_ it: Item) -> Double? {
        if case .number(let v)? = it.extra[VALUE_NOW_KEY] { return v }
        return nil
    }
    public static func setValue(_ it: inout Item, _ v: Double?) { it.extra[VALUE_NOW_KEY] = v.map { .number($0) } }

    /// What a piece is worth today: his own figure, else the price less 15 % for each year since it
    /// was bought, never below 10 % of the price (his pick). No price: nil.
    public static func valueToday(_ it: Item, today: String) -> Double? {
        if let mine = valueSet(it) { return mine }
        guard it.price > 0 else { return nil }
        let years = Library.yearsBetween(it.acquired, today)
        return (it.price * max(0.10, pow(0.85, years))).rounded()
    }

    // MARK: Warranty and the complaint right

    /// The last day of a warranty `years` long from the bought date ("" without a bought date).
    public static func warrantyEnd(bought: String, years: Int) -> String {
        guard isYMD(bought), years > 0 else { return "" }
        return Library.addYears(bought, years)
    }

    /// The length the chips show lit: the warranty ending exactly 1, 2, 3 or 5 years after it was bought.
    public static func warrantyYears(_ it: Item) -> Int? {
        guard isYMD(it.warranty) else { return nil }
        return WARRANTY_YEARS.first { warrantyEnd(bought: it.acquired, years: $0) == it.warranty }
    }

    /// The Swedish three-year complaint right (reklamationsrätt) — shown quietly on a thing that has a
    /// bought date and no warranty of its own; "" otherwise.
    public static func complaintRightUntil(_ it: Item) -> String {
        guard isYMD(it.acquired), !isYMD(it.warranty) else { return "" }
        return addYears(it.acquired, 3)
    }

    /// "1 year 4 months left", "12 days left", "Ended" — from today to `end`.
    public static func timeLeft(until end: String, today: String) -> String {
        guard isYMD(end), isYMD(today) else { return "" }
        let cal = Calendar(identifier: .gregorian)
        guard let a = ymdDate(today), let b = ymdDate(end) else { return "" }
        if b < a { return "Ended" }
        let c = cal.dateComponents([.year, .month, .day], from: a, to: b)
        let y = c.year ?? 0, m = c.month ?? 0, d = c.day ?? 0
        func n(_ v: Int, _ w: String) -> String { "\(v) \(w)\(v == 1 ? "" : "s")" }
        if y > 0 { return (m > 0 ? "\(n(y, "year")) \(n(m, "month"))" : n(y, "year")) + " left" }
        if m > 0 { return n(m, "month") + " left" }
        return d == 0 ? "Ends today" : n(d, "day") + " left"
    }

    // MARK: Totals and views

    /// Counted things, what they cost and what they are worth today — pieces × count, in kronor. A price
    /// in another currency counts at the rates' value (0.121); one in a currency they do not know is
    /// left out (`otherCurrency`). Gone things are never counted (0.121).
    public static func totals(_ things: [Item], today: String, rates: CurrencyRates = .current) -> InventoryTotals {
        var t = InventoryTotals()
        for it in things where !isGone(it) {
            t.things += 1
            guard it.price > 0 || valueSet(it) != nil else { continue }
            guard let one = rates.inKronor(1, it.currency) else { t.otherCurrency += 1; continue }
            if CurrencyRates.code(it.currency) != "SEK" { t.converted += 1 }
            let n = Double(max(1, it.qtyOwned))
            t.paid += it.price * one * n
            t.today += (valueToday(it, today: today) ?? 0) * one * n
        }
        return t
    }

    /// Search that also finds brand, model, serial, shop and spot (0.115).
    public static func detailsMatch(_ it: Item, _ q: String) -> Bool {
        let needle = normName(q)
        guard !needle.isEmpty else { return false }
        return [it.manufacturer, it.model, it.serial, shop(it), spot(it), it.storage]
            .contains { normName($0).contains(needle) }
    }

    // MARK: Dates

    /// A stored day as a date on this device's calendar (for a date picker); nil for "".
    public static func ymdDay(_ s: String) -> Date? {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard isYMD(s), p.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12))
    }
    /// A picked date as the stored day.
    public static func ymd(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }
    /// "3 Mar 2027".
    public static func dayWords(_ s: String) -> String {
        guard let d = ymdDay(s) else { return s }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "d MMM yyyy"
        return f.string(from: d)
    }

    static func ymdDate(_ s: String) -> Date? {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        var c = DateComponents(); c.year = p[0]; c.month = p[1]; c.day = p[2]
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: c)
    }

    static func addYears(_ ymd: String, _ years: Int) -> String {
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return "" }
        let y = p[0] + years, m = p[1]
        // 29 Feb + 1 year = 28 Feb.
        let d = (m == 2 && p[2] == 29 && !(y % 4 == 0 && (y % 100 != 0 || y % 400 == 0))) ? 28 : p[2]
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func yearsBetween(_ from: String, _ to: String) -> Double {
        guard let a = ymdDate(from), let b = ymdDate(to), b > a else { return 0 }
        return b.timeIntervalSince(a) / (365.25 * 86_400)
    }
}
