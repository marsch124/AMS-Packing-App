import Foundation
import PackingCore

// 0.101, his list of 26 Oct 2026 — three asks about folding things away and putting first things first:
//  1. "There is a red frame called 'Before You Go.' I would like that to be collapsible so I can
//     toggle it into one line."
//  2. "When in pack mode, I would like the ability to toggle or collapse all items with one click,
//     not only the individual 'From where', 'Into' etc areas."
//  3. "completed to-do's should be tucked away in a toggle. Priority to-do's in a separate area."
//
// The trip's folds are the ones the trip screen has kept since 26 Sep 2026 (`TripFolds`, one
// "<trip>|<sorting>|<heading>" per line in AppStorage `ams.trip.folded`). Fold all writes every
// heading of the sorting at once; Before you go keeps its fold in the same string under the
// "sorting" `beforego` — no sorting has that id — so a deleted trip's choice goes with its folds.

extension TripFolds {
    /// Every heading of one trip under one sorting folded (`folded`), or every one opened — Fold all
    /// and Unfold all (0.101). Folds of other sortings and of Before you go are left alone; the folds
    /// of trips not in `trips` are dropped, as by every fold.
    public static func settingAll(_ raw: String, trip: String, view: String, headings: [String], folded: Bool,
                                  trips: Set<String>) -> String {
        let mine = Set(headings.map { key(trip: trip, view: view, heading: $0) })
        var keys = raw.split(separator: "\n").map(String.init).filter { trips.contains(tripOfKey($0)) && !mine.contains($0) }
        if folded { keys += headings.map { key(trip: trip, view: view, heading: $0) }.uniqued() }
        return keys.joined(separator: "\n")
    }

    /// Are all these headings folded? (Nothing to fold = no.)
    public static func allFolded(_ raw: String, trip: String, view: String, headings: [String]) -> Bool {
        !headings.isEmpty && headings.allSatisfy { isFolded(raw, key(trip: trip, view: view, heading: $0)) }
    }

    // MARK: Before you go (0.101)

    /// The "sorting" Before you go's fold is kept under — never a sorting's id.
    static let beforeYouGo = "beforego"

    /// Is the trip's Before you go folded to its one line? His choice on this device when he made
    /// one; until then folded only when All set (0.77's rule: nothing left, nothing to show).
    public static func beforeYouGoFolded(_ raw: String, trip: String, allSet: Bool) -> Bool {
        if isFolded(raw, key(trip: trip, view: beforeYouGo, heading: "folded")) { return true }
        if isFolded(raw, key(trip: trip, view: beforeYouGo, heading: "open")) { return false }
        return allSet
    }

    /// A press on Before you go's line: the other way from how it shows now, kept as his choice.
    public static func beforeYouGoToggled(_ raw: String, trip: String, allSet: Bool, trips: Set<String>) -> String {
        let now = beforeYouGoFolded(raw, trip: trip, allSet: allSet)
        var keys = beforeYouGoReset(raw, trip: trip).split(separator: "\n").map(String.init)
            .filter { trips.contains(tripOfKey($0)) }
        keys.append(key(trip: trip, view: beforeYouGo, heading: now ? "open" : "folded"))
        return keys.joined(separator: "\n")
    }

    /// His choice forgotten — back to the rule (a tapped "Charge tonight" opens a folded card).
    public static func beforeYouGoReset(_ raw: String, trip: String) -> String {
        let gone: Set<String> = [key(trip: trip, view: beforeYouGo, heading: "folded"),
                                 key(trip: trip, view: beforeYouGo, heading: "open")]
        return raw.split(separator: "\n").map(String.init).filter { !gone.contains($0) }.joined(separator: "\n")
    }

    private static func tripOfKey(_ key: String) -> String { String(key.prefix { $0 != "|" }) }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - The To do page in parts (0.101)

/// The To do page's lines in the order the central list has always had them (`compareActions`:
/// open before done, high before normal, sooner before later), cut in three: the open priorities,
/// the other open ones, and those done. Each part is a run of `sortedActions`, so a line's place
/// in the whole list (its `action-<n>` on the screen) is its part's start plus its place in it.
public struct ToDoParts: Equatable, Sendable {
    public var priority: [ActionItem]
    public var others: [ActionItem]
    public var done: [ActionItem]

    public var open: Int { priority.count + others.count }
    public var all: [ActionItem] { priority + others + done }
}

extension Library {
    /// The To do page's parts (`kind` "todo"); for To buy ("shopping") nothing is a priority there —
    /// its open lines are all `others`.
    public func toDoParts(kind: String = "todo") -> ToDoParts {
        let all = sortedActions(kind: kind)
        let open = all.filter { !$0.done }
        let priority = kind == "todo" ? open.filter(Library.isPriority) : []
        return ToDoParts(priority: priority, others: open.filter { !priority.contains($0) },
                         done: all.filter(\.done))
    }

    /// A priority: the web app's own field, `priority` "high" — what the add bar's "!" has always set.
    public static func isPriority(_ a: ActionItem) -> Bool { a.priority == "high" }

    /// Mark a to-do a priority, or take that off (0.101) — the web app's `priority` field, "high" or
    /// "normal", stamped like a tick so the field-wise merges see it as the change it is.
    @discardableResult
    public mutating func setActionPriority(_ high: Bool, id: String) -> Bool {
        guard let n = actions.firstIndex(where: { $0.id == id }) else { return false }
        let want = high ? "high" : "normal"
        guard actions[n].priority != want else { return false }
        actions[n].priority = want
        actions[n].updatedAt = nowISO()
        return true
    }
}
