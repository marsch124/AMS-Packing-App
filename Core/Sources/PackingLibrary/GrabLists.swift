import Foundation
import PackingCore

// The six grab lists — the Home buttons for a workout: what to take, ticked as
// it is picked up. His most-used thing on the iPhone.
//
// The factory six live in the CODE (web app v163 rule): an account that has
// never edited a list stores no row, and a `grab` row in the shared store
// carries an edited list (items, and the look) to both devices. Ticks and skips
// are THIS DEVICE's working state and clear themselves after six hours — they
// belong to one workout, not to the account.

public struct GrabDefinition: Equatable, Sendable {
    public var id: String
    public var label: String     // on the button ("Swim")
    public var title: String     // on the screen ("Indoor swim")
    public var tone: String      // blue | yellow | green
    public var icon: String      // swim | bike | run | swim-sun | bike-sun | run-sun | …
    public var items: [String]
}

/// The factory six, in the order of the Home buttons.
public let GRAB_FACTORY: [GrabDefinition] = [
    GrabDefinition(id: "swim", label: "Swim", title: "Indoor swim", tone: "blue", icon: "swim",
                   items: ["Swim trunks", "Goggles", "Swim cap", "Towel", "Drink / water bottle", "Sports watch", "Flip-flops"]),
    GrabDefinition(id: "bike", label: "Bike", title: "Indoor bike", tone: "yellow", icon: "bike",
                   items: ["Headband", "AirPods", "Drink / water bottle", "Towel", "Sports watch", "Shoes", "Heart-rate strap"]),
    GrabDefinition(id: "run", label: "Run", title: "Indoor run", tone: "green", icon: "run",
                   items: ["Headband", "AirPods", "Drink / water bottle", "Towel", "Sports watch", "Shoes", "Heart-rate strap"]),
    GrabDefinition(id: "swim-out", label: "Swim", title: "Outdoor swim", tone: "blue", icon: "swim-sun",
                   items: ["Swim trunks", "Goggles", "Wetsuit", "Safety buoy", "Towel", "Drink / water bottle", "Sports watch"]),
    GrabDefinition(id: "bike-out", label: "Bike", title: "Outdoor bike", tone: "yellow", icon: "bike-sun",
                   items: ["Helmet", "Sunglasses", "Cycling gloves", "Drink / water bottle", "Spare tube & pump", "iPhone", "Sports watch"]),
    GrabDefinition(id: "run-out", label: "Run", title: "Outdoor run", tone: "green", icon: "run-sun",
                   items: ["Shoes", "Cap", "Sunglasses", "Sunscreen", "iPhone", "Drink / water bottle", "Sports watch"]),
]

extension Library {
    /// The six lists as they are for this account: the factory list, with his
    /// edits (items, name, icon, colour) laid over it where a `grab` row exists.
    public func grabLists() -> [GrabDefinition] {
        let edited = grabFromRows(shared)
        return GRAB_FACTORY.map { factory in
            guard let row = edited.first(where: { $0.id == factory.id }) else { return factory }
            var d = factory
            if !row.items.isEmpty { d.items = row.items }
            if !row.label.isEmpty { d.label = row.label }
            if !row.icon.isEmpty { d.icon = row.icon }
            if !row.tone.isEmpty { d.tone = row.tone }
            return d
        }
    }
}

/// One workout's ticks and skips for one list — this device's own, never synced.
public struct GrabState: Equatable, Codable, Sendable {
    public static let resetHours = 6.0   // ticks older than this belong to a previous workout

    public var done: [String] = []
    public var skipped: [String] = []
    public var at: Date = Date.distantPast

    public init(done: [String] = [], skipped: [String] = [], at: Date = .distantPast) {
        self.done = done; self.skipped = skipped; self.at = at
    }

    /// The state as it applies NOW to THESE items: stale ticks are gone, and so
    /// is anything naming an item that no longer exists (edited away meanwhile).
    public func current(for items: [String], now: Date = Date()) -> GrabState {
        if now.timeIntervalSince(at) > GrabState.resetHours * 3600 { return GrabState() }
        return GrabState(done: done.filter(items.contains), skipped: skipped.filter(items.contains), at: at)
    }

    public func active(_ items: [String]) -> [String] { items.filter { !skipped.contains($0) } }
    /// Everything not skipped is in hand — and there is something to take at all.
    public func isComplete(_ items: [String]) -> Bool {
        let a = active(items)
        return !a.isEmpty && a.allSatisfy(done.contains)
    }
    public func missing(_ items: [String]) -> [String] { active(items).filter { !done.contains($0) } }

    /// Tap on a name: a skipped thing comes back; otherwise it is ticked or unticked.
    public func tapped(_ name: String, now: Date = Date()) -> GrabState {
        var s = self; s.at = now
        if skipped.contains(name) { s.skipped.removeAll { $0 == name } }
        else if done.contains(name) { s.done.removeAll { $0 == name } }
        else { s.done.append(name) }
        return s
    }
    /// ⊘ on a name: leave it behind just this once (and it cannot be ticked), or take it after all.
    public func skipToggled(_ name: String, now: Date = Date()) -> GrabState {
        var s = self; s.at = now
        if skipped.contains(name) { s.skipped.removeAll { $0 == name } }
        else { s.skipped.append(name); s.done.removeAll { $0 == name } }
        return s
    }
}
