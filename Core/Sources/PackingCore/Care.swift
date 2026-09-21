// Care — care & maintenance: where every item's service schedule stands today.
// Ported from js/model.js ("Care & maintenance").
//
// A physical item can carry a care record: how to look after it (notes + a
// manufacturer/how-to link), an optional recurring service interval, when it was
// last done, and a history log. The building-block item (in a List) is the
// canonical record of the real thing, so care lives there — not on trip entries.
// (The record itself — `Maintenance`, `normalizeMaintenance` — is in Items.swift.)

import Foundation

// MARK: - Constants

/// A `{ days, label }` pair of `MAINTENANCE_INTERVALS`.
public struct MaintenanceInterval: Equatable, Hashable, Sendable {
    public var days: Int
    public var label: String
    public init(days: Int, label: String) { self.days = days; self.label = label }
}

/// Friendly interval presets offered in the editor. 0 = no recurring schedule
/// (reference-only care: notes/link but nothing to remind about).
public let MAINTENANCE_INTERVALS: [MaintenanceInterval] = [
    MaintenanceInterval(days: 0, label: "No schedule (reference only)"),
    MaintenanceInterval(days: 30, label: "Every month"),
    MaintenanceInterval(days: 90, label: "Every 3 months"),
    MaintenanceInterval(days: 182, label: "Every 6 months"),
    MaintenanceInterval(days: 365, label: "Every year"),
    MaintenanceInterval(days: 730, label: "Every 2 years"),
]
/// A due date within this many days counts as "due soon" (amber, not yet overdue).
public let MAINTENANCE_SOON_DAYS = 14
/// Everything scheduled further out than this is real, but not worth scrolling past
/// every time you open the Care tab — the list folds it away under "Later".
public let MAINTENANCE_UPCOMING_DAYS = 60

// MARK: - A calendar day, the way `Date.parse` reads one

/// `Date.parse(`${ymd}T00:00:00Z`)`, as a whole number of DAYS since 1970-01-01.
///
/// Pure arithmetic — no Calendar, no time zone, no locale: nothing on the device can
/// shift the answer by a day. It reads exactly what the JS engine reads (checked
/// against Node/V8, which the model's tests and the parity checker run on):
///  • `YYYY-MM-DD`, and also the shorter ISO forms `YYYY-MM` and `YYYY` (the 1st);
///  • a signed six-digit year (`+002026-07-30`), but never `-000000`;
///  • month 01–12 and day 01–31 — and a day the month does not have ROLLS OVER
///    ("2026-02-30" is 2 March) rather than failing. That is V8; Safari says NaN.
///    `isYMD` does not check the calendar either, so such a date can reach here;
///  • anything else — '', "2026-7-3", a full timestamp, spaces — is NaN (nil).
/// (Internal: `dowLabel` in Weather.swift and the places sort read days through it too.)
enum JSDay {
    /// `new Date(8.64e15)` is the last moment a JS Date can hold: ±100 000 000 days.
    static let maxDayNumber = 100_000_000

    static func number(_ ymd: String) -> Int? {
        let u = Array(ymd.utf8)
        var i = 0
        func digits(_ n: Int) -> Int? {
            guard i + n <= u.count else { return nil }
            var v = 0
            for k in i..<(i + n) {
                guard u[k] >= 0x30, u[k] <= 0x39 else { return nil }
                v = v * 10 + Int(u[k] - 0x30)
            }
            i += n
            return v
        }
        var year: Int
        if let sign = u.first, sign == 0x2B || sign == 0x2D {
            i = 1
            guard let y = digits(6) else { return nil }
            if sign == 0x2D { if y == 0 { return nil }; year = -y } else { year = y }
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
        let n = daysFromCivil(year, month, 1) + (day - 1)
        return abs(n) <= maxDayNumber ? n : nil
    }

    /// `new Date(dayNumber * 86400000).toISOString().slice(0, 10)`.
    /// A year outside 0000–9999 is written `+010000-…` by JS, and the cut at ten
    /// characters then lands inside it ("+010000-01") — reproduced, odd as it is.
    static func ymd(_ dayNumber: Int) -> String {
        let (y, m, d) = civilFromDays(dayNumber)
        func pad(_ v: Int, _ w: Int) -> String {
            let s = String(v)
            return s.count >= w ? s : String(repeating: "0", count: w - s.count) + s
        }
        let year = (0...9999).contains(y) ? pad(y, 4) : (y < 0 ? "-" : "+") + pad(abs(y), 6)
        return jsSlice("\(year)-\(pad(m, 2))-\(pad(d, 2))", 0, 10)
    }

    /// 0 = Sunday … 6 = Saturday (1970-01-01 was a Thursday).
    static func weekday(_ dayNumber: Int) -> Int { (((dayNumber + 4) % 7) + 7) % 7 }

    // Howard Hinnant's civil-date algorithms (proleptic Gregorian, as JS dates are).
    static func daysFromCivil(_ year: Int, _ m: Int, _ d: Int) -> Int {
        let y = m <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }
    static func civilFromDays(_ days: Int) -> (y: Int, m: Int, d: Int) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }
}

