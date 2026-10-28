import Foundation
import PackingCore

// ⌘Z undo everywhere (0.105). His words, 28 Oct 2026: "2. ⌘Z - yes please" — to the proposal "⌘Z undo
// everywhere (Mac): undo and redo the last change, whatever page it was on."
//
// What a step is: everything ONE change of this device did to his library — a tick, a heading's tick,
// a line set aside, things added to a trip, a thing's or a template's Done, a delete — as the RECORDS it
// touched, before and after (`UndoStep`). The records are what is stored and synced, one small record
// per thing (docs/store.md), so a step is the same shape for every kind of change and needs no code of
// its own per screen.
//
// THE RULE WITH SYNC (spec 01 §5, "Undo and the other device"). An undo is a NORMAL change: it writes
// what it takes back like any tap, and it takes back only what is still as this step left it. Record
// by record and field by field, three ways — as the step wrote it, as it was before, as it is NOW:
//   - a field still as the step wrote it goes back to what it was;
//   - a field the step did not change is not touched (the other device's tick beside it stays);
//   - a field changed since (by the other device: a page's Done merges the same way, 0.93–0.97) is
//     KEPT as it is now and named in a small note — "Partly undone — Passport was changed on your iPhone";
//   - a list (the lines of a trip, a template's sections, what a kit holds) loses what the step added
//     and gets back what it took away; what was added to it meanwhile stays (`mergeList`, 0.95);
//   - a record the step deleted comes back with its own id — the same record on both devices, never a
//     copy; one made again meanwhile is left as it is; one the step changed that was deleted meanwhile
//     stays deleted (0.95's rule: a record gone here stays gone); one the step made goes, unless it was
//     changed meanwhile.
// The time a record was last changed (`updatedAt`, a bag's Last edited, a tick's moment) is no change of
// its own: it goes back with the step when it can and is never named.
//
// Redo is the same move the other way: an undo is itself a step (`Reverted.inverse`).
//
// Per device, in memory: the history is gone when the app quits, holds 50 steps, and is forgotten when
// the library is replaced or its store reopened (a restore, the first import, a restart of the sync,
// 0.104) — a step of the library before means nothing to the library after.

/// One change this device made to his library, as Edit ▸ Undo knows it.
public struct UndoStep: Identifiable, Equatable, Sendable {
    public let id: Int
    /// What the menu says after "Undo" or "Redo" — Apple's way: "Tick Passport", "Delete Weekend in the hills".
    public var name: String
    /// The name came from the screen (a heading's tick, Clear every tick), not from the records.
    public var named: Bool
    /// Every record the change touched, as it was (absent: it did not exist) …
    public var before: [RecordID: StoredRecord]
    /// … and as the change left it (absent: deleted).
    public var after: [RecordID: StoredRecord]
    /// The records it touched, in order.
    public var touched: [RecordID]

    /// The step from one set of records to the next; nil when nothing changed. `library` is the library
    /// AFTER the change (names of things a row or a line points at).
    public static func make(id: Int, name: String?, from old: [StoredRecord], to new: [StoredRecord],
                            in library: Library) -> UndoStep? {
        make(id: id, name: name, old: old, changes: recordChanges(from: old, to: new), in: library)
    }

    /// The same from a difference already made (`StoreSession.saveReturningChanges`): no second comparison.
    public static func make(id: Int, name: String?, old: [StoredRecord], changes: RecordChanges,
                            in library: Library) -> UndoStep? {
        guard !changes.isEmpty else { return nil }
        var was: [RecordID: StoredRecord] = [:]
        for r in old { was[r.id] = r }
        var before: [RecordID: StoredRecord] = [:], after: [RecordID: StoredRecord] = [:]
        var touched: [RecordID] = []
        for r in changes.puts {
            if let b = was[r.id] { before[r.id] = b }
            after[r.id] = r
            touched.append(r.id)
        }
        for id in changes.deletes where was[id] != nil {
            before[id] = was[id]
            touched.append(id)
        }
        guard !touched.isEmpty else { return nil }
        var step = UndoStep(id: id, name: "", named: name != nil, before: before, after: after, touched: touched.sorted())
        step.name = name ?? library.undoName(step)
        return step
    }

