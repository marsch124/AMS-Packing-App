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
    /// The list as he arranged it in Edit, top to bottom: his things and (0.85) his own
    /// headings (`GrabHeadings.swift`).
    public var lines: [GrabLine]

    /// Its THINGS alone, in his order — what is ticked, skipped, counted, marked "1 in 10"
    /// and said to be missing. Never a heading. Read only: a list is changed through its
    /// `lines`, so no change of things can drop his headings unseen.
    public var items: [String] {
        lines.compactMap { if case .thing(let n) = $0 { return n } else { return nil } }
    }

    /// A list of things alone (the factory six, and every list until 0.85).
    public init(id: String, label: String, title: String, tone: String, icon: String, items: [String]) {
        self.init(id: id, label: label, title: title, tone: tone, icon: icon, lines: items.map { .thing($0) })
    }

    public init(id: String, label: String, title: String, tone: String, icon: String, lines: [GrabLine]) {
        self.id = id; self.label = label; self.title = title; self.tone = tone; self.icon = icon; self.lines = lines
    }
}

/// The drawings this app has for a grab list (`GrabDoodle`), and the tones it
/// colours one in (`GrabTone`). A list received from elsewhere that names anything
/// else is given the standard look a new list gets — no drawing (it wears its
/// initial) and blue — rather than a runner it never was (5 Oct 2026).
public let GRAB_ICONS: Set<String> = ["swim", "bike", "run", "swim-sun", "bike-sun", "run-sun"]
public let GRAB_TONES: Set<String> = ["blue", "yellow", "green", "red", "purple", "teal"]

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
            // His things and his headings (0.85), read from the names the row holds. A row
            // holding no thing at all keeps the factory's things.
            let lines = GrabLine.lines(stored: row.items)
            if lines.contains(where: { !$0.isHeading }) { d.lines = lines }
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
    /// What the counter says, for the list AS IT STANDS — "<in hand> of <active>",
    /// "· <skipped> skipped". Counted against the list itself, not the session's own
    /// names: a list edited on the other device while it is open here no longer
    /// reads "8 of 7" (5 Oct 2026).
    public func inHand(_ items: [String]) -> Int { active(items).filter(done.contains).count }
    public func skippedCount(_ items: [String]) -> Int { items.filter(skipped.contains).count }

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

extension Library {
    /// Any grab list by its id — one of the original six or one of his own.
    public func grabList(id: String) -> GrabDefinition? {
        allGrabLists().first { $0.id == id }
    }

    /// Save an edited grab list for the account — ONE `grab` row, so it reaches the
    /// other device like every other record (web app v163: the iPhone is where he
    /// edits them). What he did not change (the list's name, doodle, colour) keeps
    /// whatever it was. A list with nothing on it is refused: it would not be a list.
    ///
    /// The ONE door for an edit of a list's things, whichever kind it is. A list of
    /// his own is saved where his own lists live (the library's `meta`, also one
    /// record, synced). Until 4 Oct 2026 this door took the original six only, and
    /// his additions to a list he had made himself were silently thrown away.
    @discardableResult
    public mutating func saveGrabList(id: String, items newItems: [String]) -> Bool {
        saveGrabList(id: id, lines: newItems.map { .thing($0) })
    }

    /// The same for a list with his headings among its things (0.85): the lines are kept as
    /// he arranged them, each heading stored among the names in its reserved form
    /// (`GrabHeadings.swift`), so it travels wherever the names do. A list with headings but
    /// no thing is refused, as an empty one is.
    @discardableResult
    public mutating func saveGrabList(id: String, lines newLines: [GrabLine]) -> Bool {
        let clean = GrabLine.cleaned(newLines)
        guard clean.contains(where: { !$0.isHeading }) else { return false }
        guard let at = GRAB_FACTORY.firstIndex(where: { $0.id == id }) else {
            guard var own = ownGrabLists().first(where: { $0.id == id }) else { return false }
            own.lines = clean
            return saveOwnGrabList(own)
        }
        let before = grabFromRows(shared).first { $0.id == id }
        var rows = grabToRows([GrabList(id: id, items: GrabLine.stored(clean), label: before?.label ?? "",
                                        icon: before?.icon ?? "", tone: before?.tone ?? "")])
        guard !rows.isEmpty else { return false }
        rows[0].order = Double(at)   // the Home-row order, as the web app keeps it
        shared.removeAll { $0.kind == "grab" && $0.id == rows[0].id }
        shared.append(rows[0])
        return true
    }

