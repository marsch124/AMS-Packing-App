import Foundation
import PackingCore

// The two moves between the store and the library in memory — reading everything,
// and storing the difference. The app's LibraryModel makes exactly these moves and
// only publishes what they answer; they live here so a model test can reach them
// (the spec pass, 2026-10-05: reload, commit and a refusing store had no test).
//
// ⚠️ What they cost (the spec pass, 2026-10-05 — written down so a rewrite decides it
// on purpose): `save` rebuilds EVERY record of the library — base64-decoding every
// photo — and diffs them all, so the cost of one tick grows with the library and its
// photos; `load` reads the whole store, and runs on every iCloud notification. Fine
// at a few thousand records; the first thing to change if a tick ever feels slow.

public enum StoreSession {
    /// Read everything the store holds. Twins of a key (CloudKit cannot keep a key
    /// unique) are settled by rule, and the survivors written again so the store
    /// drops the losers — both devices end up holding the same records.
    ///
    /// `held` is what the store is believed to hold, rebuilt from the LIBRARY, not
    /// from what was read: records the library cannot see (a line of a trip deleted on
    /// the other device, a table a newer build added) are therefore never in it, and a
    /// later difference never deletes them.
    public static func load(_ store: LibraryStore) throws -> (library: Library, held: [StoredRecord]) {
        let settled = settleDuplicates(try store.loadAll())
        if !settled.dropped.isEmpty {
            let losers = Set(settled.dropped.map(\.id))
            try store.apply(RecordChanges(puts: settled.kept.filter { losers.contains($0.id) }))
        }
        var library = Library(records: settled.kept)
        // Rows whose note or "How many" an older build froze from their thing follow the
        // thing again (spec 04, the spec pass of 5 Oct 2026). Nothing on screen changes;
        // only a place that still holds a copy is written, so a load with none writes nothing.
        let loaded = library.records()
        if library.letCopiedAnswersFollowTheirThings() > 0 {
            try store.apply(recordChanges(from: loaded, to: library.records()))
        }
        return (library, library.records())
    }

    /// Store what changed between `held` and `next`. nil = nothing changed and
    /// nothing was written. A store that refuses throws, and nothing is believed
    /// written: the caller keeps its old library and its old `held`.
    public static func save(_ next: Library, held: [StoredRecord], to store: LibraryStore) throws -> [StoredRecord]? {
        let records = next.records()
        let changes = recordChanges(from: held, to: records)
        guard !changes.isEmpty else { return nil }
        try store.apply(changes)
        return records
    }
}
