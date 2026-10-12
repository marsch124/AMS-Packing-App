import Foundation
import PackingCore

// What a trip looks like from the outside: where it is in its life, how far the
// packing has got, and whether it still wants something from him. The Events
// screen shows nothing but this.

extension Library {
    /// Where a trip is in its life. The order is the order it happens in.
    public enum TripState: String, Sendable, CaseIterable {
        /// Nothing ticked yet.
        case planned
        /// Started, not finished.
        case packing
        /// Everything ticked or set aside — nothing left to decide.
        case packed
        /// Been and reviewed: it has taught the lists what it learnt.
        case reviewed
    }

    /// Which pile a trip belongs in: reviewed = done; else by its dates against today.
    public enum TripWhen: String, Sendable {
        case comingUp, now, been
    }

    /// Which pile a trip belongs in — ONE rule for the Trips tab and for "still ahead"
    /// (a change to a thing reaching a trip, `tripStillAhead`); the countdown and the
    /// packing reminders already leave a reviewed trip out (`stillToLeave`).
    ///
    /// 0.73, his must-fix: a trip he had REVIEWED stayed among his active trips. The
    /// pile went by the dates alone, so a reviewed trip with no dates (or with today's
    /// or later ones) sat in Coming up or Now. Reviewed means finished with: it goes to
    /// Done, folded under Reviewed there, whatever its dates. Otherwise: no start date
    /// → Coming up (still ahead); start after today → Coming up; start to end (end =
    /// start when empty) holding today → Now; else Done. YYYY-MM-DD compared as strings.
    public static func tripWhen(_ trip: TripEvent, today: String) -> TripWhen {
        guard !isReviewed(trip) else { return .been }
        let start = jsTrim(trip.startDate), end = jsTrim(trip.endDate).isEmpty ? start : jsTrim(trip.endDate)
        if start.isEmpty || start > today { return .comingUp }
        return end >= today ? .now : .been
    }

    public struct TripCard: Equatable, Sendable {
        public var id: String
        public var name: String
        public var startDate: String
        public var endDate: String
        public var place: String
        public var done: Int
        public var total: Int
        public var aside: Int
        public var state: TripState
        public var when: TripWhen
        /// What the forecast says, when the trip holds one.
        public var weather: String

        /// 0…1 for a bar. A trip with no lines is not "complete", it is empty.
        public var part: Double { total > 0 ? Double(done) / Double(total) : 0 }
    }

    /// Has the trip been reviewed? ONE rule for every screen (the spec pass, 5 Oct
    /// 2026): marked done, or a review time on it — trips from the web app can carry
    /// the time alone. The trip screen asked only for "done", so such a trip looked
    /// reviewed on its card and offered Review again on its page.
    public static func isReviewed(_ trip: TripEvent) -> Bool {
        trip.status == "done" || !trip.reviewedAt.isEmpty
    }

    /// Every trip, in the order the Events screen shows them: what is happening
    /// now first, then what is coming, then what has been (most recent first).
    public func tripCards(today: String) -> [TripCard] {
        sortEventsForList(trips, today).map { trip in
            let p = progress(trip.entries)
            let state: TripState
            if Library.isReviewed(trip) { state = .reviewed }
            else if p.total > 0 && p.done == p.total { state = .packed }
            else if p.done > 0 || p.aside > 0 { state = .packing }
            else { state = .planned }

            let when = Library.tripWhen(trip, today: today)

            var weather = ""
            if let sky = deriveWeather(trip), !sky.days.isEmpty {
                weather = sky.rangeLabel.contains("NaN") ? "" : sky.rangeLabel
            }
            return TripCard(id: trip.id, name: trip.name, startDate: trip.startDate, endDate: trip.endDate,
                            place: trip.destination, done: p.done, total: p.total, aside: p.aside,
                            state: state, when: when, weather: weather)
        }
    }

    /// The to-dos still open — the Events screen says so and points at Actions,
    /// because a to-do is usually something to do BEFORE leaving.
    public func openToDoCount() -> Int { sortedActions().filter { !$0.done }.count }
}
