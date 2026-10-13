import Foundation
import PackingCore

// Whole-trip moves from the web app's trip menu (the gap list, 2026-09-27):
// "Mark everything packed", "Clear every tick", and the weather card's "Add all".
//
// 0.79 (his decision of 13 Oct 2026): "Tick everything" and "Clear every tick" were "two very
// risky buttons — in a stressful situation half way packed, pressed by mistake: catastrophe".
// Tick everything left the trip screen; Clear every tick moved into Trip settings; and a
// heading's round tick and Clear every tick can be taken back with Undo (`TicksChanged`).

/// What one press that ticks or unticks many lines changed — a heading's round tick, or
/// Clear every tick — so its Undo can put back exactly that and nothing else (0.79).
public struct TicksChanged: Equatable, Sendable {
    /// One line the press changed, as it was before it.
    public struct Before: Equatable, Sendable {
        public let id: String
        /// Its pocket: a tick chooses the usual one (`prechoosePocket`), and Undo takes it away.
        public let pocket: JSONValue?
    }
    public let tripId: String
    /// What the press set the lines to: true = ticked.
    public let checked: Bool
    /// Only the lines whose tick it CHANGED — not one already so, not a kit that refused.
    public let lines: [Before]
    public var count: Int { lines.count }
    public var isEmpty: Bool { lines.isEmpty }
}

extension Library {
    /// Tick — or untick — every line of a trip. Lines set aside stay out, as the
    /// round button by each heading leaves them: they are not being packed. Each line
    /// is its own small write, as a tick by hand is. Returns how many changed.
    @discardableResult
    public mutating func setAllChecked(_ checked: Bool, tripId: String) -> Int {
        setEveryTick(checked, tripId: tripId).count
    }

    /// The same, saying which lines changed and how they were — what Clear every tick in Trip
    /// settings hands to the trip's Undo (0.79).
    @discardableResult
    public mutating func setEveryTick(_ checked: Bool, tripId: String) -> TicksChanged {
        let ids = trip(tripId)?.entries.filter { !isSetAside($0) && $0.checked != checked }.map(\.id) ?? []
        return setChecked(checked, tripId: tripId, entryIds: ids)
    }

    /// Tick — or untick — these lines of a trip, one `setChecked` (one small write) each: a
    /// heading's round tick passes its group's lines (0.79). A line already so is left alone, a
    /// line set aside is never ticked, and a kit still waiting for what is inside refuses, as it
    /// does by hand. Returns what changed, for Undo.
    @discardableResult
    public mutating func setChecked(_ checked: Bool, tripId: String, entryIds: [String]) -> TicksChanged {
        var changed: [TicksChanged.Before] = []
        for id in entryIds {
            // The first line with the id, as everywhere (his E.6 crash, 28 Sep: ids can repeat).
            guard let line = trip(tripId)?.entries.first(where: { $0.id == id }),
                  line.checked != checked, !(checked && isSetAside(line)),
                  setChecked(checked, tripId: tripId, entryId: id) else { continue }
            changed.append(.init(id: id, pocket: line.extra[POCKET_KEY]))
        }
        return TicksChanged(tripId: tripId, checked: checked, lines: changed)
    }

    /// Undo (0.79): every line the press changed goes back to how it was — its tick and its
    /// pocket, WRITTEN back rather than ticked again: a kit checked before each trip that Clear
    /// unpacked has lost what was ticked inside it (unticking a kit starts it over), so a tick
    /// would be refused — written back, it is packed again, and a packed kit counts all inside
    /// as ticked (it keeps no list). A line changed again since (by hand, or on the other device)
    /// is left as he left it; one set aside since is not ticked underneath; one gone from the
    /// trip (a rebuild) is skipped. Returns how many went back.
    @discardableResult
    public mutating func undo(_ change: TicksChanged) -> Int {
        guard let t = trips.firstIndex(where: { $0.id == change.tripId }) else { return 0 }
        var back = 0
        for was in change.lines {
            guard let e = trips[t].entries.firstIndex(where: { $0.id == was.id }) else { continue }
            let line = trips[t].entries[e]
            guard line.checked == change.checked, !(!change.checked && isSetAside(line)) else { continue }
            trips[t].entries[e].checked = !change.checked
            trips[t].entries[e].extra[POCKET_KEY] = was.pocket
            back += 1
        }
        return back
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
