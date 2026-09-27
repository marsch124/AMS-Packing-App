import Foundation
import PackingCore

// Whole-trip moves from the web app's trip menu (the gap list, 2026-09-27):
// "Mark everything packed", "Clear every tick", and the weather card's "Add all".

extension Library {
    /// Tick — or untick — every line of a trip. Lines set aside stay out, as the
    /// round button by each heading leaves them: they are not being packed. Each line
    /// is its own small write, as a tick by hand is. Returns how many changed.
    @discardableResult
    public mutating func setAllChecked(_ checked: Bool, tripId: String) -> Int {
        guard let t = trips.firstIndex(where: { $0.id == tripId }) else { return 0 }
        let ids = trips[t].entries.filter { !isSetAside($0) && $0.checked != checked }.map(\.id)
        for id in ids { setChecked(checked, tripId: tripId, entryId: id) }
        return ids.count
    }

    /// Everything the forecast asks for that is not on the trip yet, in one go.
    /// Returns how many lines were added.
    @discardableResult
    public mutating func addAllWeatherGear(tripId: String) -> Int {
        var added = 0
        for gear in weatherMissing(tripId: tripId) where addWeatherGear(tripId: tripId, gear) != nil { added += 1 }
        return added
    }
}
