import Foundation
import PackingCore

// "Only sometimes": things on a grab list that he takes perhaps one time in ten.
//
// They are on the list because they belong to it — a safety buoy belongs to open
// water swimming — but he does not want to tick them off every single time. So
// they start SKIPPED, greyed and out of the count, and one tap brings one into
// today's swim. The skip itself is still this device's working state and clears
// after six hours (GrabLists.swift); what is kept here is only the DEFAULT.
//
// Kept in the library's own `meta`, not in a shared row: PackingCore keeps only
// the shared kinds the WEB APP knows (`SHARED_KINDS`) and blanks anything else on
// the way back from storage — a new kind is silently erased. The round-trip test
// caught that. `meta` is ours, survives the store, and rides in the backup as
// `prefs.grab.sometimes`.

public let GRAB_SOMETIMES_META = "grabSometimes"

extension Library {
    /// The names on this list that he only takes sometimes.
    public func sometimes(listId: String) -> [String] {
        (meta[GRAB_SOMETIMES_META]?[listId]?.arrayValue ?? []).compactMap { $0.stringValue }
    }

    /// Every list's marks, as the backup writes them.
    public func sometimesByList() -> [String: [String]] {
        var out: [String: [String]] = [:]
        for (listId, names) in meta[GRAB_SOMETIMES_META]?.objectValue ?? [:] {
            let clean = (names.arrayValue ?? []).compactMap { $0.stringValue }
            if !clean.isEmpty { out[listId] = clean }
        }
        return out
    }

    /// Put them back, as the import reads them.
    public mutating func setSometimesByList(_ all: [String: [String]]) {
        var o: [String: JSONValue] = [:]
        for (listId, names) in all where !names.isEmpty { o[listId] = JSONValue(names) }
        if o.isEmpty { meta[GRAB_SOMETIMES_META] = nil } else { meta[GRAB_SOMETIMES_META] = .object(o) }
    }

    /// Say which of a list's things are "only sometimes". Names not on the list
    /// are dropped; an empty answer removes the row rather than storing nothing.
    /// Any list — his own ones too (until 4 Oct 2026 only the original six could
    /// have a "1 in 10", and his marks on his own lists were silently refused).
    @discardableResult
    public mutating func setSometimes(listId: String, names: [String]) -> Bool {
        guard let list = grabList(id: listId) else { return false }
        let onTheList = Set(list.items.map(normName))
        var seen = Set<String>()
        let clean = names.map(jsTrim).filter {
            !$0.isEmpty && onTheList.contains(normName($0)) && seen.insert(normName($0)).inserted
        }
        var all = sometimesByList()
        all[listId] = clean
        setSometimesByList(all)
        return true
    }

    /// Turn one thing's default on or off.
    @discardableResult
    public mutating func setSometimes(listId: String, name: String, on: Bool) -> Bool {
        var names = sometimes(listId: listId)
        let key = normName(name)
        if on {
            guard !names.contains(where: { normName($0) == key }) else { return true }
            names.append(name)
        } else {
            names.removeAll { normName($0) == key }
        }
        return setSometimes(listId: listId, names: names)
    }

    /// The state a grab list starts in: everything "only sometimes" already
    /// skipped. Applied when a session begins — never on top of one he is in the
    /// middle of, or a thing he brought in today would jump back out.
    public func openingState(listId: String, held: GrabState?, now: Date = Date()) -> GrabState {
        // EVERY list, his own too. It once looked among the original six only: a
        // list of his own came out with no things, so its ticks were filtered away
        // on every opening — and that empty state was saved over the real one.
        let items = grabList(id: listId)?.items ?? []
        let live = (held ?? GrabState()).current(for: items, now: now)
        // A session already under way is HIS: whatever he ticked or brought in
        // today stays exactly as it is.
        if live.at != Date.distantPast { return live }
        var fresh = GrabState()
        fresh.at = now
        // The names as the LIST spells them — the state matches by string.
        let mine = Set(sometimes(listId: listId).map(normName))
        fresh.skipped = items.filter { mine.contains(normName($0)) }
        return fresh
    }

    /// The session after he saves an edit of the list: today's ticks STAY. Until 5 Oct
    /// 2026 every Save started the session over — even a Save with nothing changed
    /// threw away what he had already picked up. Now a name edited away drops out; a
    /// thing he has just marked "1 in 10" is set aside, unless it is already in his
    /// hand; one he has just unmarked comes back into the count. A session that had
    /// not begun (or has run out) starts from the defaults, as an opening does.
    public func stateAfterEdit(listId: String, held: GrabState?, markedBefore: [String], now: Date = Date()) -> GrabState {
        let items = grabList(id: listId)?.items ?? []
        var live = (held ?? GrabState()).current(for: items, now: now)
        guard live.at != Date.distantPast else { return openingState(listId: listId, held: nil, now: now) }
        let before = Set(markedBefore.map(normName))
        let after = Set(sometimes(listId: listId).map(normName))
        for name in items {
            let key = normName(name)
            if after.contains(key), !before.contains(key), !live.done.contains(name), !live.skipped.contains(name) {
                live.skipped.append(name)
            } else if before.contains(key), !after.contains(key) {
                live.skipped.removeAll { $0 == name }
            }
        }
        return live
    }
}
