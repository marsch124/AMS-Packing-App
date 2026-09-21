// JSSemantics — the places where JavaScript and Swift quietly disagree.
//
// The port has to give the SAME ANSWERS as js/model.js, so every spot where the
// two languages differ goes through one helper here, and is fixed once.

import Foundation

// MARK: - Whitespace, trim, normName

/// What JS counts as whitespace — in `trim()` and in the regex class `\s`.
/// NOT the same set as Foundation's `.whitespacesAndNewlines`: JS includes U+FEFF
/// (the byte-order mark) and leaves out U+0085.
public func jsIsWhitespace(_ u: Unicode.Scalar) -> Bool {
    switch u.value {
    case 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0xA0, 0x1680,
         0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
        return true
    default:
        return false
    }
}

/// `s.trim()`
public func jsTrim(_ s: String) -> String {
    let scalars = s.unicodeScalars
    var start = scalars.startIndex
    var end = scalars.endIndex
    while start < end, jsIsWhitespace(scalars[start]) { start = scalars.index(after: start) }
    while end > start, jsIsWhitespace(scalars[scalars.index(before: end)]) { end = scalars.index(before: end) }
    return String(scalars[start..<end])
}

/// `s.replace(/\s+/g, ' ')` — every run of whitespace becomes ONE space.
public func jsCollapseWhitespace(_ s: String) -> String {
    var out = String.UnicodeScalarView()
    var inRun = false
    for u in s.unicodeScalars {
        if jsIsWhitespace(u) {
            if !inRun { out.append(" "); inRun = true }
        } else {
            out.append(u); inRun = false
        }
    }
    return String(out)
}

/// `normName` — trim, lowercase, collapse whitespace runs to one space. The key two
/// spellings of the same name are compared by, everywhere in the app.
public func normName(_ s: String?) -> String {
    jsCollapseWhitespace(jsTrim(s ?? "").lowercased())
}

// MARK: - slice (UTF-16 units, as JS counts them)

/// `str.slice(start, end)`. Counts UTF-16 units, NOT Characters, and takes negative
/// indices from the end. A cut that lands in the middle of a surrogate pair would
/// leave JS holding half a character, which a Swift String cannot represent — the
/// broken half is dropped.
public func jsSlice(_ s: String, _ start: Int, _ end: Int? = nil) -> String {
    let units = Array(s.utf16)
    let n = units.count
    func clamp(_ i: Int) -> Int { i < 0 ? max(n + i, 0) : min(i, n) }
    var from = clamp(start)
    var to = clamp(end ?? n)
    guard from < to else { return "" }
    if from == 0 && to == n { return s }
    if UTF16.isTrailSurrogate(units[from]) { from += 1 }
    if to > from, UTF16.isLeadSurrogate(units[to - 1]) { to -= 1 }
    guard from < to else { return "" }
    return String(decoding: units[from..<to], as: UTF16.self)
}

/// `str.length`
public func jsLength(_ s: String) -> Int { s.utf16.count }

/// `a < b` on two JS strings: by UTF-16 unit, NOT by Swift's Unicode ordering.
/// (For the ASCII dates and ranks the app compares, both agree — this is the safe form.)
public func jsStringLess(_ a: String, _ b: String) -> Bool {
    a.utf16.lexicographicallyPrecedes(b.utf16)
}

// MARK: - Dates as strings

/// A calendar date in YYYY-MM-DD form — `/^\d{4}-\d{2}-\d{2}$/` (ASCII digits only;
/// it does NOT check that the month or day exist, and neither does the JS).
public func isYMD(_ s: String?) -> Bool {
    guard let s = s else { return false }
    let u = Array(s.utf8)
    guard u.count == 10 else { return false }
    for (i, c) in u.enumerated() {
        if i == 4 || i == 7 { if c != 0x2D { return false } }
        else if c < 0x30 || c > 0x39 { return false }
    }
    return true
}
public func isYMD(_ v: JSONValue?) -> Bool { isYMD(v?.stringValue) }