    /// This step and the next one of the same press (two changes made by one tap or one Done — a thing's
    /// page renames, then writes the rest) as one: the first state of each record and the last.
    public func joined(with next: UndoStep, in library: Library) -> UndoStep? {
        var out = self
        for id in next.touched {
            if !out.touched.contains(id) {
                out.touched.append(id)
                if let b = next.before[id] { out.before[id] = b } else { out.before[id] = nil }
            }
            out.after[id] = next.after[id]
        }
        // A record put back as it was within the same press is no change of the step.
        out.touched = out.touched.filter { id in
            switch (out.before[id], out.after[id]) {
            case (nil, nil): return false
            case let (b?, a?): return !b.sameContent(as: a)
            default: return true
            }
        }.sorted()
        guard !out.touched.isEmpty else { return nil }
        if !named {
            if next.named { out.name = next.name; out.named = true } else { out.name = library.undoName(out) }
        }
        return out
    }
}

/// A step taken back: the library as it is after, the step that would put back what was taken back (an
/// undo's Redo, a redo's Undo), and what was kept because it had changed since.
public struct Reverted: Equatable, Sendable {
    public var library: Library
    /// nil: nothing changed — everything the step did had been changed since, or was already back.
    public var inverse: UndoStep?
    /// The things changed since by the other device, kept as they are now — named in the note.
    public var kept: [String]
    /// Nothing at all could be taken back.
    public var nothing: Bool { inverse == nil }
}

// MARK: - Taking a step back

extension Library {
    /// The time a record was last changed — no change of its own (a heading's tick, a page's follow and
    /// the other device each write it): taken back with the step where it is as the step left it,
    /// otherwise left as it is, and never named in the note.
    static let undoStamps: Set<String> = ["updatedAt", "doneAt", BAG_EDITED_KEY, TICKED_AT_KEY]

    /// This library with `step` taken back, by the rule at the top of this file. `inverseId`: the id of
    /// the step that would put it back. `quiet`: records a LATER step of this device changed (a banner's
    /// Undo of a step that is not the last) — what they hold now is this device's own, not the other
    /// device's, so it is kept without a word.
    public func reverting(_ step: UndoStep, inverseId: Int, quiet: Set<RecordID> = []) -> Reverted {
        let now = records()
        var current: [RecordID: StoredRecord] = [:]
        for r in now { current[r.id] = r }
        var next = current
        var kept: [String] = []
        for id in step.touched {
            var (value, clash) = Library.revert(current[id], was: step.after[id], back: step.before[id])
            // A line unticked by an undo keeps no tick moment it did not have (the other device ticked it
            // again meanwhile: the tick goes back, its later moment would stay behind on an unticked line).
            if id.table == .entries, var v = value, v.json["checked"]?.truthy != true,
               step.before[id]?.json[TICKED_AT_KEY] == nil, v.json[TICKED_AT_KEY] != nil {
                v.json[TICKED_AT_KEY] = nil
                value = v
            }
            // A buy line brought back comes without the reminder it had: that reminder went from Reminders
            // with the line, and the line is sent again like a new one (`putBackLine`, To buy's own Undo).
            if id.table == .actions, current[id] == nil, var v = value, v.json[REMINDER_ID_KEY] != nil {
                v.json[REMINDER_ID_KEY] = nil
                value = v
            }
            next[id] = value
            if clash && !quiet.contains(id) {
                let name = undoNoun(value ?? current[id] ?? step.after[id] ?? step.before[id])
                if !kept.contains(name) { kept.append(name) }
            }
        }
        let out = Library(records: Array(next.values)).ordered(like: self)
        let inverse = UndoStep.make(id: inverseId, name: step.name, from: now, to: out.records(), in: out)
        return Reverted(library: inverse == nil ? self : out, inverse: inverse, kept: kept)
    }

    /// One record, three ways: `now` (here, now), `was` (as the step left it), `back` (as it was before
    /// the step). What to store, and whether something the step wrote had changed since.
    static func revert(_ now: StoredRecord?, was: StoredRecord?, back: StoredRecord?) -> (StoredRecord?, Bool) {
        switch (now, was, back) {
        case (nil, nil, _): return (back, false)                  // still deleted, as the step left it
        case let (n?, w?, _) where n.sameContent(as: w): return (back, false)
        case (nil, _?, nil): return (nil, false)                  // made by the step, gone since: done already
        case (nil, _?, _?): return (nil, true)                    // changed by the step, deleted since: stays gone
        case let (n?, nil, _): return (n, true)                   // deleted by the step, made again since
        case let (n?, _?, nil): return (n, true)                  // made by the step, changed since: kept
        case let (n?, w?, b?):
            var out = n
            var clash = false
            if let json = revertValue(n.json, was: w.json, back: b.json, stamps: undoStamps, clash: &clash) {
                out.json = json
            } else {
                out.json = .null
            }
            if w.parent != b.parent {
                if n.parent == w.parent { out.parent = b.parent } else if n.parent != b.parent { clash = true }
            }
            if w.blob != b.blob {
                if n.blob == w.blob { out.blob = b.blob } else if n.blob != b.blob { clash = true }
            }
            return (out, clash)
        }
    }

