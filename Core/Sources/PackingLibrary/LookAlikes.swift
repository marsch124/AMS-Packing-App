import Foundation
import PackingCore

// Look-alikes (0.125 — his pick "10" of 12 Nov 2026: "Duplicate finder: spots two entries that are
// probably the same thing and offers to merge them").
//
// FINDING. Two of his things look alike when their names give the same `dupeKey` (spaces,
// punctuation, capitals and a plural -s ignored: "Sunglasses" / "Sun glasses" / "sunglass") or
// they carry the same serial number (`cleanSerial`, at least 4 characters). Offered: his own
// things (`ownThings` — no reminders), never a bag, never a thing marked gone, never a pair he
// answered "Not the same" (kept on BOTH things in `extra["notSame"]` = [other ids], so it syncs
// and survives a backup). Nothing is ever merged on its own: the app only asks.
//
// MERGING (`mergeThing(keep:from:)`). The kept thing keeps its name and everything it already has;
// what it lacks comes from the other (details, notes, photos up to two, papers up to twelve, its
// extra marks — lent, parts, label code…). Then every reference to the other thing anywhere in the
// library — templates (memberships), kits, a kit's contents, trip lines past and ahead, to-dos,
// shared rows, other things' "Goes with" — points to the kept one. That is done on the stored
// JSON of each record that mentions the other id (ids are random, so an exact match is that
// thing), and only those records are rebuilt. Doubles left behind are settled: one membership per
// template, one id per kit, one line per trip (ticked / used if either was). The other thing goes.

public let NOT_SAME_KEY = "notSame"

/// Two of his things that look like the same thing, and why.
public struct LookAlikePair: Equatable, Sendable {
    public var a: Item
    public var b: Item
    /// "Same serial number" or "Same name".
    public var why: String
}

extension Library {
    /// The ids he said are NOT the same thing as this one.
    public static func notSame(_ it: Item) -> Set<String> {
        guard case .array(let rows)? = it.extra[NOT_SAME_KEY] else { return [] }
        return Set(rows.compactMap(\.stringValue).filter { !$0.isEmpty })
    }

    /// The things the finder looks at: his own, no bag, nothing gone.
    func lookAlikeCandidates() -> [Item] {
        let bagIds = Set(bags().map(\.id))
        return ownThings().filter { !bagIds.contains($0.id) && !Library.isGone($0) && !jsTrim($0.name).isEmpty }
    }

    /// Every pair of look-alikes, by name order of the first; a pair he answered "Not the same"
    /// never comes back.
    public func lookAlikePairs() -> [LookAlikePair] {
        let things = lookAlikeCandidates()
        var out: [LookAlikePair] = []
        for i in things.indices {
            for j in things.indices where j > i {
                let a = things[i], b = things[j]
                if Library.notSame(a).contains(b.id) || Library.notSame(b).contains(a.id) { continue }
                let sa = Library.cleanSerial(a.serial), sb = Library.cleanSerial(b.serial)
                if sa.count >= 4 && sa == sb {
                    out.append(LookAlikePair(a: a, b: b, why: "Same serial number"))
                } else {
                    let ka = dupeKey(a.name), kb = dupeKey(b.name)
                    if !ka.isEmpty && ka == kb { out.append(LookAlikePair(a: a, b: b, why: "Same name")) }
                }
            }
        }
        return out.stableSorted(compare: { x, y in
            jsLocaleCompare(x.a.name, y.a.name, sensitivity: .base)
        })
    }

    /// "Not the same": the pair is never offered again (kept on both things).
    @discardableResult
    public mutating func markNotSame(_ a: String, _ b: String) -> Bool {
        guard a != b, items.contains(where: { $0.id == a }), items.contains(where: { $0.id == b }) else { return false }
        for (me, other) in [(a, b), (b, a)] {
            guard let n = items.firstIndex(where: { $0.id == me }) else { continue }
            var set = Library.notSame(items[n]); set.insert(other)
            items[n].extra[NOT_SAME_KEY] = .array(set.sorted().map { .string($0) })
        }
        return true
    }

