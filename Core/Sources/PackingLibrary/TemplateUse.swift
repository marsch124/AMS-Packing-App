import Foundation
import PackingCore

// When each list was last taken along, and how often. A list nobody has packed in
// a year is worth knowing about; so is the one that goes everywhere.

extension Library {
    public struct TemplateUse: Equatable, Sendable {
        /// The most recent trip that drew on this list and has begun (by `today`).
        public var lastTrip: String
        /// That trip's start date (YYYY-MM-DD), or "" when it has none.
        public var lastDate: String
        /// How many trips have drawn on it, ever (the ones still ahead included).
        public var trips: Int
        /// The soonest trip still ahead that draws on it, and its start date — a trip
        /// that has not begun is not "last taken" (the spec pass, 5 Oct 2026: the
        /// card said "in 30 days" where it meant "last").
        public var nextTrip: String
        public var nextDate: String
        public init(lastTrip: String = "", lastDate: String = "", trips: Int = 0, nextTrip: String = "", nextDate: String = "") {
            self.lastTrip = lastTrip; self.lastDate = lastDate; self.trips = trips
            self.nextTrip = nextTrip; self.nextDate = nextDate
        }

        /// The line on the template's card: when it was last taken and on which trip;
        /// a template only ever planned says when it goes NEXT; one never used says so.
        /// The WHEN comes first: it is the part that is always worth reading, and the
        /// part that still shows when a long trip name is cut off.
        public static func line(_ use: TemplateUse?, today: String) -> String {
            guard let use, use.trips > 0 else { return "Never taken along" }
            if !use.lastTrip.isEmpty {
                let ago = use.lastDate.isEmpty ? "" : countdownLabel(daysUntil(use.lastDate, today))
                return ago.isEmpty ? "Last: \(use.lastTrip)" : "\(ago) \u{00B7} \(use.lastTrip)"
            }
            if !use.nextTrip.isEmpty {
                let when = countdownLabel(daysUntil(use.nextDate, today))
                let soft = when.prefix(1).lowercased() + when.dropFirst()   // "Next: tomorrow"
                return when.isEmpty ? "Next: \(use.nextTrip)" : "Next: \(soft) \u{00B7} \(use.nextTrip)"
            }
            return "Taken on \(use.trips) trip\(use.trips == 1 ? "" : "s")"
        }
    }

    /// Template id → when it was last taken. Counted from the trips themselves:
    /// the lists a trip was built from, and, for a trip whose list has since been
    /// deleted or replaced, the lists its own lines still name. `today`
    /// (YYYY-MM-DD) splits the trips that have begun from those still ahead; ""
    /// counts every dated trip as taken.
    public func templateUse(today: String = "") -> [String: TemplateUse] {
        var out: [String: TemplateUse] = [:]
        for trip in trips {
            var ids = Set(trip.activities)
            for line in trip.entries { if let from = line.sourceListId, !from.isEmpty { ids.insert(from) } }
            for id in ids {
                var use = out[id] ?? TemplateUse()
                use.trips += 1
                // The most recent that has begun; the soonest still ahead. A trip
                // with no date never wins either.
                let start = trip.startDate
                if !start.isEmpty, !today.isEmpty, start > today {
                    if use.nextDate.isEmpty || start < use.nextDate {
                        use.nextDate = start
                        use.nextTrip = trip.name
                    }
                } else if !start.isEmpty, start > use.lastDate {
                    use.lastDate = start
                    use.lastTrip = trip.name
                }
                out[id] = use
            }
        }
        return out
    }
}