// MARK: - Date arithmetic

/// YYYY-MM-DD arithmetic, done in UTC so it never drifts by a day across timezones.
/// '' when `ymd` is not a date. (Past the end of JS time — ±100 000 000 days from
/// 1970 — the JS throws a RangeError; this gives '' there as well.)
public func addDays(_ ymd: String, _ days: Int) -> String {
    guard let t = JSDay.number(ymd) else { return "" }
    let (n, overflow) = t.addingReportingOverflow(days)
    if overflow || abs(n) > JSDay.maxDayNumber { return "" }
    return JSDay.ymd(n)
}

/// Whole days from one date to another (negative = `toYMD` is earlier); nil where JS
/// gives null — either side is not a date.
public func daysBetween(_ fromYMD: String, _ toYMD: String) -> Int? {
    guard let a = JSDay.number(fromYMD), let b = JSDay.number(toYMD) else { return nil }
    return b - a
}

// MARK: - Status

/// Does this item hold any care info worth surfacing (schedule, notes, link, or history)?
public func hasCare(_ item: Item?) -> Bool {
    guard let m = item?.maintenance else { return false }
    return m.intervalDays != 0 || !m.notes.isEmpty || !m.link.isEmpty || !m.lastDone.isEmpty || !m.log.isEmpty
}

/// Where an item's maintenance stands today — what `maintenanceStatus` answers.
public struct MaintenanceStatus: Equatable, Hashable, Sendable {
    public var scheduled: Bool
    /// 'overdue' | 'soon' | 'ok' (scheduled), or 'reference' (care notes/link but no
    /// recurring schedule).
    public var state: String
    public var nextDue: String
    /// Days until `nextDue`; negative = overdue by that many days. nil = JS null
    /// (reference-only, or a date that could not be read).
    public var days: Int?
    public var lastDone: String
    public var neverDone: Bool
    public var intervalDays: Int

    public init(scheduled: Bool = false, state: String = "reference", nextDue: String = "", days: Int? = nil,
                lastDone: String = "", neverDone: Bool = true, intervalDays: Int = 0) {
        self.scheduled = scheduled; self.state = state; self.nextDue = nextDue; self.days = days
        self.lastDone = lastDone; self.neverDone = neverDone; self.intervalDays = intervalDays
    }
    public var json: JSONValue {
        ["scheduled": .bool(scheduled), "state": .string(state), "nextDue": .string(nextDue),
         "days": days.map { JSONValue($0) } ?? .null, "lastDone": .string(lastDone),
         "neverDone": .bool(neverDone), "intervalDays": JSONValue(intervalDays)]
    }
}

/// Where an item's maintenance stands today. Returns nil for items with no care
/// record. A scheduled item never logged as done is treated as due today, and
/// flagged `neverDone` so the UI can say so.
public func maintenanceStatus(_ item: Item?, _ todayISO: String? = nil) -> MaintenanceStatus? {
    guard let m = item?.maintenance else { return nil }
    let today = todayYMD(todayISO)
    if m.intervalDays == 0 {
        return MaintenanceStatus(scheduled: false, state: "reference", nextDue: "", days: nil,
                                 lastDone: m.lastDone, neverDone: m.lastDone.isEmpty, intervalDays: 0)
    }
    let neverDone = m.lastDone.isEmpty
    let nextDue = neverDone ? today : addDays(m.lastDone, m.intervalDays)
    let days = daysBetween(today, nextDue)   // negative = overdue by that many days
    // JS compares a null day count as 0 (`null < 0` is false, `null <= 14` is true), so a
    // date that cannot be read lands in 'soon' rather than crashing.
    let d = days ?? 0
    let state = d < 0 ? "overdue" : (d <= MAINTENANCE_SOON_DAYS ? "soon" : "ok")
    return MaintenanceStatus(scheduled: true, state: state, nextDue: nextDue, days: days,
                             lastDone: m.lastDone, neverDone: neverDone, intervalDays: m.intervalDays)
}

// MARK: - The Care list

