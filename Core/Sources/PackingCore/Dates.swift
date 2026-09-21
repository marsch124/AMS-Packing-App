// Dates — the departure countdown, trip length in nights, and the calendar behind
// the trip date picker.
// Ported from js/model.js ("Departure countdown", "The calendar behind the trip date picker").
//
// EVERYTHING HERE IS UTC, deliberately, and NOTHING reads the device's time zone or
// calendar. Dates are `YYYY-MM-DD` strings; the JS parses them as
// `Date.parse(`${s.slice(0, 10)}T00:00:00Z`)` and does whole-day arithmetic on the
// milliseconds. Build a grid from a LOCAL `new Date(y, m, d)` instead and the picker
// in one time zone hands back the day before the one that was tapped — the classic
// off-by-one that only shows up east or west of the machine it was written on.
// So there is no `Calendar`, no `TimeZone` and no `DateFormatter` in this file: a
// day count and the civil-date arithmetic below, which no device setting can shift.
//
// The one thing that DOES depend on the clock: when `todayISO` is not given, "today"
// is `new Date().toISOString().slice(0, 10)` — the UTC date, not the local one
// (`todayYMD`, through `PackingEnv.now`). In Sweden that is still yesterday until
// 01:00 (02:00 in summer). The web app has always counted that way; so does this.

import Foundation

// MARK: - Civil-date arithmetic (no Calendar, no time zone)

private let MS_PER_DAY: Double = 86_400_000

/// Floor division and its remainder (JS `Math.floor(a / b)`), for negative values too.
private func floorDiv(_ a: Int, _ b: Int) -> Int { (a >= 0 ? a : a - (b - 1)) / b }

/// Days since 1970-01-01 of a proleptic-Gregorian date (Howard Hinnant's algorithm).
private func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int {
    let y = month <= 2 ? year - 1 : year
    let era = floorDiv(y, 400)
    let yoe = y - era * 400
    let mp = month > 2 ? month - 3 : month + 9
    let doy = (153 * mp + 2) / 5 + day - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146_097 + doe - 719_468
}

/// The date of a day count — the inverse of `daysFromCivil`.
private func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
    let z = days + 719_468
    let era = floorDiv(z, 146_097)
    let doe = z - era * 146_097
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let d = doy - (153 * mp + 2) / 5 + 1
    let m = mp < 10 ? mp + 3 : mp - 9
    return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
}

private func pad(_ n: Int, _ width: Int) -> String {
    let s = String(n)
    return s.count >= width ? s : String(repeating: "0", count: width - s.count) + s
}

/// `new Date(ms).toISOString().slice(0, 10)` for a whole day count. A year outside
/// 0000–9999 is written the way JS writes it (`+010000-01-01`), and then cut at 10.
private func isoDay(_ days: Int) -> String {
    let c = civilFromDays(days)
    let year = (0...9999).contains(c.year) ? pad(c.year, 4) : (c.year < 0 ? "-" : "+") + pad(abs(c.year), 6)
    return jsSlice("\(year)-\(pad(c.month, 2))-\(pad(c.day, 2))", 0, 10)
}

/// `Date.parse(`${prefix}T00:00:00Z`)` as a DAY COUNT since 1970-01-01, or nil for NaN.
/// `prefix` is what `.slice(0, 10)` left of the date.
///
/// What the JS engine accepts in front of `T00:00:00Z` (checked against Node):
///   • `YYYY-MM-DD`, and also the shorter ISO forms `YYYY-MM` and `YYYY` (the 1st);
///   • a signed six-digit year (`+002026-08`), but not `-000000`;
///   • month 01–12, day 01–31 — 🪤 the day is NOT checked against the month, so
///     `2026-02-30` is a real date to JS: it rolls over to 2 March.
///   Anything else — `2026-8-3`, `2026/08/03`, `not a date`, non-ASCII digits — is NaN.
private func jsParseUTCDay(_ prefix: String) -> Int? {
    let u = Array(prefix.utf8)
    var i = 0
    func digits(_ n: Int) -> Int? {
        guard i + n <= u.count else { return nil }
        var v = 0
        for k in 0..<n {
            let c = u[i + k]
            guard c >= 0x30 && c <= 0x39 else { return nil }
            v = v * 10 + Int(c - 0x30)
        }
        i += n
        return v
    }
    var year: Int
    if let sign = u.first, sign == 0x2B || sign == 0x2D {
        i = 1
        guard let y = digits(6) else { return nil }
        if sign == 0x2D && y == 0 { return nil }
        year = sign == 0x2D ? -y : y
    } else {
        guard let y = digits(4) else { return nil }
        year = y
    }
    var month = 1, day = 1
    if i < u.count {
        guard u[i] == 0x2D else { return nil }
        i += 1
        guard let m = digits(2), (1...12).contains(m) else { return nil }
        month = m
        if i < u.count {
            guard u[i] == 0x2D else { return nil }
            i += 1
            guard let d = digits(2), (1...31).contains(d) else { return nil }
            day = d
        }
    }
    guard i == u.count else { return nil }
    return daysFromCivil(year, month, 1) + day - 1
}

