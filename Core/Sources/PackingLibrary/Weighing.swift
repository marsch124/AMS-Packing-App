import Foundation
import PackingCore

// The bag on the luggage scale — his pre-trip idea 8 (2 Oct 2026). The Bags card
// adds up what the things in a bag weigh; the scale says what the bag really
// weighs, the bag itself and everything unrecorded included. What he reads off the
// scale is kept per trip and per bag (in the trip's extra keys, so the web app's
// model is untouched), and once there it is the weight the bag is judged by.

/// The trip's extra key: `{ "<bag name>": grams }`.
public let WEIGHED_KEY = "weighed"

public struct WeighedBag: Equatable, Sendable {
    /// What the things in it add up to, and its limit.
    public var load: BagLoad
    /// What the scale said, in grams — nil until he weighs it.
    public var scaleGrams: Double?
    /// On the trip by Packing Stations' "+ Add a bag" (0.81) — with or without things in it.
    public var added = false

    /// The weight it is judged by: the scale's when there is one.
    public var grams: Double { scaleGrams ?? load.grams }
    public var over: Bool { load.limitKg > 0 && grams / 1000 > load.limitKg }
}

extension Library {
    /// What the scale said for each bag of a trip, in grams.
    public func weighed(tripId: String) -> [String: Double] {
        guard let trip = trips.first(where: { $0.id == tripId }),
              let o = trip.extra[WEIGHED_KEY]?.objectValue else { return [:] }
        var out: [String: Double] = [:]
        for (bag, v) in o { if let g = v.finiteNumber, g > 0 { out[bag] = g } }
        return out
    }

    /// Keep what the scale said for one bag; nil or nothing takes it away again.
    @discardableResult
    public mutating func setWeighed(tripId: String, bag: String, grams: Double?) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }), !bag.isEmpty else { return false }
        var o = trips[n].extra[WEIGHED_KEY]?.objectValue ?? [:]
        if let g = grams, g.isFinite, g > 0 { o[bag] = .number((g).rounded()) } else { o[bag] = nil }
        trips[n].extra[WEIGHED_KEY] = o.isEmpty ? nil : .object(o)
        trips[n].updatedAt = nowISO()
        return true
    }

    /// The trip's bags as the Bags card shows them — each with its sum, its limit,
    /// and what the scale said. Then (0.81) each bag Packing Stations' "+ Add a bag" put on the
    /// trip that nothing on the list is packed in yet: last, in the order added, empty, with its
    /// limit — a bag added that the list packs into is the list's row, marked `added`.
    public func weighedBags(tripId: String) -> [WeighedBag] {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return [] }
        let scale = weighed(tripId: tripId)
        let limits = bagLimits()
        let added = Library.addedBags(trip)
        func isAdded(_ name: String) -> Bool { added.contains { normName($0) == normName(name) } }
        // A kit weighs what is inside it — on a reviewed trip, what was inside it then (ThingKits).
        var rows = bagLoads(linesWithKitWeights(trip: trip), qtyNights(trip), limits).map {
            WeighedBag(load: $0, scaleGrams: scale[$0.container], added: isAdded($0.container))
        }
        for name in added where !rows.contains(where: { normName($0.load.container) == normName(name) }) {
            let limit = limits[name] ?? 0
            rows.append(WeighedBag(load: BagLoad(container: name, limitKg: limit.isNaN ? 0 : limit), scaleGrams: scale[name], added: true))
        }
        return rows
    }
}
