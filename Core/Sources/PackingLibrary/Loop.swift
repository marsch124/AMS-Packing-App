import Foundation
import PackingCore

// The loop the app runs on (his picture, 2026-09-27): Plan → Pack → Review →
// Refine, and Refine feeds the next Plan. Plan and Refine are about his LISTS;
// Pack and Review are about ONE trip.
//
// On site joined it between Pack and Review — their field test
// (3 Oct 2026): "I'm still pondering if we should add a phase (in the graphics as
// well). The phase could be 'During the trip' or 'On site'. It should come
// immediately after Pack, process-wise." It is about one trip too.

extension Library {
    public enum LoopStep: Int, Sendable, CaseIterable {
        case plan, pack, onSite, review, refine

        public var name: String {
            switch self {
            case .plan: return "Plan"
            case .pack: return "Pack"
            case .onSite: return "On site"
            case .review: return "Review"
            case .refine: return "Refine"
            }
        }

        /// Pack, On site and Review are about one trip; Plan and Refine about the lists.
        public var aboutOneTrip: Bool { self == .pack || self == .onSite || self == .review }
    }

    /// Where a trip stands in the loop. Reviewed: what it taught now waits in
    /// Refine. Over and not reviewed: Review. No lines yet: still Plan. Set off (see
    /// `hasSetOff`; its last day not yet passed): On site — and so is any trip
    /// once something was bought on site, whatever its dates say: buying on site says
    /// he is there. (The spec pass, 5 Oct 2026: a dated trip still ahead stayed at Pack
    /// here while its On site door, which has always gone by a bought line, showed.)
    /// Otherwise it is being packed — all ticked or not, until it sets off.
    /// `time` is now's time of day, "HH:mm" (0.75); given none, the end of the day.
    public func loopStep(tripId: String, today: String, time: String = END_OF_DAY) -> LoopStep {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return .plan }
        if Library.isReviewed(trip) { return .refine }
        let end = trip.endDate.isEmpty ? trip.startDate : trip.endDate
        if !end.isEmpty, end < today { return .review }
        if trip.entries.isEmpty { return .plan }
        if Library.hasSetOff(trip, today: today, time: time) { return .onSite }
        if trip.entries.contains(where: Library.isBoughtOnSite) { return .onSite }
        return .pack
    }
}

// When a trip sets off (0.75) — his report of 13 Oct 2026: "at 07:30 on the first day, with
// 'I leave at 08:00', the trip already shows On site." The loop went by the date alone. Now
// "now" is a day and a time of day, and on the first day the time he leaves decides.

/// The time of day that stands for "some time today" when only the day is known: the end of
/// it. A caller that gives no time sees the first day as set off — what the loop always said.
public let END_OF_DAY = "23:59"

extension Library {
    /// Has the trip set off by `today` ("YYYY-MM-DD") at `time` ("HH:mm", this device's
    /// clock)? Before its first day: no. On a later day: yes. On its first day: from the time
    /// he leaves on it (`leaveAt`), that minute included — with no time set, from the start
    /// of the day. Without a valid start date: never. A time that is not one counts as the
    /// end of the day.
    public static func hasSetOff(_ trip: TripEvent, today: String, time: String = END_OF_DAY) -> Bool {
        let start = trip.startDate
        guard isYMD(start), !jsStringLess(today, start) else { return false }
        guard today == start else { return true }
        let leave = leaveTime(trip, home: false)
        guard !leave.isEmpty else { return true }
        return !jsStringLess(cleanTime(time) ?? END_OF_DAY, leave)
    }

    /// The moments the trip's step turns by the clock alone, "yyyy-MM-dd HH:mm", in order:
    /// when it sets off (its first day at the time he leaves, else at 00:00 — Pack to On
    /// site) and the day after its last at 00:00 (to Review). A trip open on the screen wakes
    /// at the next one still ahead, so it turns while he looks at it. Reviewed or undated: none.
    public static func clockTurns(_ trip: TripEvent) -> [String] {
        guard !isReviewed(trip), isYMD(trip.startDate) else { return [] }
        let leave = leaveTime(trip, home: false)
        var turns = ["\(trip.startDate) \(leave.isEmpty ? "00:00" : leave)"]
        // The last day as `loopStep` reads it: the end date, else the start.
        let last = trip.endDate.isEmpty ? trip.startDate : trip.endDate
        if isYMD(last) { turns.append("\(ymd(last, plusDays: 1)) 00:00") }
        return turns
    }
}
