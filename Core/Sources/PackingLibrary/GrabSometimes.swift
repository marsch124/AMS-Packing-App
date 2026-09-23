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
    @discardableResult
    public mutating func setSometimes(listId: String, names: [String]) -> Bool {
        guard GRAB_FACTORY.contains(where: { $0.id == listId }) else { return false }
        let onTheList = Set(grabLists().first { $0.id == listId }?.items.map(normName) ?? [])
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
        let items = grabLists().first { $0.id == listId }?.items ?? []
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
}
