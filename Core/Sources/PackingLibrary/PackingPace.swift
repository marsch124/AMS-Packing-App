import Foundation
import PackingCore

// Progress you can see (spec 07 part 20) — his words of 14 Oct 2026, from his own packing
// walk-through: "once a WET, GA, Template is finished I would like to enjoy a green checkbox or
// green colour somewhere showing me a good progress — but also indicating how much is left. Both
// in items, charging, actual packing time etc."
//
// The green ring per group is the screen's alone (it reads the heading's own count). Here is
// what the line under the trip's count says — "23 left · 2 to charge · about 25 min" — and the
// rule the time is estimated by: HIS pace, measured from his own ticks.
//
// WHERE IT IS KEPT: every tick writes its moment on the line's own record, extra key `tickedAt`
// (whole seconds since 1970, UTC) — synced with the tick, backed up with the trip. The web app's
// model sees a key it does not know; nothing else is stored.

/// On a trip LINE: when it was ticked — whole seconds since 1 January 1970 (UTC), this device's
/// clock. Removed by an untick.
public let TICKED_AT_KEY = "tickedAt"
/// A gap between two ticks of a trip longer than this is a break, not packing time.
public let PACE_BREAK_SECONDS: Double = 600
/// His pace is read from at most this many timed ticks, the newest (about his last three packings).
public let PACE_RECENT_TICKS = 200
/// Fewer timed ticks than this: the default pace.
public let PACE_MIN_TICKS = 20
/// Seconds per thing until his own pace is known.
public let PACE_DEFAULT_SECONDS: Double = 45

/// His packing pace: seconds per thing, and whether it was measured.
public struct PackingPace: Equatable, Sendable {
    public var secondsPerThing: Double
    /// How many timed ticks it was read from (the newest, at most `PACE_RECENT_TICKS`).
    public var timedTicks: Int
    /// False: fewer than `PACE_MIN_TICKS` timed ticks — the default 45 s.
    public var measured: Bool
}

/// What is left on a trip being packed — the line under its count.
public struct WhatsLeft: Equatable, Sendable {
    /// Lines not set aside and not ticked (its reminders too).
    public var left: Int
    /// Things on the To charge card not charged yet (0 when the card does not show today).
    public var toCharge: Int
    /// How long the rest takes at his pace, in seconds.
    public var seconds: Double

    public var allPacked: Bool { left == 0 }

    /// "23 left · 2 to charge · about 25 min"; "All packed" (· "2 to charge").
    public var words: String {
        var parts: [String] = [left == 0 ? "All packed" : "\(left) left"]
        if toCharge > 0 { parts.append("\(toCharge) to charge") }
        if left > 0 { parts.append(Library.aboutWords(seconds)) }
        return parts.joined(separator: " \u{00B7} ")
    }
}

extension Library {
    // MARK: - The moment of a tick

    /// A line's tick moment, seconds since 1970; nil when it has none (or not a number > 0).
    public static func tickedAt(_ line: Item) -> Double? {
        guard let n = line.extra[TICKED_AT_KEY]?.numberValue, n > 0, n.isFinite else { return nil }
        return n
    }

    /// The moment written on a tick: now, in whole seconds.
    static func tickMoment() -> JSONValue {
        .number(PackingEnv.now().timeIntervalSince1970.rounded(.down))
    }

    // MARK: - His pace

    /// His pace (spec 07 part 20, rules 14–16): per trip, the moments of its ticked lines (not set
    /// aside) in order; lines with the same moment are one step of k lines (one press of a heading's
    /// tick); the gap from the step before, when 10 minutes or less, gives each of them gap ÷ k
    /// seconds; a longer gap is a break; a trip's first step is not timed. The newest 200 timed
    /// ticks of all trips, their median; fewer than 20: 45 s.
    public func packingPace() -> PackingPace {
        var timed: [(at: Double, seconds: Double)] = []
        for trip in trips {
            var steps: [Double: Int] = [:]
            for line in trip.entries where line.checked && !isSetAside(line) {
                if let at = Library.tickedAt(line) { steps[at, default: 0] += 1 }
            }
            let moments = steps.keys.sorted()
            guard moments.count > 1 else { continue }
            for i in 1..<moments.count {
                let gap = moments[i] - moments[i - 1]
                guard gap <= PACE_BREAK_SECONDS else { continue }
                let k = steps[moments[i]] ?? 1
                for _ in 0..<k { timed.append((moments[i], gap / Double(k))) }
            }
        }
        let recent = timed.sorted { $0.at > $1.at }.prefix(PACE_RECENT_TICKS).map(\.seconds)
        guard recent.count >= PACE_MIN_TICKS else {
            return PackingPace(secondsPerThing: PACE_DEFAULT_SECONDS, timedTicks: recent.count, measured: false)
        }
        return PackingPace(secondsPerThing: Library.median(recent), timedTicks: recent.count, measured: true)
    }

    /// The middle value; an even count, the mean of the two middle ones. 0 for none.
    static func median(_ values: [Double]) -> Double {
        let s = values.sorted()
        guard !s.isEmpty else { return 0 }
        let m = s.count / 2
        return s.count % 2 == 1 ? s[m] : (s[m - 1] + s[m]) / 2
    }

    // MARK: - What is left

    /// The line under a trip's count (rules 9–12): what is left, what is to charge `today`, and
    /// the time the rest takes at his pace. Nil for no such trip, or one with nothing to pack (no
    /// line, or every line set aside). WHEN it shows (at Pack) is the screen's.
    public func whatsLeft(tripId: String, today: String) -> WhatsLeft? {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return nil }
        let p = progress(trip.entries)
        guard p.total > 0 else { return nil }
        let left = p.total - p.done
        let charge = chargeCard(tripId: tripId, today: today).filter { !$0.charged }.count
        let seconds = left > 0 ? Double(left) * packingPace().secondsPerThing : 0
        return WhatsLeft(left: left, toCharge: charge, seconds: seconds)
    }

    /// "less than a minute", "about 4 min", "about 25 min", "about 1 h 25 min", "about 2 h" —
    /// to the minute under 10 minutes, then to the nearest 5 (rule 11).
    public static func aboutWords(_ seconds: Double) -> String {
        guard seconds >= 60 else { return "less than a minute" }
        let m = seconds / 60
        let minutes = m < 10 ? Int(m.rounded()) : Int((m / 5).rounded()) * 5
        guard minutes >= 60 else { return "about \(minutes) min" }
        let h = minutes / 60, rest = minutes % 60
        return rest == 0 ? "about \(h) h" : "about \(h) h \(rest) min"
    }
}