    /// One value, three ways (nil: no such key). A value the step did not change stays; one still as the
    /// step wrote it goes back; one already back is no clash; an object goes key by key, a list by the
    /// list rule; anything else changed since is kept, and `clash` is set — unless it is a stamp.
    static func revertValue(_ now: JSONValue?, was: JSONValue?, back: JSONValue?, stamps: Set<String> = [],
                            clash: inout Bool) -> JSONValue? {
        if was == back || now == back { return now }
        if now == was { return back }
        if case .object(var o)? = now, case .object(let a)? = was, case .object(let b)? = back {
            for key in Set(a.keys).union(b.keys) where a[key] != b[key] {
                if stamps.contains(key) {
                    if o[key] == a[key] { o[key] = b[key] }        // a stamp: back with the step, or left
                    continue
                }
                var deeper = false
                o[key] = revertValue(o[key], was: a[key], back: b[key], clash: &deeper)
                if deeper { clash = true }
            }
            return .object(o)
        }
        func isList(_ v: JSONValue?) -> Bool { v == nil || v == .null || v?.arrayValue != nil }
        if isList(now), isList(was), isList(back), now?.arrayValue != nil || was?.arrayValue != nil || back?.arrayValue != nil {
            return Library.mergeList(now, was: was, now: back)
        }
        clash = true
        return now
    }

    /// The library in `reference`'s order: what both hold in the order it is there, what is new last (the
    /// store's order). A library read from records is in key order; the screens' lists were in the order
    /// things were made, and an undo should not shuffle what it did not touch. The "When" steps keep the
    /// order their own `order` gives them (as every read of the store does).
    func ordered(like reference: Library) -> Library {
        func sort<T>(_ list: [T], _ ref: [T], _ id: (T) -> String) -> [T] {
            var at: [String: Int] = [:]
            for (n, x) in ref.enumerated() where at[id(x)] == nil { at[id(x)] = n }
            return list.enumerated().sorted { l, r in
                switch (at[id(l.element)], at[id(r.element)]) {
                case let (a?, b?): return a < b
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return l.offset < r.offset
                }
            }.map(\.element)
        }
        var out = self
        out.items = sort(items, reference.items, \.id)
        out.memberships = sort(memberships, reference.memberships, \.id)
        out.templates = sort(templates, reference.templates, \.id)
        out.trips = sort(trips, reference.trips, \.id)
        out.actions = sort(actions, reference.actions, \.id)
        out.kits = sort(kits, reference.kits, \.id)
        out.shared = sort(shared, reference.shared, \.id)
        out.photos = sort(photos, reference.photos, \.id)
        return out
    }
}

// MARK: - Naming a step

extension Library {
    /// What a record is called in a step's name and in the note: a thing's, a line's, a trip's or a
    /// template's name, a to-do's words; a row by its thing.
    func undoNoun(_ r: StoredRecord?) -> String {
        guard let r else { return "Something" }
        if r.table == .memberships, let thing = r.json["itemId"]?.stringValue,
           let name = items.first(where: { $0.id == thing })?.name, !jsTrim(name).isEmpty { return jsTrim(name) }
        for key in ["name", "text"] {
            if let s = r.json[key]?.stringValue, !jsTrim(s).isEmpty { return jsTrim(s) }
        }
        switch r.table {
        case .photos: return "Photo"
        case .shared, .phases: return "Your choices"
        default: return "Something"
        }
    }