/// One row of `maintenanceList`: an item with its list context and current status.
public struct MaintenanceRow: Equatable, Hashable, Sendable {
    /// The FIRST template the item was met in (the one that names the row).
    public var listId: String
    /// Every template that holds the item, joined: "Golf, Hiking, Travel".
    public var listName: String
    public var listNames: [String]
    public var item: Item
    public var status: MaintenanceStatus

    public init(listId: String = "", listName: String = "", listNames: [String] = [],
                item: Item = Item(), status: MaintenanceStatus = MaintenanceStatus()) {
        self.listId = listId; self.listName = listName; self.listNames = listNames
        self.item = item; self.status = status
    }
    public var json: JSONValue {
        ["listId": .string(listId), "listName": .string(listName), "listNames": JSONValue(listNames),
         "item": item.json, "status": status.json]
    }
}

private let MAINT_RANK: [String: Int] = ["overdue": 0, "soon": 1, "ok": 2, "reference": 3]

/// Every item across all lists that carries care info, each with its list context
/// and current status, ordered by urgency (overdue → due soon → upcoming → reference).
public func maintenanceList(_ lists: [PackList], _ todayISO: String? = nil) -> [MaintenanceRow] {
    let today = todayYMD(todayISO)
    var out: [MaintenanceRow] = []
    // ONE ROW PER ITEM. Since v108 an item lives once in the catalogue and merely
    // appears in each template it belongs to — so a jacket filed under Golf, Hiking
    // and Travel is one jacket with one care record. Walking every template's items
    // listed it three times, Home counted "3 overdue", and pressing Done on one row
    // silently cleared the other two. The first template met names the row; the
    // rest join it as "Golf, Hiking, Travel", the way All items already reads.
    var seen: [String: Int] = [:]   // item id → its row's position in `out`
    for l in lists {
        for it in l.items {
            guard hasCare(it), let status = maintenanceStatus(it, today) else { continue }
            // An item with no id is never merged (JS: `it.id && seen.get(it.id)`).
            if !it.id.isEmpty, let at = seen[it.id] {
                if !l.name.isEmpty, !out[at].listNames.contains(l.name) {
                    out[at].listNames.append(l.name)
                    out[at].listName = out[at].listNames.joined(separator: ", ")
                }
                continue
            }
            if !it.id.isEmpty { seen[it.id] = out.count }
            out.append(MaintenanceRow(listId: l.id, listName: l.name, listNames: l.name.isEmpty ? [] : [l.name],
                                      item: it, status: status))
        }
    }
    return out.stableSorted(compare: { a, b in
        let ra = MAINT_RANK[a.status.state] ?? 9
        let rb = MAINT_RANK[b.status.state] ?? 9
        if ra != rb { return ra - rb }
        if !a.status.nextDue.isEmpty, !b.status.nextDue.isEmpty, a.status.nextDue != b.status.nextDue {
            return jsLocaleCompare(a.status.nextDue, b.status.nextDue)   // soonest due first
        }
        return jsLocaleCompare(a.item.name, b.item.name)
    })
}

/// One of the five sections the Care tab draws.
public struct CareSection: Equatable, Sendable {
    public var key: String
    public var state: String
    public var label: String
    /// A section the screen collapses by default.
    public var fold: Bool
    public var rows: [MaintenanceRow]
    public init(key: String, state: String, label: String, fold: Bool, rows: [MaintenanceRow]) {
        self.key = key; self.state = state; self.label = label; self.fold = fold; self.rows = rows
    }
    public var json: JSONValue {
        ["key": .string(key), "state": .string(state), "label": .string(label), "fold": .bool(fold),
         "rows": .array(rows.map { $0.json })]
    }
}

/// Split an ordered maintenance list into the sections the Care tab draws.
///
/// The point is scrolling: "Overdue" and "Due soon" are what you act on, so they
/// stay open; a service eight months out is real but is not today's business, so it
/// folds. `fold: true` marks a section the screen collapses by default.
///
/// `upcomingDays` is where the fold starts, measured from today — anything due
/// further out than that drops from "Upcoming" into "Later" (and so does a row with
/// no day count). Rows keep the order they arrived in, so maintenanceList's urgency
/// sort still governs inside a section. `nil` rows read as none.
public func careSections(_ rows: [MaintenanceRow]?, _ upcomingDays: Int = MAINTENANCE_UPCOMING_DAYS) -> [CareSection] {
    let all = rows ?? []
    func byState(_ s: String) -> [MaintenanceRow] { all.filter { $0.status.state == s } }
    func isNear(_ r: MaintenanceRow) -> Bool {
        guard let d = r.status.days else { return false }
        return d <= upcomingDays
    }
    let scheduledOk = byState("ok")
    return [
        CareSection(key: "overdue", state: "overdue", label: "Overdue", fold: false, rows: byState("overdue")),
        CareSection(key: "soon", state: "soon", label: "Due soon", fold: false, rows: byState("soon")),
        CareSection(key: "upcoming", state: "ok", label: "Upcoming", fold: false, rows: scheduledOk.filter { isNear($0) }),
        CareSection(key: "later", state: "ok", label: "Later", fold: true, rows: scheduledOk.filter { !isNear($0) }),
        CareSection(key: "reference", state: "reference", label: "Reference only (no schedule)", fold: true,
                    rows: byState("reference")),
    ]
}

