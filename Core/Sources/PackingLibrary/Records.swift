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
}

/// CloudKit cannot enforce a unique key, and two devices can create `phases/prep`
/// independently. So: records are grouped by (table, key); the NEWEST wins; the
/// content is the tiebreak so that both devices pick the same survivor.
/// Returns the survivors and the losers (which the caller deletes).
public func settleDuplicates(_ records: [StoredRecord]) -> (kept: [StoredRecord], dropped: [StoredRecord]) {
    var best: [RecordID: StoredRecord] = [:]
    var order: [RecordID] = []
    var dropped: [StoredRecord] = []
    for r in records {
        guard let have = best[r.id] else { best[r.id] = r; order.append(r.id); continue }
        let newer: Bool
        if r.updatedAt != have.updatedAt { newer = r.updatedAt > have.updatedAt }
        else { newer = r.json.text() > have.json.text() }
        if newer { dropped.append(have); best[r.id] = r } else { dropped.append(r) }
    }
    return (order.compactMap { best[$0] }, dropped)
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
