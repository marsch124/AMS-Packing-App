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

    /// Which pile a trip belongs in, by its dates against today.
    public enum TripWhen: String, Sendable {
        case comingUp, now, been
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

    /// Every trip, in the order the Events screen shows them: what is happening
    /// now first, then what is coming, then what has been (most recent first).
    public func tripCards(today: String) -> [TripCard] {
        sortEventsForList(trips, today).map { trip in
            let p = progress(trip.entries)
            let state: TripState
            if trip.status == "done" || !trip.reviewedAt.isEmpty { state = .reviewed }
            else if p.total > 0 && p.done == p.total { state = .packed }
            else if p.done > 0 || p.aside > 0 { state = .packing }
            else { state = .planned }

            let start = trip.startDate, end = trip.endDate.isEmpty ? trip.startDate : trip.endDate
            let when: TripWhen
            if !start.isEmpty, start > today { when = .comingUp }
            else if !start.isEmpty, start <= today, end >= today { when = .now }
            else if start.isEmpty { when = .comingUp }          // no dates yet: still ahead
            else { when = .been }

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
