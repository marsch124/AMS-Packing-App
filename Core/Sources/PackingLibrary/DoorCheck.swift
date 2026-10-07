import Foundation
import PackingCore

// The door check — idea 4 of his idea plan; his choice (7 Oct 2026): "c, a time". On the
// day he leaves, at the moment he sets off, one message names what is still unticked:
// "Leaving for Torremolinos? Still unticked: Passport, Charger, Goggles." A tap opens the
// trip on just those lines. On the last day away, the same for the way home, about what
// is not in a bag yet.
//
// The trip keeps "I leave at" as a time on its first day, and one on its last day for the
// way home — both optional, in the trip's extra keys (the web app's model is untouched).
// The check comes 15 minutes before. Here is only WHAT would be said and WHEN; the device
// schedules it (the app's DoorChecks), and schedules it again whenever the library
// changes, so the names are those still unticked at the last change.

/// A trip's extra key: the time he leaves on the first day, "07:30".
public let LEAVE_AT_KEY = "leaveAt"
/// A trip's extra key: the time he leaves for home on the last day, "16:00".
public let LEAVE_HOME_AT_KEY = "leaveHomeAt"
/// How long before he leaves the check comes.
public let DOOR_CHECK_LEAD_MINUTES = 15
/// How many names the message gives before "and 3 more".
public let DOOR_CHECK_NAMES = 5

/// One door check as it would be scheduled.
public struct DoorCheck: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable { case out, home }
    /// "door-out-<trip id>" / "door-home-<trip id>" — the notification's own id, so a new
    /// schedule replaces the old one.
    public var id: String
    public var tripId: String
    public var kind: Kind
    /// The day it comes, "2026-10-14", and the time, "07:15".
    public var day: String
    public var time: String
    public var title: String
    public var body: String
}

extension Library {
    /// "7:30", "07:30", "0730" → "07:30"; anything else → nil.
    public static func cleanTime(_ s: String) -> String? {
        let digits = jsTrim(s).filter { $0.isNumber }
        guard (3...4).contains(digits.count) else { return nil }
        let h = Int(digits.dropLast(2)) ?? -1, m = Int(digits.suffix(2)) ?? -1
        guard (0...23).contains(h), (0...59).contains(m) else { return nil }
        return String(format: "%02d:%02d", h, m)
    }

    /// The time he leaves: on the first day, or (`home`) on the last day for home. "" = none.
    public static func leaveTime(_ trip: TripEvent, home: Bool) -> String {
        cleanTime(trip.extra[home ? LEAVE_HOME_AT_KEY : LEAVE_AT_KEY]?.stringValue ?? "") ?? ""
    }

    /// Set (or, with "", take away) a time he leaves. A time that is not one is refused.
    public static func setLeaveTime(_ trip: inout TripEvent, _ time: String, home: Bool) -> Bool {
        let key = home ? LEAVE_HOME_AT_KEY : LEAVE_AT_KEY
        if jsTrim(time).isEmpty { trip.extra[key] = nil; return true }
        guard let clean = cleanTime(time) else { return false }
        trip.extra[key] = .string(clean)
        return true
    }

    @discardableResult
    public mutating func setLeaveTime(_ time: String, home: Bool, tripId: String) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }) else { return false }
        guard Library.setLeaveTime(&trips[n], time, home: home) else { return false }
        trips[n].updatedAt = nowISO()
        return true
    }

    /// The moment the check comes: `minutes` before the time on the day — the day before
    /// when that crosses midnight. ("2026-10-14", "00:10") → ("2026-10-13", "23:55").
    public static func before(day: String, time: String, minutes: Int) -> (day: String, time: String)? {
        guard isYMD(day), let t = cleanTime(time) else { return nil }
        let h = Int(t.prefix(2)) ?? 0, m = Int(t.suffix(2)) ?? 0
        var total = h * 60 + m - minutes
        var d = day
        while total < 0 { total += 24 * 60; d = addDays(d, -1) }
        return (d, String(format: "%02d:%02d", total / 60, total % 60))
    }

    /// "Passport, Charger, Goggles" — up to five names, then "and 3 more".
    public static func doorNames(_ names: [String]) -> String {
        let shown = names.prefix(DOOR_CHECK_NAMES).joined(separator: ", ")
        let rest = names.count - DOOR_CHECK_NAMES
        return rest > 0 ? "\(shown) and \(rest) more" : shown
    }

    /// Every door check still to come, as of `now` ("2026-10-07 08:30", this device's
    /// clock). A trip that is reviewed has none; a check whose moment has passed has none;
    /// and a check with nothing to say — every line ticked, everything in a bag — is not
    /// made at all.
    public func doorChecks(now: String) -> [DoorCheck] {
        var out: [DoorCheck] = []
        for trip in trips where !Library.isReviewed(trip) {
            let place = jsTrim(trip.destination).isEmpty ? (jsTrim(trip.name).isEmpty ? "your trip" : jsTrim(trip.name)) : jsTrim(trip.destination)
            let first = jsTrim(trip.startDate)
            let last = jsTrim(trip.endDate).isEmpty ? first : jsTrim(trip.endDate)
            // The way out: what is still unticked (a line set aside is not coming).
            if let when = Library.before(day: first, time: Library.leaveTime(trip, home: false), minutes: DOOR_CHECK_LEAD_MINUTES),
               "\(when.day) \(when.time)" > now {
                let left = trip.entries.filter { !$0.checked && !isSetAside($0) }.map(\.name)
                if !left.isEmpty {
                    out.append(DoorCheck(id: "door-out-\(trip.id)", tripId: trip.id, kind: .out, day: when.day, time: when.time,
                                         title: "Leaving for \(place)?",
                                         body: "Still unticked: \(Library.doorNames(left))"))
                }
            }
            // The way home: what is not in a bag yet (Pack to go home's own ticks).
            if let when = Library.before(day: last, time: Library.leaveTime(trip, home: true), minutes: DOOR_CHECK_LEAD_MINUTES),
               "\(when.day) \(when.time)" > now {
                let left = homeLines(tripId: trip.id).filter { !Library.isUsedUp($0) && !Library.isPackedHome($0) }.map(\.name)
                if !left.isEmpty {
                    out.append(DoorCheck(id: "door-home-\(trip.id)", tripId: trip.id, kind: .home, day: when.day, time: when.time,
                                         title: "Going home from \(place)?",
                                         body: "Not in a bag yet: \(Library.doorNames(left))"))
                }
            }
        }
        return out
    }
}
