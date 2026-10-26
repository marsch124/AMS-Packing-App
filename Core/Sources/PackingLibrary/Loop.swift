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

        /// How this step looks on the loop strip of a trip, its review and Refine, which stand
        /// at `here` (0.101 — his words, 26 Oct 2026: "The upper 'pack pill' should have the same
        /// colour shading as the lower Station: Pack as they are ongoing. The full colour means
        /// Done."). ONE rule for the strip and the Stations row: a step before `here` is done
        /// (full colour), `here` is the one being worked on (the light shading with the stronger
        /// ring of the Stations' next to do), a step after it is ahead (outlined).
        public func stage(at here: LoopStep) -> LoopStage {
            rawValue < here.rawValue ? .done : rawValue == here.rawValue ? .here : .ahead
        }
    }

    /// A loop step seen from where a trip stands (`LoopStep.stage(at:)`, 0.101).
    public enum LoopStage: String, Sendable, CaseIterable {
        case done, here, ahead
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

    /// The trip header's **Review** button (0.84, his yes of 15 Oct 2026 — "is that really
    /// necessary?" on a Review button beside Done while he was still packing): only once the trip
    /// has started — On site or later by `loopStep` (On site already follows the time he leaves
    /// on the first day) — and while it is not reviewed and has lines. A trip with no start
    /// date never starts by the clock, so it keeps the button as before (else it could never
    /// be reviewed). The loop strip's Review step is not this button and does not change.
    public func offersReview(tripId: String, today: String, time: String = END_OF_DAY) -> Bool {
        guard let trip = trips.first(where: { $0.id == tripId }),
              !Library.isReviewed(trip), !trip.entries.isEmpty else { return false }
        guard isYMD(trip.startDate) else { return true }
        return loopStep(tripId: tripId, today: today, time: time).rawValue >= LoopStep.onSite.rawValue
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

// Each step's own mark (0.77). Until then the strip wore the mark of the TAB where a step is
// done (his F.7, 0.41) — a suitcase, calendars, a list: stock-looking, three steps alike. His
// ask (13 Oct 2026): "not stock but cool", drawn in the app's own hand. Of three candidates per
// step on a sample sheet, lit and unlit, day and night, he picked: Plan A, Pack A, On site C,
// Review B, Refine C. The drawings as they were on that sheet — one 1.9 stroke on the 24-point
// grid, round caps and joins, no fill; only the path commands the app draws (M L H V C S Q A Z).
// As data here, like the template icons, so the model's tests hold each step to his pick.

/// A loop step's mark: `key` names the drawing, `label` says what it shows (VoiceOver and the
/// tests read it), `path` is the SVG path data on a 24-point box.
public struct LoopStepMark: Equatable, Sendable {
    public let key: String
    public let label: String
    public let path: String
}

extension Library.LoopStep {
    /// The step's own mark — his pick of 13 Oct 2026.
    public var mark: LoopStepMark {
        switch self {
        case .plan:      // A — a sketch map (the Map template icon's outline), a dotted route to an X
            return LoopStepMark(key: "routeMap", label: "A map with a route to an X",
                                path: "M3.5 6.5 9 4.5l6 2 5.5-2v13l-5.5 2-6-2-5.5 2Z M6.6 15.6h.01 M9.4 14.1h.01 M12.3 13h.01 M14.3 8.6l3 3 M17.3 8.6l-3 3")
        case .pack:      // A — the suitcase (Home's own mark, without its straps) with a tick
            return LoopStepMark(key: "packedCase", label: "A suitcase with a tick",
                                path: "M6.2 7.5h11.6a2.2 2.2 0 0 1 2.2 2.2v8.1a2.2 2.2 0 0 1-2.2 2.2H6.2A2.2 2.2 0 0 1 4 17.8V9.7a2.2 2.2 0 0 1 2.2-2.2Z M9 7.5V5.6A1.6 1.6 0 0 1 10.6 4h2.8A1.6 1.6 0 0 1 15 5.6V7.5 M8.8 13.9l2.2 2.2 4.2-4.4")
        case .onSite:    // C — a pin (the trip map's pin) standing on a folded map
            return LoopStepMark(key: "pinOnMap", label: "A pin on a folded map",
                                path: "M3 17.5 8 16l8 2 5-1.5v3.5l-5 1.5-8-2-5 1.5Z M12 15s-4.6-4.2-4.6-7.8a4.6 4.6 0 0 1 9.2 0c0 3.6-4.6 7.8-4.6 7.8Z M12 5.9a1.3 1.3 0 1 0 0 2.6a1.3 1.3 0 1 0 0-2.6")
        case .review:    // B — a magnifier over a list
            return LoopStepMark(key: "listLens", label: "A magnifier over a list",
                                path: "M3.5 6h11 M3.5 10.5h6.5 M3.5 15h4.5 M11.5 14a4 4 0 1 0 8 0a4 4 0 1 0 -8 0 M18.4 16.9l2.6 2.6")
        case .refine:    // C — a sprout: the templates grow better, trip after trip
            return LoopStepMark(key: "sprout", label: "A sprout",
                                path: "M12 20.5V11.2 M12 11.2c0-3.6 2.6-6 7-6 0 3.6-2.6 6-7 6Z M12 14.5c0-2.9-2.1-4.8-5.6-4.8 0 2.9 2.1 4.8 5.6 4.8Z M7.5 20.5h9")
        }
    }
}
