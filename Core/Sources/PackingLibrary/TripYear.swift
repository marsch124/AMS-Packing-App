import Foundation
import PackingCore

// His travelling year, counted from his own trips.
//
// The Trips screen had nothing under the list but empty space, and he asked for
// something worth looking at. The honest thing to show is the shape of his year:
// which months he actually goes away in, and what those trips added up to. Bars
// are data here, as on the Care dashboard — the app draws no art of its own.

extension Library {
    public struct TravelYear: Equatable, Sendable {
        /// Trips that STARTED in each of the last twelve months, oldest first.
        public var byMonth: [Int] = Array(repeating: 0, count: 12)
        /// The month each column stands for, as its first day ("2026-09-01").
        public var months: [String] = []
        /// Trips in those twelve months.
        public var trips = 0
        /// Nights away, counted from the trips that say when they were.
        public var nights = 0
        /// Things ticked off on those trips.
        public var packed = 0
        /// The busiest month's count, so a bar knows how tall it can be.
        public var most: Int { byMonth.max() ?? 0 }
    }

    /// The last twelve months, ending with the month `today` falls in.
    public func travelYear(today: String = "") -> TravelYear {
        var out = TravelYear()
        let day = today.isEmpty ? String(nowISO().prefix(10)) : today
        guard day.count >= 7 else { return out }
        let thisYear = Int(day.prefix(4)) ?? 0
        let thisMonth = Int(day.dropFirst(5).prefix(2)) ?? 0
        guard thisYear > 0, thisMonth > 0 else { return out }

        // The twelve month-keys ending with this one.
        var keys: [String] = []
        for back in stride(from: 11, through: 0, by: -1) {
            var y = thisYear, m = thisMonth - back
            while m <= 0 { m += 12; y -= 1 }
            keys.append(String(format: "%04d-%02d", y, m))
        }
        out.months = keys.map { "\($0)-01" }
        let place = Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($0.element, $0.offset) })

        for trip in trips {
            let start = jsTrim(trip.startDate)
            guard start.count >= 7, let n = place[String(start.prefix(7))] else { continue }
            out.byMonth[n] += 1
            out.trips += 1
            out.nights += nightsOf(trip)
            out.packed += trip.entries.filter { $0.checked }.count
        }
        return out
    }

    /// How many nights a trip covers, when it says. A trip with no end date, or
    /// one that ends the day it starts, counts as none — not as one.
    private func nightsOf(_ trip: TripEvent) -> Int {
        let from = jsTrim(trip.startDate), to = jsTrim(trip.endDate)
        guard from.count >= 10, to.count >= 10 else { return 0 }
        return max(0, daysBetween(from, to) ?? 0)
    }
}
