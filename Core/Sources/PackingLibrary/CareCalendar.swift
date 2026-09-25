import Foundation
import PackingCore

// The maintenance calendar: each scheduled service on the day it falls due.
//
// The web app's month view, which he said he loves: Monday first, a count on each
// day that has something due, the day coloured by the worst thing on it (overdue,
// then due soon, then fine), and a tap on a day showing what is due that day.

extension Library {
    public struct CareDay: Equatable, Sendable {
        /// "2026-09-25".
        public var ymd: String
        /// 1…31.
        public var day: Int
        /// Services falling due that day.
        public var count: Int
        /// The worst of them: "overdue", "soon", "ok" — or "" when there are none.
        public var state: String
    }

    public struct CareMonth: Equatable, Sendable {
        /// "2026-09".
        public var ym: String
        /// Empty cells before the 1st, Monday first (a month starting on a
        /// Wednesday has two).
        public var lead: Int
        public var days: [CareDay]
        /// Services already overdue, whatever month is showing — the web app flags
        /// them above the grid, because an overdue one sits in a month gone by.
        public var overdue: Int
    }

    /// One month of the calendar. `ym` is "YYYY-MM".
    public func careMonth(_ ym: String, today: String) -> CareMonth {
        let rows = careRows(today: today)
        var byDay: [String: [MaintenanceRow]] = [:]
        for row in rows where row.status.scheduled && !row.status.nextDue.isEmpty {
            byDay[row.status.nextDue, default: []].append(row)
        }

        let first = "\(ym)-01"
        let next = "\(Library.shiftMonth(ym, by: 1))-01"
        let length = daysBetween(first, next) ?? 30
        // 1970-01-01 was a Thursday: 3 days after a Monday.
        let sinceEpoch = daysBetween("1970-01-01", first) ?? 0
        let lead = ((sinceEpoch + 3) % 7 + 7) % 7

        let days = (1...max(1, length)).map { d -> CareDay in
            let ymd = String(format: "%@-%02d", ym, d)
            let due = byDay[ymd] ?? []
            let state = due.contains { $0.status.state == "overdue" } ? "overdue"
                : due.contains { $0.status.state == "soon" } ? "soon"
                : due.isEmpty ? "" : "ok"
            return CareDay(ymd: ymd, day: d, count: due.count, state: state)
        }
        return CareMonth(ym: ym, lead: lead, days: days,
                         overdue: rows.filter { $0.status.state == "overdue" }.count)
    }

    /// The services due on one day, for the list under the grid.
    public func careDue(on ymd: String, today: String) -> [MaintenanceRow] {
        careRows(today: today).filter { $0.status.scheduled && $0.status.nextDue == ymd }
    }

    /// "2026-09" moved by some months: "2026-12" + 1 = "2027-01".
    public static func shiftMonth(_ ym: String, by months: Int) -> String {
        let y = Int(ym.prefix(4)) ?? 1970
        let m = Int(ym.dropFirst(5).prefix(2)) ?? 1
        let total = y * 12 + (m - 1) + months
        return String(format: "%04d-%02d", total / 12, total % 12 + 1)
    }
}