/// `(todayISO || new Date().toISOString()).slice(0, 10)`
public func todayYMD(_ todayISO: String? = nil) -> String {
    let t = (todayISO ?? "").isEmpty ? nowISO() : (todayISO ?? "")
    return jsSlice(t, 0, 10)
}

/// `date.toISOString()` — always UTC, always milliseconds: 2026-08-20T12:00:00.000Z
public func jsISOString(_ date: Date) -> String {
    let ms = Int64((date.timeIntervalSince1970 * 1000).rounded(.down))
    let dayMs: Int64 = 86_400_000
    var days = ms / dayMs
    var rem = ms % dayMs
    if rem < 0 { rem += dayMs; days -= 1 }
    // Civil date from a day count (Howard Hinnant's algorithm) — no Calendar, no
    // time zone, no locale: nothing on the device can shift the answer by a day.
    let z = days + 719_468
    let era = (z >= 0 ? z : z - 146_096) / 146_097
    let doe = z - era * 146_097
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let d = doy - (153 * mp + 2) / 5 + 1
    let m = mp < 10 ? mp + 3 : mp - 9
    let y = yoe + era * 400 + (m <= 2 ? 1 : 0)
    func pad(_ v: Int64, _ w: Int) -> String {
        let s = String(v)
        return s.count >= w ? s : String(repeating: "0", count: w - s.count) + s
    }
    return "\(pad(y, 4))-\(pad(m, 2))-\(pad(d, 2))T\(pad(rem / 3_600_000, 2)):\(pad(rem / 60_000 % 60, 2)):\(pad(rem / 1000 % 60, 2)).\(pad(rem % 1000, 3))Z"
}

// MARK: - Numbers

/// `Math.round` — a half rounds UP (towards +∞): 2.5 → 3, -2.5 → -2.
/// Swift's `.rounded()` rounds a half AWAY from zero, which is a different answer.
public func jsRound(_ x: Double) -> Double {
    let r = x.rounded(.down)
    return (x - r >= 0.5) ? r + 1 : r
}

/// A finite Double as an Int without trapping on a huge value.
public func jsInt(_ x: Double) -> Int {
    guard x.isFinite else { return 0 }
    if x >= 9.2e18 { return Int.max }
    if x <= -9.2e18 { return Int.min }
    return Int(x)
}
/// `Math.round(x)` as an Int.
public func jsRoundInt(_ x: Double) -> Int { jsInt(jsRound(x)) }
/// `Math.floor(x)` as an Int.
public func jsFloorInt(_ x: Double) -> Int { jsInt(x.rounded(.down)) }

/// `String(n)` for a number: a whole number has no ".0"; NaN and Infinity by name.
public func jsNumberToString(_ n: Double) -> String {
    if n.isNaN { return "NaN" }
    if n.isInfinite { return n < 0 ? "-Infinity" : "Infinity" }
    if n == 0 { return "0" }
    if n == n.rounded(), abs(n) < 1e21 { return String(format: "%.0f", n) }
    return "\(n)"
}

/// `Number(str)` — trims, reads '' as 0, and is NaN for anything with junk in it
/// ("12px"), unlike `parseFloat`.
public func jsParseNumber(_ raw: String) -> Double {
    let s = jsTrim(raw)
    if s.isEmpty { return 0 }
    if s == "Infinity" || s == "+Infinity" { return .infinity }
    if s == "-Infinity" { return -.infinity }
    let lower = s.lowercased()
    for (prefix, radix) in [("0x", 16), ("0o", 8), ("0b", 2)] where lower.hasPrefix(prefix) {
        guard let v = UInt64(lower.dropFirst(2), radix: radix) else { return .nan }
        return Double(v)
    }
    // Swift's Double("…") also accepts "nan", "inf" and hex floats, which JS does not.
    let allowed = Set("0123456789+-.eE")
    guard s.allSatisfy({ allowed.contains($0) }) else { return .nan }
    return Double(s) ?? .nan
}