/// Headline counts for the Care tab and the Home reminder.
public struct MaintenanceSummary: Equatable, Hashable, Sendable {
    public var overdue: Int
    public var soon: Int
    public var ok: Int
    public var reference: Int
    /// overdue + soon + ok
    public var scheduled: Int
    public var total: Int
    /// overdue + soon
    public var due: Int
    public init(overdue: Int = 0, soon: Int = 0, ok: Int = 0, reference: Int = 0, scheduled: Int = 0,
                total: Int = 0, due: Int = 0) {
        self.overdue = overdue; self.soon = soon; self.ok = ok; self.reference = reference
        self.scheduled = scheduled; self.total = total; self.due = due
    }
    public var json: JSONValue {
        ["overdue": JSONValue(overdue), "soon": JSONValue(soon), "ok": JSONValue(ok),
         "reference": JSONValue(reference), "scheduled": JSONValue(scheduled), "total": JSONValue(total),
         "due": JSONValue(due)]
    }
}

public func maintenanceSummary(_ lists: [PackList], _ todayISO: String? = nil) -> MaintenanceSummary {
    let all = maintenanceList(lists, todayISO)
    func count(_ s: String) -> Int { all.filter { $0.status.state == s }.count }
    let overdue = count("overdue")
    let soon = count("soon")
    return MaintenanceSummary(overdue: overdue, soon: soon, ok: count("ok"), reference: count("reference"),
                              scheduled: overdue + soon + count("ok"), total: all.count, due: overdue + soon)
}

/// One entry of `maintenanceByDate`: a next-due date and the rows that fall on it.
public struct MaintenanceDateBucket: Equatable, Sendable {
    public var date: String
    public var rows: [MaintenanceRow]
    public init(date: String, rows: [MaintenanceRow]) { self.date = date; self.rows = rows }
    public var json: JSONValue { ["date": .string(date), "rows": .array(rows.map { $0.json })] }
}

/// Scheduled items bucketed by their next-due date (YYYY-MM-DD) — powers the calendar.
/// JS returns a Map; this is its entries IN INSERTION ORDER (the order each date is
/// first met in `maintenanceList`, so most urgent first) — look a date up with
/// `first { $0.date == … }`.
public func maintenanceByDate(_ lists: [PackList], _ todayISO: String? = nil) -> [MaintenanceDateBucket] {
    var out: [MaintenanceDateBucket] = []
    var at: [String: Int] = [:]
    for row in maintenanceList(lists, todayISO) {
        if !row.status.scheduled || row.status.nextDue.isEmpty { continue }
        if let i = at[row.status.nextDue] {
            out[i].rows.append(row)
        } else {
            at[row.status.nextDue] = out.count
            out.append(MaintenanceDateBucket(date: row.status.nextDue, rows: [row]))
        }
    }
    return out
}

/// Record that an item was maintained on `dateYMD` (default today), appending to
/// its history and resetting the schedule. Mutates and returns the item; creates
/// the care record if the item didn't have one.
///
/// NOTE, as in the JS: `lastDone` becomes THIS date even when a later service is
/// already in the log — logging a forgotten old service moves the schedule back.
@discardableResult
public func logMaintenance(_ item: inout Item, _ dateYMD: String? = nil, _ note: String = "",
                           _ todayISO: String? = nil) -> Item {
    let date = isYMD(dateYMD) ? (dateYMD ?? "") : todayYMD(todayISO)
    var base = normalizeMaintenance(item.maintenance) ?? Maintenance()
    base.log = (base.log + [MaintenanceLogEntry(date: date, note: note)])
        .stableSorted(compare: { a, b in jsLocaleCompare(a.date, b.date) })
    base.lastDone = date
    item.maintenance = normalizeMaintenance(base)
    return item
}
