import Foundation

// The station he is on (0.101, his words of 26 Oct 2026, "1 and 2, put them in 0.101"): his trip
// "2026-11 Torremolinos" stayed on Bags, lit, however much he packed — the row lit the first station
// not done, and Bags out was never ticked. Now the station he taps is the lit one, until he taps
// another; with none tapped yet, the first not done. Kept per trip on THIS device (an AppStorage
// text, like the trip's folds): which station he is at is where he stands, not a fact of the trip.

/// The stations tapped, one per trip: lines "<trip id>|<station>", the newest last.
public enum StationPicks {
    /// At most this many trips are remembered: the oldest go first.
    public static let kept = 40
    /// Where this device keeps them (AppStorage).
    public static let storageKey = "ams.trip.station"

    /// The station last tapped on this trip — nil when none was, or it is no station.
    public static func picked(_ raw: String, trip: String) -> PackingDayStation? {
        for line in raw.split(separator: "\n").reversed() {
            let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[0] == trip { return PackingDayStation(rawValue: parts[1]) }
        }
        return nil
    }

    /// `raw` with this trip's station set to `station`.
    public static func picking(_ raw: String, trip: String, _ station: PackingDayStation) -> String {
        var lines = raw.split(separator: "\n").map(String.init).filter { !$0.hasPrefix("\(trip)|") }
        lines.append("\(trip)|\(station.rawValue)")
        return lines.suffix(kept).joined(separator: "\n")
    }
}

extension PackingDay {
    /// The station lit on the row and shown as "here": the one he tapped last on this trip while
    /// it can be done (a station asking about bags needs bags) — done or not, it stays his until he
    /// taps another; with none tapped, the first not done (`current`).
    public func lit(picked: PackingDayStation?) -> PackingDayStation {
        guard let picked, usable(picked) else { return current }
        return picked
    }
}