/// `n.toString(36)` for a non-negative whole number (ids and timestamps).
public func jsBase36(_ n: Int64) -> String { String(n, radix: 36) }

// MARK: - Sorting

/// The sign of a JS comparator's result: negative → -1, positive → 1, 0 and NaN → 0.
public func jsSign(_ d: Double) -> Int { d < 0 ? -1 : (d > 0 ? 1 : 0) }

/// `a || b` between two comparator results: the first one that is not 0.
public func jsOr(_ a: Int, _ b: @autoclosure () -> Int) -> Int { a != 0 ? a : b() }

extension Sequence {
    /// `Array.prototype.sort` is STABLE; Swift's `sort` does not promise to be.
    /// Always sort through one of these two.
    public func stableSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
        enumerated().sorted { a, b in
            if areInIncreasingOrder(a.element, b.element) { return true }
            if areInIncreasingOrder(b.element, a.element) { return false }
            return a.offset < b.offset
        }.map { $0.element }
    }

    /// The JS form: `compare(a, b)` is negative when `a` comes first, 0 for a tie.
    public func stableSorted(compare: (Element, Element) -> Int) -> [Element] {
        enumerated().sorted { a, b in
            let c = compare(a.element, b.element)
            return c != 0 ? c < 0 : a.offset < b.offset
        }.map { $0.element }
    }
}

// MARK: - localeCompare

public enum JSCollatorSensitivity: Sendable {
    /// The default: case and accents both count ("a" < "A", "a" < "á").
    case variant
    /// `{ sensitivity: 'base' }`: "a", "A" and "á" are all equal.
    case base
}

/// `a.localeCompare(b)` → -1, 0 or 1.
///
/// In JS this is ICU collation in the runtime's locale — NOT `<`: "a" sorts before
/// "B", and "co-op" before "coop". THE ONE PLACE this is decided, so it can be tuned
/// once when the parity checker runs over his Swedish names (å ä ö): change
/// `PackingEnv.collationLocale`, nothing else.
public func jsLocaleCompare(_ a: String, _ b: String, sensitivity: JSCollatorSensitivity = .variant) -> Int {
    if a == b { return 0 }
    let options: String.CompareOptions = sensitivity == .base ? [.caseInsensitive, .diacriticInsensitive] : []
    let r = a.compare(b, options: options, range: nil, locale: PackingEnv.collationLocale)
    switch r {
    case .orderedAscending: return -1
    case .orderedDescending: return 1
    case .orderedSame: return 0
    }
}

// MARK: - Small regex stand-ins

/// `/^#[0-9a-fA-F]{3,8}$/` — what the app accepts as a colour.
public func isHexColor(_ s: String?) -> Bool {
    guard let s = s else { return false }
    let u = Array(s.utf8)
    guard (4...9).contains(u.count), u[0] == 0x23 else { return false }
    return u.dropFirst().allSatisfy { ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x41 && $0 <= 0x46) || ($0 >= 0x61 && $0 <= 0x66) }
}

/// The id a new phase or condition earns from its name:
/// `trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 24)`
public func jsSlug(_ label: String, max: Int = 24) -> String {
    var out = ""
    var pendingDash = false
    for u in jsTrim(label).lowercased().unicodeScalars {
        let ok = (u.value >= 0x61 && u.value <= 0x7A) || (u.value >= 0x30 && u.value <= 0x39)
        if ok {
            if pendingDash && !out.isEmpty { out.append("-") }
            pendingDash = false
            out.unicodeScalars.append(u)
        } else {
            pendingDash = true
        }
    }
    // NOTE the order, as in the JS: dashes are stripped from the ends BEFORE the cut,
    // so a name longer than 24 can still end in a dash.
    return jsSlice(out, 0, max)
}