    /// Merge `from` into `keep`: the kept thing takes what it lacks, everything that pointed to the
    /// other now points to it, and the other is gone. False (nothing changed) for a missing thing,
    /// the same id twice, or a bag.
    @discardableResult
    public mutating func mergeThing(keep: String, from: String) -> Bool {
        guard keep != from,
              let k = items.firstIndex(where: { $0.id == keep }),
              let old = items.first(where: { $0.id == from }) else { return false }
        let bagIds = Set(bags().map(\.id))
        guard !bagIds.contains(keep), !bagIds.contains(from) else { return false }

        // 1. The kept thing takes what it lacks.
        var kept = items[k]
        Library.fillGaps(&kept, from: old)
        // Photos: its own first, then the other's, up to two; the rest are let go below.
        let ownPhotos = photoRefs(kept)
        let theirs = photoRefs(old).filter { !ownPhotos.contains($0) }
        let room = max(0, THING_PHOTOS_MAX - ownPhotos.count)
        let taken = Array(theirs.prefix(room))
        if !taken.isEmpty {
            kept.photos = kept.photos + taken.filter { !kept.photos.contains($0) }
            if kept.thumb.isEmpty { kept.thumb = taken[0] }
        }
        // Papers: both lists, each picture once, up to twelve.
        var papers = Library.papers(kept)
        for p in Library.papers(old) where !papers.contains(where: { $0.id == p.id }) && papers.count < THING_PAPERS_MAX {
            papers.append(p)
        }
        Library.setPapers(&kept, papers)
        // "Not the same" answers of both, never about each other.
        let notSame = Library.notSame(kept).union(Library.notSame(old)).subtracting([keep, from])
        kept.extra[NOT_SAME_KEY] = notSame.isEmpty ? nil : .array(notSame.sorted().map { .string($0) })
        items[k] = coerceItem(kept)

        // 2. Doubles that pointing to the kept thing would make: settle them first.
        let keptOn = Set(memberships.filter { $0.itemId == keep }.map(\.templateId))
        memberships.removeAll { $0.itemId == from && keptOn.contains($0.templateId) }
        for t in trips.indices {
            let theirs = trips[t].entries.indices.filter { trips[t].entries[$0].sourceItemId == from }
            guard !theirs.isEmpty,
                  let mine = trips[t].entries.firstIndex(where: { $0.sourceItemId == keep }) else { continue }
            for n in theirs {
                let line = trips[t].entries[n]
                if line.checked { trips[t].entries[mine].checked = true }
                if line.used == true { trips[t].entries[mine].used = true }
            }
            let drop = Set(theirs.map { trips[t].entries[$0].id })
            trips[t].entries.removeAll { drop.contains($0.id) }
            trips[t].updatedAt = nowISO()
        }

        // 3. The other thing goes; every mention of it now names the kept one.
        items.removeAll { $0.id == from }
        func swap<T: JSONModel>(_ list: inout [T]) {
            for n in list.indices {
                let j = list[n].json
                guard Library.mentions(j, from) else { continue }
                list[n] = T(json: Library.replacing(j, from, with: keep))
            }
        }
        swap(&memberships); swap(&templates); swap(&trips); swap(&actions); swap(&kits); swap(&shared); swap(&items)
        let metaJSON = JSONValue.object(meta)
        if Library.mentions(metaJSON, from) { meta = Library.replacing(metaJSON, from, with: keep).objectValue ?? meta }

        // 4. Doubles the swap made: one id per kit, one per kit's contents.
        for n in kits.indices { kits[n].itemIds = Library.unique(kits[n].itemIds) }
        for n in items.indices where !Library.listedContents(items[n]).isEmpty {
            let list = Library.listedContents(items[n])
            let once = Library.unique(list.filter { $0 != items[n].id })
            if once != list {
                let it = items[n]
                Library.writeKit(&items[n], contents: once, out: Set(Library.kitIds(it.extra[KIT_OUT_KEY])))
            }
        }

        // 5. Photos and papers of the other thing that nothing shows any more go.
        dropPhotos(of: photoRefs(old) + Library.paperIds(old))
        _ = followThing(id: keep)
        return true
    }

    /// Fill the kept thing's empty details from the other one. Never overwrites what it has.
    static func fillGaps(_ it: inout Item, from o: Item) {
        func text(_ kp: WritableKeyPath<Item, String>) {
            if jsTrim(it[keyPath: kp]).isEmpty && !jsTrim(o[keyPath: kp]).isEmpty { it[keyPath: kp] = o[keyPath: kp] }
        }
        for kp in [\Item.storage, \.color, \.size, \.manufacturer, \.model, \.ownedBy, \.acquired, \.currency,
                   \.purchaseLink, \.expiry, \.serial, \.warranty, \.condition, \.category, \.container] as [WritableKeyPath<Item, String>] {
            text(kp)
        }
        // Notes: both, when they differ.
        let a = jsTrim(it.note), b = jsTrim(o.note)
        if a.isEmpty { it.note = o.note } else if !b.isEmpty && a != b && !a.contains(b) { it.note = a + "\n" + b }
        if it.price == 0 && o.price > 0 { it.price = o.price }
        if it.weight == 0 && o.weight > 0 { it.weight = o.weight }
        if it.maintenance == nil { it.maintenance = o.maintenance }
        // What it has learnt from trips: both counted.
        it.stats.packed += o.stats.packed
        it.stats.used += o.stats.used
        it.stats.unused += o.stats.unused
        it.stats.skipped += o.stats.skipped
        if o.stats.lastReviewed > it.stats.lastReviewed { it.stats.lastReviewed = o.stats.lastReviewed }
        // Its marks (lent, parts, label code, shop, value today…): the kept thing's own win.
        for (key, value) in o.extra where it.extra[key] == nil && key != PAPERS_KEY && key != NOT_SAME_KEY {
            it.extra[key] = value
        }
    }

    // MARK: JSON helpers

    static func mentions(_ v: JSONValue, _ id: String) -> Bool {
        switch v {
        case .string(let s): return s == id
        case .array(let a): return a.contains { mentions($0, id) }
        case .object(let o): return o.keys.contains(id) || o.values.contains { mentions($0, id) }
        default: return false
        }
    }

    static func replacing(_ v: JSONValue, _ id: String, with new: String) -> JSONValue {
        switch v {
        case .string(let s): return s == id ? .string(new) : v
        case .array(let a): return .array(a.map { replacing($0, id, with: new) })
        case .object(let o):
            var out: [String: JSONValue] = [:]
            for (key, value) in o where key != id { out[key] = replacing(value, id, with: new) }
            if let value = o[id], out[new] == nil { out[new] = replacing(value, id, with: new) }
            return .object(out)
        default: return v
        }
    }

    static func unique(_ list: [String]) -> [String] {
        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted }
    }
}
