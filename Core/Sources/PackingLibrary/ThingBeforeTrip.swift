import PackingCore

// "Before a trip" on a thing's page (0.104 — his mix of sketches A and C, 28 Oct 2026: "A mix of A
// and folded as C"). One frame after Name and Notes holds Battery, Also pack, Remember, On a plane
// and Valid until; folded, it is ONE line that says what is set — this file's words, in the frame's
// own order. The page passes what it HOLDS (the draft, not the stored thing): a switch pressed and
// not saved yet is said too.

public enum BeforeATrip {
    /// Folded with nothing set.
    public static let nothing = "Nothing set"

    /// "Battery · Also pack Charger · 1 reminder · Liquid · Not in the cabin · until 30 Jun 2027";
    /// "Nothing set" when none of it is. One thing packed with it is named, more are counted ("Also
    /// pack 2 things" — the line must stay ONE line on an iPhone); a date already past says "ran out
    /// 3 Oct 2026".
    public static func summary(battery: Bool, alsoPack: [String], reminders: Int, liquid: Bool,
                               notInCabin: Bool, validUntil: String, today: String) -> String {
        var parts: [String] = []
        if battery { parts.append("Battery") }
        let names = alsoPack.map(jsTrim).filter { !$0.isEmpty }
        if let first = names.first {
            parts.append("Also pack " + (names.count == 1 ? first : "\(names.count) things"))
        }
        if reminders > 0 { parts.append(reminders == 1 ? "1 reminder" : "\(reminders) reminders") }
        if liquid { parts.append("Liquid") }
        if notInCabin { parts.append("Not in the cabin") }
        if isYMD(validUntil) {
            let past = isYMD(today) && jsStringLess(validUntil, today)
            parts.append((past ? "ran out " : "until ") + dayWords(validUntil))
        }
        return parts.isEmpty ? nothing : parts.joined(separator: " \u{00B7} ")
    }

    /// "2027-06-30" → "30 Jun 2027" (a day that is no date is said as it is).
    public static func dayWords(_ ymd: String) -> String {
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        guard isYMD(ymd), p.count == 3, (1...12).contains(p[1]) else { return ymd }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(p[2]) \(months[p[1] - 1]) \(p[0])"
    }

    /// The short hint on Valid until's own line: a document is judged six months past the trip
    /// (`DOCUMENT_MONTHS_LEFT`), anything else by the day the trip ends.
    public static func validUntilHint(category: String) -> String {
        category == DOCUMENTS_CATEGORY ? "warns \(DOCUMENT_MONTHS_LEFT) months ahead" : "warns before it runs out"
    }
}