    /// What the editor's Save does: the list's things AND its "1 in 10" marks, both
    /// or neither. A list with nothing left on it is refused whole — until 5 Oct 2026
    /// the things were refused but the marks were still written, with no name left to
    /// mark, so every mark on the list was lost and nothing was said.
    @discardableResult
    public mutating func saveGrabEdit(id: String, items: [String], sometimes names: [String]) -> Bool {
        saveGrabEdit(id: id, lines: items.map { .thing($0) }, sometimes: names)
    }

    /// The editor's Save onto the list as it is NOW (0.95, residual of the outside review): the lines
    /// and "1 in 10" marks as Edit opened (`opened`, `openedSometimes`) and as he leaves them. What he
    /// added, took off or moved goes in; what the other device added or marked meanwhile stays (the
    /// list rule of `Library.mergeList`). Until 0.95 the editor's whole list was written.
    @discardableResult
    public mutating func saveGrabEdit(id: String, opened: [GrabLine], openedSometimes: [String],
                                      lines: [GrabLine], sometimes: [String]) -> Bool {
        let now = grabList(id: id)?.lines ?? opened
        func key(_ l: GrabLine) -> String { l.isHeading ? "h:" + jsTrim(l.name) : "t:" + normName(l.name) }
        let merged = Library.mergeList(now, was: GrabLine.cleaned(opened), now: GrabLine.cleaned(lines), id: key) { _, _, b in b }
        let was = Set(openedSometimes.map(normName)), mine = Set(sometimes.map(normName))
        var marks = self.sometimes(listId: id).filter { !(was.contains(normName($0)) && !mine.contains(normName($0))) }
        for n in sometimes where !was.contains(normName(n)) && !marks.contains(where: { normName($0) == normName(n) }) { marks.append(n) }
        return saveGrabEdit(id: id, lines: merged, sometimes: marks)
    }

    /// The editor's Save with his headings among the things (0.85).
    @discardableResult
    public mutating func saveGrabEdit(id: String, lines: [GrabLine], sometimes names: [String]) -> Bool {
        guard saveGrabList(id: id, lines: lines) else { return false }
        setSometimes(listId: id, names: names)
        return true
    }
}

// Twins of an original list's row (0.97, his check 7 of 21 Oct 2026). Mac: a grab list's Edit open;
// iPhone: the same list's Edit, ✕ on one thing, Save; Mac, before that had arrived: ✕ on another,
// Save. The list had never been changed, so neither device held a row for it, and each made its own
// under the list's fixed key ("grab:swim") — twins. The load kept the newer whole: the other
// device's removal came back. Twins of such a row can only come from two devices each changing the
// ORIGINAL list (once a row is stored, a change goes into it), so each twin is read as one edit of the
// original list and both are kept — what either removed stays removed, what either added stays —
// in the order of the newest, with its name, drawing and colour, and the other's where the newest
// left the original's.

extension Library {
    /// An original grab list's row (`shared`, "grab:<id>").
    static func isGrabRow(_ id: RecordID) -> Bool { id.table == .shared && id.key.hasPrefix("grab:") }

    /// Twins of one original list's row as one: the newest, with what each other twin changed on the
    /// original list put in (`mergeList`). Both devices read the twins in the same order (`beats`),
    /// so both make the same row, with the newest twin's time. nil: no original list's row.
    static func mergeGrabTwins(_ twins: [StoredRecord]) -> StoredRecord? {
        let ordered = twins.sorted { $0.beats($1) }
        guard var out = ordered.first else { return nil }
        var row = SharedRow(json: out.json)
        let lists = ordered.map { grabFromRows([SharedRow(json: $0.json)]).first }
        guard let gid = lists[0]?.id, let original = GRAB_FACTORY.first(where: { $0.id == gid }) else { return nil }
        func key(_ l: GrabLine) -> String { l.isHeading ? "h:" + jsTrim(l.name) : "t:" + normName(l.name) }
        var lines = GrabLine.lines(stored: lists[0]?.items ?? [])
        var data = row.data.objectValue ?? [:]
        for list in lists.dropFirst() {
            guard let list, list.id == gid else { continue }
            lines = Library.mergeList(lines, was: original.lines, now: GrabLine.lines(stored: list.items), id: key) { _, _, b in b }
            let theirs = ["label": list.label, "icon": list.icon, "tone": list.tone]
            for (field, value) in theirs where (data[field]?.stringValue ?? "").isEmpty && !value.isEmpty { data[field] = .string(value) }
        }
        data["items"] = JSONValue(GrabLine.stored(lines))
        guard .object(data) != row.data else { return out }      // nothing of the others' to put in
        row.data = .object(data)
        let label = data["label"]?.stringValue ?? ""
        row.name = label.isEmpty ? gid : label
        out.json = row.json
        return out
    }
}
