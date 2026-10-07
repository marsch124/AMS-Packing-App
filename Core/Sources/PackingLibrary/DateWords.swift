import Foundation
import PackingCore

// How far away a date is, in words — their field test (Oct 2026), on a
// thing's Valid until: "It didn't say 10 days. You have to calculate that
// yourself. Maybe we could add that information visually."
//
// The words never promise MORE time than is left: each unit is counted in whole
// ones, rounded down. A passport is judged six months ahead, so one that runs out
// in five and a half months must read "in 5 months", never "in 6 months".
// And a quick choice reads back as itself: +1 month says "in 1 month", +1 year
// "in 1 year", from any day of the year (the end of January included).

/// "2027-01-31" plus one month is "2027-02-28": a day the month lacks becomes its
/// last, so a month on is never pushed into the month after. '' when `ymd` is not
/// a YYYY-MM-DD date.
public func addMonths(_ ymd: String, _ months: Int) -> String {
    guard let (y, m, d) = civil(ymd) else { return "" }
    let total = y * 12 + (m - 1) + months
    let year = total >= 0 ? total / 12 : (total - 11) / 12
    let month = total - year * 12 + 1
    guard (0...9999).contains(year) else { return "" }
    return String(format: "%04d-%02d-%02d", year, month, min(d, daysIn(year, month)))
}

/// "in 10 days", "in 3 weeks", "in 4 months", "in 2 years", "today", "tomorrow",
/// "3 days ago (out of date)". '' when either side is not a date.
public func distanceWords(from today: String, to ymd: String) -> String {
    guard civil(today) != nil, civil(ymd) != nil, let days = daysBetween(today, ymd) else { return "" }
    switch days {
    case 0: return "today"
    case 1: return "tomorrow"
    case -1: return "yesterday (out of date)"
    case ..<0: return "\(span(from: ymd, to: today, days: -days)) ago (out of date)"
    default: return "in \(span(from: today, to: ymd, days: days))"
    }
}

/// Two days or more, in the largest unit that fits whole:
/// under two weeks in days; under two months in weeks (a month and up to four weeks
/// more reads "1 month" — "4 weeks" right after "+1 month" would puzzle); under a
/// year in months; then years.
private func span(from a: String, to b: String, days: Int) -> String {
    if days < 14 { return "\(days) days" }
    let months = wholeMonths(from: a, to: b)
    if months < 2 {
        let weeks = days / 7
        return months == 1 && weeks < 5 ? "1 month" : "\(weeks) weeks"
    }
    if months < 12 { return "\(months) months" }
    let years = months / 12
    return years == 1 ? "1 year" : "\(years) years"
}

/// Whole calendar months from one day to a later one: the most `k` for which
/// `addMonths(a, k)` is not past `b`.
func wholeMonths(from a: String, to b: String) -> Int {
    guard let (y1, m1, _) = civil(a), let (y2, m2, _) = civil(b) else { return 0 }
    var k = max(0, (y2 * 12 + m2) - (y1 * 12 + m1))
    while k > 0 && addMonths(a, k) > b { k -= 1 }
    return k
}

/// A date typed on the Mac's keys (0.68, a thing's Valid until), answered as
/// YYYY-MM-DD: "2027-06-30"; day and month first as Sweden writes them — "30/6 27",
/// "30/6/2027", "30.6.27" — or without a year, "30/6" (the next 30 June from today); or a
/// jump from today — "+6m", "+1y", "+10y", "+2w", "+30d" (a month on keeps the day, or
/// the month's last: `addMonths`). "" for nothing typed (no date); nil for anything
/// else, a day the month lacks included ("31/6"), so the page can say so.
public func readDate(_ typed: String, today: String) -> String? {
    let s = jsTrim(typed).lowercased()
    if s.isEmpty { return "" }
    guard civil(today) != nil else { return nil }
    if s.hasPrefix("+") {
        let rest = s.dropFirst().trimmingCharacters(in: .whitespaces)
        let digits = rest.prefix { $0.isASCII && $0.isNumber }
        let unit = rest.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        guard !digits.isEmpty, digits.count <= 4, let n = Int(digits) else { return nil }
        let out: String
        switch unit {
        case "d", "day", "days": out = addDays(today, n)
        case "w", "week", "weeks": out = addDays(today, 7 * n)
        case "m", "month", "months": out = addMonths(today, n)
        case "y", "year", "years": out = addMonths(today, 12 * n)
        default: return nil
        }
        return out.isEmpty ? nil : out
    }
    let parts = s.split(whereSeparator: { "/.- ".contains($0) }).map(String.init)
    guard (2...3).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return nil }
    var y: Int, m: Int, d: Int
    if parts[0].count == 4 {
        // Year first: 2027-06-30 (or 2027/6/30).
        guard parts.count == 3, let yy = Int(parts[0]), let mm = Int(parts[1]), let dd = Int(parts[2]),
              parts[1].count <= 2, parts[2].count <= 2 else { return nil }
        (y, m, d) = (yy, mm, dd)
    } else {
        guard parts[0].count <= 2, parts[1].count <= 2, let dd = Int(parts[0]), let mm = Int(parts[1]) else { return nil }
        (d, m) = (dd, mm)
        if parts.count == 3 {
            let year = parts[2]
            guard year.count == 2 || year.count == 4, let yy = Int(year) else { return nil }
            y = year.count == 2 ? 2000 + yy : yy
        } else {
            // No year: this year's, or the next year's once this year's has gone by
            // (29 February: the next year that has one; "31/6" never comes).
            guard let (ty, _, _) = civil(today), (1...12).contains(m), (1...31).contains(d) else { return nil }
            y = ty
            var tries = 0
            while d > daysIn(y, m) || String(format: "%04d-%02d-%02d", y, m, d) < today {
                y += 1; tries += 1
                if tries > 8 { return nil }
            }
        }
    }
    guard (1...9999).contains(y), (1...12).contains(m), (1...daysIn(y, m)).contains(d) else { return nil }
    return String(format: "%04d-%02d-%02d", y, m, d)
}

/// "2026-10-03" → (2026, 10, 3); nil unless it is exactly YYYY-MM-DD.
private func civil(_ ymd: String) -> (Int, Int, Int)? {
    let p = ymd.split(separator: "-", omittingEmptySubsequences: false)
    guard ymd.count == 10, p.count == 3, p[0].count == 4, p[1].count == 2, p[2].count == 2,
          let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]),
          (1...12).contains(m), (1...31).contains(d) else { return nil }
    return (y, m, d)
}

private func daysIn(_ year: Int, _ month: Int) -> Int {
    switch month {
    case 2: return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
    case 4, 6, 9, 11: return 30
    default: return 31
    }
}
