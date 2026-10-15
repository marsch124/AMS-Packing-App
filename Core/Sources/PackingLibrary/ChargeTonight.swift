import Foundation
import PackingCore

// "Charge tonight" — his yes of 15 Oct 2026 to the idea put to him: "the evening before you
// leave, your iPhone says what still needs charging — 'Charge tonight: Garmin, power pack, bike
// computer' — only if something is left to charge." (Spec 07 part 16, "Charge tonight".)
//
// One more of the trip's messages (`tripMessages`, the app's TripMessages): WHAT it says and
// WHEN is here; the device puts it in its list and puts it right whenever the library changes
// — a charge tick, a new date, a thing given a battery — so the names are the ones still
// uncharged at the last change, and with everything charged it goes.
//
// The names are the trip's To charge (`chargeCard`, part 15) as it will be on that evening —
// the one source the card in Before you go, Take a break's overview and What's left read.

/// The evening before the trip's first day, at this time: home by then, and in time to charge
/// overnight; not the minute of a break's "This evening" (19:00), so two messages never come
/// at once.
public let CHARGE_TONIGHT_AT = "20:00"
/// How many names the message gives before "and 2 more".
public let CHARGE_TONIGHT_NAMES = 4
/// The message's title — his words.
public let CHARGE_TONIGHT_TITLE = "Charge tonight"

extension Library {
    /// "Toothbrush, Power bank" — up to four names, then "and 2 more".
    public static func chargeTonightNames(_ names: [String]) -> String {
        let shown = names.prefix(CHARGE_TONIGHT_NAMES).joined(separator: ", ")
        let rest = names.count - CHARGE_TONIGHT_NAMES
        return rest > 0 ? "\(shown) and \(rest) more" : shown
    }

    /// The trip's "Charge tonight", as of `now` ("2026-10-13 14:20", this device's clock): on
    /// the evening before its first day at 20:00, naming every thing on its To charge that
    /// evening (`chargeCard`) not charged yet, in the card's order. Nil when the trip is
    /// reviewed or has no start date, when that evening has passed (the moment itself
    /// included), or when nothing is left to charge — nothing on the trip has a battery, or
    /// every such thing is charged.
    public func chargeTonight(tripId: String, now: String) -> TripMessage? {
        guard let trip = trips.first(where: { $0.id == tripId }), !Library.isReviewed(trip),
              let now = Library.cleanMoment(now) else { return nil }
        let start = jsTrim(trip.startDate)
        guard isYMD(start) else { return nil }
        let eve = addDays(start, -1)
        guard jsStringLess(now, "\(eve) \(CHARGE_TONIGHT_AT)") else { return nil }
        let left = chargeCard(tripId: tripId, today: eve).filter { !$0.charged }.map(\.name)
        guard !left.isEmpty else { return nil }
        return TripMessage(id: "charge-\(trip.id)", tripId: trip.id, kind: .charge,
                           day: eve, time: CHARGE_TONIGHT_AT,
                           title: CHARGE_TONIGHT_TITLE, body: Library.chargeTonightNames(left))
    }
}
