import Foundation
import PackingCore

// Records — the shape everything is STORED and SYNCED in. See docs/store.md.
//
// One small record per thing, and one generic shape for all of them, so the
// CloudKit schema never has to change: a new field on an item is a change to
// PackingCore, not a schema deployment a TestFlight build silently depends on.

/// Which kind of thing a record holds.
public enum Table: String, CaseIterable, Sendable, Codable {
    case items          // the catalogue: one record per physical thing
    case memberships    // one per (thing, template) — keyed by MEMBERSHIP id: the same
                        // thing can sit on one template twice with a different "When"
    case templates      // a template without its items
    case trips          // a trip without its lines
    case entries        // one per trip line — so a tick is ONE small record, and two
                        // devices ticking different lines of one trip both win
    case actions, kits, phases
    case shared         // the six author-made Settings lists, one record per entry
    case photos
    case meta           // facts about the library itself (the import marker…)
}

public struct RecordID: Hashable, Sendable, Comparable {
    public var table: Table
    public var key: String
    public init(_ table: Table, _ key: String) { self.table = table; self.key = key }
    public static func < (a: RecordID, b: RecordID) -> Bool {
        a.table.rawValue != b.table.rawValue ? a.table.rawValue < b.table.rawValue : a.key < b.key
    }
}

public struct StoredRecord: Equatable, Sendable {
    public var table: Table
    /// The thing's own id. STABLE for things that are the same thing on every
    /// device ("prep", "places:garage"); random only for what is genuinely new.
    public var key: String
    /// The id it belongs to, where that is how it is fetched (a line's trip, a
    /// membership's template). "" otherwise.
    public var parent: String
    /// The thing itself, exactly as PackingCore writes it.
    public var json: JSONValue
    /// A photo's bytes. nil for everything else.
    public var blob: Data?
    public var updatedAt: Date

    public init(table: Table, key: String, parent: String = "", json: JSONValue,
                blob: Data? = nil, updatedAt: Date = PackingEnv.now()) {
        self.table = table; self.key = key; self.parent = parent
        self.json = json; self.blob = blob; self.updatedAt = updatedAt
    }
    public var id: RecordID { RecordID(table, key) }

    /// Same content? (`updatedAt` is when it was written, not what it says.)
    public func sameContent(as other: StoredRecord) -> Bool {
        table == other.table && key == other.key && parent == other.parent
            && json == other.json && blob == other.blob
    }

    /// The same in every respect, its time included: two such twins cannot be told apart (0.94).
    public func identical(to other: StoredRecord) -> Bool {
        sameContent(as: other) && updatedAt == other.updatedAt
    }

    /// Does this twin win over `other` (same table and key)? The NEWER wins; on an exact tie the
    /// greater JSON text, then the greater parent, then the greater photo bytes — so both devices
    /// choose the same survivor whatever order they read the twins in. (Until 0.94 a tie on time and
    /// text kept whichever was read first: twins differing only in their parent or a photo's bytes
    /// could settle differently on the two devices.) False for identical twins.
    public func beats(_ other: StoredRecord) -> Bool {
        if updatedAt != other.updatedAt { return updatedAt > other.updatedAt }
        let (mine, theirs) = (json.text(), other.json.text())
        if mine != theirs { return mine > theirs }
        if parent != other.parent { return parent > other.parent }
        let (a, b) = (blob ?? Data(), other.blob ?? Data())
        if a != b { return a.lexicographicallyPrecedes(b) == false }
        return blob != nil && other.blob == nil
    }
}

/// CloudKit cannot enforce a unique key, and two devices can create `phases/prep`
/// independently. So: records are grouped by (table, key); the NEWEST wins; the
/// content is the tiebreak so that both devices pick the same survivor (`beats`).
/// Returns the survivors and the losers (which `StoreSession.load` has the store delete).
public func settleDuplicates(_ records: [StoredRecord]) -> (kept: [StoredRecord], dropped: [StoredRecord]) {
    var best: [RecordID: StoredRecord] = [:]
    var order: [RecordID] = []
    var dropped: [StoredRecord] = []
    for r in records {
        guard let have = best[r.id] else { best[r.id] = r; order.append(r.id); continue }
        if r.beats(have) { dropped.append(have); best[r.id] = r } else { dropped.append(r) }
    }
    return (order.compactMap { best[$0] }, dropped)
}

/// What a store holding several rows under one key (twins) does with them when `put` is stored
/// there — `CloudStore.apply`'s rule (0.94, item 3 of the outside review of 0.92).
///
/// Both devices settle the same twins, and neither can tell which row the other calls its own:
/// CloudKit's name for a row is not handed out by SwiftData, and a field of our own would need a
/// schema deployment. So the rule reads only what both devices hold alike — what the rows SAY —
/// never the order a fetch returns them in. (Until 0.94 the winner was written into the FIRST row
/// fetched and the others deleted; a device's own row tends to come first, so each device kept its
/// own and deleted the other's, and once that synced both were gone.)
/// - A row already holds exactly `put` (the winner, which `StoreSession.load` writes again to settle
///   twins): every such row is kept untouched, and only rows holding something ELSE are deleted.
///   Rows identical to each other are never told apart, so neither is deleted.
/// - No row holds it (a change made here): every row takes it and none is deleted — the other
///   device may be settling the same twins at that very moment.
public struct TwinPlan: Equatable, Sendable {
    /// The rows (positions in what was handed over) that take `put`'s content.
    public var write: [Int] = []
    /// The rows deleted.
    public var delete: [Int] = []
    public init(write: [Int] = [], delete: [Int] = []) { self.write = write; self.delete = delete }
}

/// `rows`: every row the store holds under `put`'s key, in any order; nil for a row it cannot read.
public func planTwins(_ rows: [StoredRecord?], storing put: StoredRecord) -> TwinPlan {
    let holding = rows.indices.filter { rows[$0]?.identical(to: put) == true }
    if holding.isEmpty { return TwinPlan(write: Array(rows.indices)) }
    return TwinPlan(delete: rows.indices.filter { !holding.contains($0) })
}

/// What has to be written and deleted to turn one set of records into another.
/// The write path of the whole app: change the library, diff, store the diff.
public struct RecordChanges: Equatable, Sendable {
    public var puts: [StoredRecord] = []
    public var deletes: [RecordID] = []
    public var isEmpty: Bool { puts.isEmpty && deletes.isEmpty }
    public init(puts: [StoredRecord] = [], deletes: [RecordID] = []) { self.puts = puts; self.deletes = deletes }
}

public func recordChanges(from old: [StoredRecord], to new: [StoredRecord]) -> RecordChanges {
    var before: [RecordID: StoredRecord] = [:]
    for r in old { before[r.id] = r }
    var changes = RecordChanges()
    var seen = Set<RecordID>()
    for r in new {
        seen.insert(r.id)
        if let b = before[r.id], b.sameContent(as: r) { continue }
        changes.puts.append(r)
    }
    changes.deletes = old.map(\.id).filter { !seen.contains($0) }.sorted()
    return changes
}
