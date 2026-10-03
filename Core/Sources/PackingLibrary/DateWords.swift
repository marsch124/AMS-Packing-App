import Foundation
import PackingCore

// How far away a date is, in words — his and Anna's field test (Oct 2026), on a
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