    /// The step's name when the screen gave none, read from what it did — deletes first (what goes is
    /// what is looked for), then what it made, then what it changed: "Delete Weekend in the hills",
    /// "Add Passport", "Tick Passport", "Untick 3 Things", "Set Aside Map", "Edit Hiking".
    public func undoName(_ step: UndoStep) -> String {
        var gone: [Table: [StoredRecord]] = [:], made: [Table: [StoredRecord]] = [:]
        var changed: [Table: [(b: StoredRecord, a: StoredRecord)]] = [:]
        for id in step.touched {
            switch (step.before[id], step.after[id]) {
            case let (b?, nil): gone[id.table, default: []].append(b)
            case let (nil, a?): made[id.table, default: []].append(a)
            case let (b?, a?): changed[id.table, default: []].append((b, a))
            default: break
            }
        }
        func say(_ verb: String, _ list: [StoredRecord], _ plural: String) -> String {
            list.count == 1 ? "\(verb) \(undoNoun(list[0]))" : "\(verb) \(list.count) \(plural)"
        }
        let order: [(Table, String)] = [(.trips, "Trips"), (.templates, "Templates"), (.kits, "Kits"), (.items, "Things"),
                                        (.actions, "Lines"), (.memberships, "Things"), (.entries, "Things"), (.photos, "Photos")]
        for (table, plural) in order {
            if let list = gone[table], !list.isEmpty {
                return say(table == .memberships || table == .entries || table == .actions ? "Remove" : "Delete", list, plural)
            }
        }
        for (table, plural) in order {
            if let list = made[table], !list.isEmpty { return say("Add", list, plural) }
        }
        if let list = changed[.templates], !list.isEmpty { return say("Edit", list.map(\.a), "Templates") }
        if let list = changed[.items], !list.isEmpty {
            return list.count == 1 ? "Edit \(undoNoun(list[0].a))" : "Change \(list.count) Things"
        }
        if let rows = changed[.memberships], !rows.isEmpty {
            let lists = Set(rows.map(\.a.parent))
            if lists.count == 1, let t = templates.first(where: { $0.id == rows[0].a.parent }), !jsTrim(t.name).isEmpty {
                return "Edit \(jsTrim(t.name))"
            }
            return say("Edit", rows.map(\.a), "Things")
        }
        if let list = changed[.kits], !list.isEmpty { return say("Edit", list.map(\.a), "Kits") }
        func flips(_ list: [(b: StoredRecord, a: StoredRecord)], _ key: String) -> Bool? {
            let all = list.map { ($0.b.json[key]?.truthy ?? false, $0.a.json[key]?.truthy ?? false) }
            guard all.allSatisfy({ $0.0 != $0.1 }), let first = all.first, all.allSatisfy({ $0.1 == first.1 }) else { return nil }
            return first.1
        }
        if let list = changed[.actions], !list.isEmpty {
            if let done = flips(list, "done") { return say(done ? "Tick" : "Untick", list.map(\.a), "Lines") }
            return say("Change", list.map(\.a), "Lines")
        }
        if let lines = changed[.entries], !lines.isEmpty {
            // Set aside takes the tick away too: the aside decides the name.
            if let aside = flips(lines, "skipped") { return say(aside ? "Set Aside" : "Bring Back", lines.map(\.a), "Things") }
            if let ticked = flips(lines, "checked") { return say(ticked ? "Tick" : "Untick", lines.map(\.a), "Things") }
            return say("Change", lines.map(\.a), "Things")
        }
        if let list = changed[.trips], !list.isEmpty { return say("Change", list.map(\.a), "Trips") }
        if changed[.shared] != nil || changed[.phases] != nil || made[.shared] != nil || gone[.shared] != nil {
            return "Change Your Choices"
        }
        return "Change"
    }
}

// MARK: - The history

/// This device's steps, newest last — in memory only (gone when the app quits), at most `depth`.
public struct UndoBook: Equatable, Sendable {
    /// How many steps back: 50.
    public static let depth = 50
    public private(set) var undos: [UndoStep] = []
    public private(set) var redos: [UndoStep] = []
    private var lastId = 0

    public init() {}

    public var canUndo: Bool { !undos.isEmpty }
    public var canRedo: Bool { !redos.isEmpty }
    /// "Tick Passport" — the menu adds "Undo" or "Redo".
    public var undoName: String? { undos.last?.name }
    public var redoName: String? { redos.last?.name }
    public func holds(_ id: UndoStep.ID) -> Bool { undos.contains { $0.id == id } }

    public mutating func newId() -> Int { lastId += 1; return lastId }

    /// A change kept: `old` → `new`. `joining`: the same press as the last step (one tap, one Done) — one
    /// step. A new step forgets what could be redone, as everywhere on the Mac. Returns the step on top
    /// now and whether the oldest fell off the end; nil when nothing changed.
    @discardableResult
    public mutating func record(name: String?, old: [StoredRecord], changes: RecordChanges, library: Library,
                                joining: Bool = false) -> (step: UndoStep, trimmed: Bool)? {
        guard let step = UndoStep.make(id: joining && !undos.isEmpty ? undos[undos.count - 1].id : newId(),
                                       name: name, old: old, changes: changes, in: library) else { return nil }
        redos = []
        if joining, let top = undos.last {
            undos.removeLast()
            guard let both = top.joined(with: step, in: library) else { return nil }
            undos.append(both)
            return (both, false)
        }
        undos.append(step)
        let trimmed = undos.count > UndoBook.depth
        if trimmed { undos.removeFirst(undos.count - UndoBook.depth) }
        return (step, trimmed)
    }

