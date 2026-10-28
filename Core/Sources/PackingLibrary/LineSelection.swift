import Foundation
import PackingCore

// Several lines of a trip selected on the Mac (0.105) — his yes of 28 Oct 2026 to "Select several lines
// (Mac): ⇧-click or ⌘-click lines on a trip, then tick, set aside or move to another bag in one go."
//
// Apple's way, as in the Finder and Mail: ⌘-click puts a line in the selection or takes it out, ⇧-click
// selects every line from the last one ⌘-clicked to this one in the order the list SHOWS them (across its
// headings), ⌘A selects every line shown, Esc clears. A plain click still ticks its line (the trip screen).
// What the screen does with the selection is decided here, where the model's tests hold it; the actions
// themselves are the library's (`setChecked(_:tripId:entryIds:)`, `setAside(_:tripId:entryIds:)`,
// `moveLines(tripId:entryIds:toBag:)`), each ONE change.

/// The lines selected on a trip — by line id (under Template a line stands twice; both copies show it).
public struct LineSelection: Equatable, Sendable {
    public private(set) var ids: Set<String> = []
    /// Where a ⇧-click ranges from: the line last ⌘-clicked (or the first ⇧-clicked, with none before).
    public private(set) var anchor: String?
    /// What was selected before the ⇧-clicks from this anchor began: a second ⇧-click moves the END of the
    /// range — lines the first one took in and the second leaves out are let go (the Finder's way).
    private var before: Set<String>?

    public init() {}

    public var count: Int { ids.count }
    public var isEmpty: Bool { ids.isEmpty }
    public func contains(_ id: String) -> Bool { ids.contains(id) }

    /// ⌘-click: the line in, or out again — and the next ⇧-click ranges from it.
    public mutating func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        anchor = id
        before = nil
    }

    /// ⇧-click: every line from the anchor to this one, in `shown` — the lines in the order the list shows
    /// them, the folded ones left out — added to what was selected before. With no anchor (or one no longer
    /// shown) the line alone, and it becomes the anchor.
    public mutating func extend(to id: String, shown: [String]) {
        guard let from = anchor, let a = shown.firstIndex(of: from), let b = shown.firstIndex(of: id) else {
            ids.insert(id)
            anchor = id
            before = ids
            return
        }
        if before == nil { before = ids }
        ids = (before ?? []).union(shown[min(a, b)...max(a, b)])
    }

    /// ⌘A: every line shown.
    public mutating func selectAll(_ shown: [String]) {
        ids = Set(shown)
        anchor = shown.first
        before = nil
    }

    /// Esc, a plain click, or Clear.
    public mutating func clear() {
        ids = []
        anchor = nil
        before = nil
    }

    /// Only lines still shown stay selected: a heading folded, another grouping that leaves a line out, a line
    /// gone from the trip.
    public mutating func keep(only shown: [String]) {
        let still = Set(shown)
        ids.formIntersection(still)
        if let a = anchor, !still.contains(a) { anchor = nil }
        before = before?.intersection(still)
    }

    /// The selected lines in the order the list shows them, each once — what an action is given.
    public func ordered(_ shown: [String]) -> [String] {
        var seen = Set<String>()
        return shown.filter { ids.contains($0) && seen.insert($0).inserted }
    }

    /// "1 thing", "4 things" — how the line's menu names what it acts on ("Tick 4 things").
    public static func things(_ n: Int) -> String { n == 1 ? "1 thing" : "\(n) things" }
}

extension Library {
    /// Not this time — or take them back — for these lines of a trip (0.105, several lines selected): one
    /// `setAside` each, so each also takes the tick and its companions along, as ⊘ does. A line already so is
    /// left alone. Returns how many changed.
    @discardableResult
    public mutating func setAside(_ aside: Bool, tripId: String, entryIds: [String]) -> Int {
        var changed = 0
        for id in entryIds {
            guard let line = trip(tripId)?.entries.first(where: { $0.id == id }), isSetAside(line) != aside,
                  setAside(aside, tripId: tripId, entryId: id) else { continue }
            changed += 1
        }
        return changed
    }

    /// Move to bag (0.105): these lines go into `bag` — on THIS trip only, never the thing or its templates
    /// (as Not this time is the trip's own). Each line moved is marked as changed on the trip (`edited`), so a
    /// rebuild from Trip settings keeps it and a later change to its thing (`followThing`) does not take it
    /// back. Its pocket goes unless the new bag has one of that name — a ticked line then gets the new bag's
    /// usual one, as a tick does; the same for its pocket on the way home. A reminder ("To do") goes in no bag,
    /// and a line already in that bag is left alone. Returns how many moved.
    @discardableResult
    public mutating func moveLines(tripId: String, entryIds: [String], toBag bag: String) -> Int {
        let name = jsTrim(bag)
        guard !name.isEmpty, let t = trips.firstIndex(where: { $0.id == tripId }) else { return 0 }
        let pocketsThere = pockets(bag: name)
        func keeps(_ pocket: String) -> Bool { pocketsThere.contains { normName($0) == normName(pocket) } }
        var moved = 0
        for id in entryIds {
            guard let e = trips[t].entries.firstIndex(where: { $0.id == id }) else { continue }
            let line = trips[t].entries[e]
            guard !Library.isReminder(line), normName(line.container) != normName(name) else { continue }
            trips[t].entries[e].container = name
            trips[t].entries[e].edited = true
            let pocket = Library.pocket(line)
            if !pocket.isEmpty, !keeps(pocket) {
                trips[t].entries[e].extra[POCKET_KEY] = nil
                if line.checked { prechoosePocket(trip: t, entry: e) }
            }
            let home = Library.homePocket(line)
            if !home.isEmpty, !keeps(home) { trips[t].entries[e].extra[HOME_POCKET_KEY] = nil }
            moved += 1
        }
        if moved > 0 { trips[t].updatedAt = nowISO() }
        return moved
    }
}