/// `/^(\d{4})-(\d{2})$/` — ASCII digits only; the month is NOT range-checked.
private func parseMonthKey(_ key: String?) -> (year: Int, month: Int)? {
    let u = Array((key ?? "").utf8)
    guard u.count == 7, u[4] == 0x2D else { return nil }
    var year = 0, month = 0
    for (i, c) in u.enumerated() where i != 4 {
        guard c >= 0x30 && c <= 0x39 else { return nil }
        if i < 4 { year = year * 10 + Int(c - 0x30) } else { month = month * 10 + Int(c - 0x30) }
    }
    return (year, month)
}

// MARK: - Departure countdown & trip length (#4)

/// Whole days from `todayISO` to the trip's start date (negative = in the past).
/// nil when there is no start date, or either date cannot be read.
public func daysUntil(_ startDate: String?, _ todayISO: String? = nil) -> Int? {
    guard let start = startDate, !start.isEmpty else { return nil }
    let today = todayYMD(todayISO)
    guard let a = jsParseUTCDay(jsSlice(start, 0, 10)), let b = jsParseUTCDay(today) else { return nil }
    return a - b
}

public func countdownLabel(_ d: Int?) -> String {
    guard let d = d else { return "" }
    if d == 0 { return "Today" }
    if d == 1 { return "Tomorrow" }
    if d == -1 { return "Yesterday" }
    return d > 0 ? "in \(d) days" : "\(-d) days ago"
}

/// Whole nights between a start and end date (end minus start, in days). Returns
/// nil when either date is missing/invalid or the end falls before the start.
/// Same-day start and end = 0 nights (a day trip).
public func nightsBetween(_ startDate: String?, _ endDate: String?) -> Int? {
    guard let start = startDate, !start.isEmpty, let end = endDate, !end.isEmpty else { return nil }
    guard let a = jsParseUTCDay(jsSlice(start, 0, 10)), let b = jsParseUTCDay(jsSlice(end, 0, 10)) else { return nil }
    let nights = b - a
    return nights >= 0 ? nights : nil
}

/// The end date implied by a start date plus a number of nights — used to show an
/// end-date field for older events that only stored `nights`. '' with no start date.
/// (Beyond the year 275760 JS throws a RangeError; this gives ''.)
public func endFromNights(_ startDate: String?, _ nights: Double) -> String {
    guard let s = startDate, !s.isEmpty, let start = jsParseUTCDay(jsSlice(s, 0, 10)) else { return "" }
    let n = nights.isFinite && nights > 0 ? nights.rounded(.down) : 0
    let days = Double(start) + n
    guard abs(days) * MS_PER_DAY <= 8.64e15 else { return "" }
    return isoDay(Int(days))
}
/// `endFromNights` for a whole number of nights (`event.nights`).
public func endFromNights(_ startDate: String?, _ nights: Int) -> String {
    endFromNights(startDate, Double(nights))
}

// MARK: - The calendar behind the trip date picker (v125)

/// 'YYYY-MM' for a date, '' if it isn't one.
public func monthKey(_ iso: String?) -> String {
    let s = jsSlice(iso ?? "", 0, 10)
    return isYMD(s) && jsParseUTCDay(s) != nil ? jsSlice(s, 0, 7) : ""
}