    /// The same from two sets of records (the model tests).
    @discardableResult
    public mutating func record(name: String? = nil, from old: [StoredRecord], to new: [StoredRecord], library: Library,
                                joining: Bool = false) -> UndoStep? {
        record(name: name, old: old, changes: recordChanges(from: old, to: new), library: library, joining: joining)?.step
    }

    /// Undo, worked out: the library with the last step taken back. Changes nothing here — `undone` once
    /// the library is kept (a store that refuses leaves the step where it is).
    public mutating func undoing(_ library: Library) -> Reverted? {
        guard let step = undos.last else { return nil }
        return library.reverting(step, inverseId: newId())
    }

    public mutating func undone(_ r: Reverted) {
        guard !undos.isEmpty else { return }
        undos.removeLast()
        if let back = r.inverse { redos.append(back) }
    }

    /// Redo, worked out: the last undo put back, by the same rule.
    public mutating func redoing(_ library: Library) -> Reverted? {
        guard let step = redos.last else { return nil }
        return library.reverting(step, inverseId: newId())
    }

    public mutating func redone(_ r: Reverted) {
        guard !redos.isEmpty else { return }
        redos.removeLast()
        if let again = r.inverse {
            undos.append(again)
            if undos.count > UndoBook.depth { undos.removeFirst(undos.count - UndoBook.depth) }
        }
    }

    /// A banner's Undo (the trip's 6-second Undo, To do's and To buy's, the table's Change all) for a step
    /// that is not the last one: taken back on its own, by the same rule. What a later step of this device
    /// changed since is its own and is kept without a word.
    public mutating func undoingOne(_ id: UndoStep.ID, in library: Library) -> Reverted? {
        guard let n = undos.firstIndex(where: { $0.id == id }) else { return nil }
        let later = Set(undos[(n + 1)...].flatMap(\.touched))
        return library.reverting(undos[n], inverseId: newId(), quiet: later)
    }

    /// … and once kept: gone from the history. Not offered as a Redo — it was not the last step.
    public mutating func undoneOne(_ id: UndoStep.ID) {
        undos.removeAll { $0.id == id }
    }

    /// The app's own bookkeeping, written by this device and no step of his — a forecast kept on a trip,
    /// a line marked as sent to Reminders, a repair: carried into the newest step that touched the same
    /// record, as if that step had written it. Without it an undo would find the record changed since and
    /// take it for the other device's (the trip just made, its forecast arrived: "Partly undone — …").
    public mutating func carry(old: [StoredRecord], changes: RecordChanges) {
        guard !(undos.isEmpty && redos.isEmpty), !changes.isEmpty else { return }
        var now: [RecordID: StoredRecord?] = [:]
        for r in changes.puts { now[r.id] = .some(r) }
        for id in changes.deletes { now[id] = .some(nil) }
        var was: [RecordID: StoredRecord] = [:]
        for r in old where now[r.id] != nil { was[r.id] = r }
        func carry(_ steps: inout [UndoStep]) {
            for (id, new) in now {
                guard let n = steps.lastIndex(where: { $0.after[id] != nil || $0.before[id] != nil }) else { continue }
                let left = steps[n].after[id]
                let same = left.map { a in was[id].map { a.sameContent(as: $0) } ?? false } ?? (was[id] == nil)
                guard same, steps[n].touched.contains(id) else { continue }
                steps[n].after[id] = new
            }
        }
        carry(&undos)
        carry(&redos)
    }

    /// The library was replaced or its store reopened (a restore, the first import, a restart of the
    /// sync): nothing of before can be undone or redone.
    public mutating func forget() {
        undos = []
        redos = []
    }

    /// The note when something was kept: "Partly undone — Passport was changed on your iPhone", or, when
    /// nothing at all could be taken back, "Not undone — …". nil when all of it went back.
    public static func note(_ r: Reverted, redo: Bool = false, otherDevice: String) -> String? {
        guard !r.kept.isEmpty else { return nil }
        let names = r.kept.count <= 2 ? r.kept.joined(separator: " and ") : "\(r.kept[0]) and \(r.kept.count - 1) more"
        let verb = r.kept.count == 1 ? "was" : "were"
        let what = r.nothing ? (redo ? "Not redone" : "Not undone") : (redo ? "Partly redone" : "Partly undone")
        return "\(what) \u{2014} \(names) \(verb) changed on \(otherDevice)"
    }
}
