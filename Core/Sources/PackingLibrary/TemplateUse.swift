import Foundation
import PackingCore

// When each list was last taken along, and how often. A list nobody has packed in
// a year is worth knowing about; so is the one that goes everywhere.

extension Library {
    public struct TemplateUse: Equatable, Sendable {
        /// The most recent trip that drew on this list.
        public var lastTrip: String
        /// That trip's start date (YYYY-MM-DD), or "" when it has none.
        public var lastDate: String
        /// How many trips have drawn on it, ever.
        public var trips: Int
        public init(lastTrip: String = "", lastDate: String = "", trips: Int = 0) {
            self.lastTrip = lastTrip; self.lastDate = lastDate; self.trips = trips
        }
    }

    /// Template id → when it was last taken. Counted from the trips themselves:
    /// the lists a trip was built from, and, for a trip whose list has since been
    /// deleted or replaced, the lists its own lines still name.
    public func templateUse() -> [String: TemplateUse] {
        var out: [String: TemplateUse] = [:]
        for trip in trips {
            var ids = Set(trip.activities)
            for line in trip.entries { if let from = line.sourceListId, !from.isEmpty { ids.insert(from) } }
            for id in ids {
                var use = out[id] ?? TemplateUse()
                use.trips += 1
                // The most recent by date; a trip with no date never wins.
                if !trip.startDate.isEmpty, trip.startDate > use.lastDate {
                    use.lastDate = trip.startDate
                    use.lastTrip = trip.name
                }
                out[id] = use
            }
        }
        return out
    }
}