/// Step a 'YYYY-MM' by whole months, rolling the year over in both directions.
/// (The month in the key is not range-checked: '2026-13' reads as January 2027, as in JS.)
public func shiftMonth(_ key: String?, _ delta: Int = 0) -> String {
    guard let k = parseMonthKey(key) else { return "" }
    // In Double, as the JS — so an absurd delta cannot trap.
    let total = Double(k.year) * 12 + Double(k.month - 1) + Double(delta)
    let year = (total / 12).rounded(.down)
    let month = total - year * 12
    func padStart(_ s: String, _ w: Int) -> String { s.count >= w ? s : String(repeating: "0", count: w - s.count) + s }
    return "\(padStart(jsNumberToString(year), 4))-\(padStart(jsNumberToString(month + 1), 2))"
}

/// `{ iso, inMonth }` — one cell of a `monthGrid`.
public struct MonthGridDay: Equatable, Hashable, Sendable {
    public var iso: String
    public var inMonth: Bool
    public init(iso: String, inMonth: Bool) { self.iso = iso; self.inMonth = inMonth }
    public var json: JSONValue { ["iso": .string(iso), "inMonth": .bool(inMonth)] }
}
/// `{ key, year, month, days }` — `month` is 0-based, as a JS Date's.
public struct MonthGrid: Equatable, Hashable, Sendable {
    public var key: String
    public var year: Int
    public var month: Int
    public var days: [MonthGridDay]
    public init(key: String = "", year: Int = 0, month: Int = 0, days: [MonthGridDay] = []) {
        self.key = key; self.year = year; self.month = month; self.days = days
    }
    public var json: JSONValue {
        ["key": .string(key), "year": .number(Double(year)), "month": .number(Double(month)),
         "days": .array(days.map { $0.json })]
    }
}

/// One month as a fixed 6×7 grid of ISO days, so every month draws the same height
/// and the panel never jumps as you page through it. `weekStart` is 1 for Monday
/// (Europe) / 0 for Sunday. Cells outside the month are still real dates — they are
/// simply marked, so a tap on one can still pick that day.
public func monthGrid(_ key: String?, _ weekStart: Int = 1) -> MonthGrid {
    guard let k = parseMonthKey(key) else { return MonthGrid() }
    let year = k.year
    let month = k.month - 1
    // `Date.UTC(year, month, 1)`: a year 0–99 means 1900 + year, and a month outside
    // 0–11 (a key like '2026-00' or '2026-13') rolls into the neighbouring year —
    // no cell of such a grid is then "in" the month, exactly as in JS.
    let fullYear = (0...99).contains(year) ? 1900 + year : year
    let months = fullYear * 12 + month
    let civilYear = floorDiv(months, 12)
    let first = daysFromCivil(civilYear, months - civilYear * 12 + 1, 1)
    let ws = weekStart == 0 ? 0 : 1
    // How many days of the previous month to show before the 1st.
    let weekday = ((first + 4) % 7 + 7) % 7                     // getUTCDay(): 1 Jan 1970 was a Thursday
    let lead = (weekday - ws + 7) % 7
    var days: [MonthGridDay] = []
    for i in 0..<42 {
        let d = first + i - lead
        days.append(MonthGridDay(iso: isoDay(d), inMonth: civilFromDays(d).month - 1 == month))
    }
    return MonthGrid(key: key ?? "", year: year, month: month, days: days)
}

/// Where one day sits in the chosen range — what the cell is painted from.
/// 'only' is a start with no end yet (and a same-day start+end), which is why it is
/// its own state rather than a start that happens to look unfinished.
public func rangeCellState(_ iso: String?, _ start: String?, _ end: String?) -> String {
    let d = jsSlice(iso ?? "", 0, 10)
    let a = jsSlice(start ?? "", 0, 10)
    let b = jsSlice(end ?? "", 0, 10)
    if d.isEmpty || a.isEmpty { return "" }
    if b.isEmpty { return d == a ? "only" : "" }
    if a == b { return d == a ? "only" : "" }
    if d == a { return "start" }
    if d == b { return "end" }
    return jsStringLess(a, d) && jsStringLess(d, b) ? "between" : ""
}

/// Two picked days in the order a trip happens. Tapping an earlier day second is a
/// correction, not an error, so it becomes the new start rather than a red warning.
/// Always two strings: [start, end] ('' = not picked).
public func orderRange(_ a: String?, _ b: String?) -> [String] {
    let x = jsSlice(a ?? "", 0, 10)
    let y = jsSlice(b ?? "", 0, 10)
    if x.isEmpty { return [y, ""] }
    if y.isEmpty { return [x, ""] }
    return !jsStringLess(y, x) ? [x, y] : [y, x]
}
