import Foundation
import PackingCore

// Duplicate a thing (0.92 — his yes of 19 Oct 2026 to "Duplicate a thing: the same as Duplicate bag, for
// any thing — handy for near-copies like a second charger or a spare cable"). Spec 05, a thing's page 18b;
// spec 07 §11.
//
// ONE copy for things and bags (Duplicate this bag, 0.90, BagDuplicate.swift, is the same copy with its
// own place). The copy is a NEW thing, named "<name> 2" (`duplicateName`), with everything that
// describes the original:
//   copied   kind of thing, whose it is, kept at home, the bag it usually goes in and its pocket, When,
//            its own Only on some trips, weight, brand, colour, condition, its care (what to do and how
//            often), On a plane (liquid, not allowed in the cabin), Has a battery, Valid until, Notes, how
//            many, when bought, price, link, warranty — a bag's sizes, details and pockets too — and any
//            key a later version adds, unless listed next;
//   NOT      its photos (`photos`, `thumb`) — a picture of THAT one; its trips — a trip's lines carry
//            the original's name, and a trip already made is never joined by the copy (`followThing`
//            only rebuilds lines a thing already has); its review counts (`stats`) and Refine's Keep it
//            — the copy has not been on a trip; its serial number; the care log (when it was last done,
//            the log); retired; the kit it is in (a thing is in one kit at most — the copy is in none)
//            and, for a kit, what is inside it (`COPY_LEAVES`); a bag's edit stamp.
// Where it goes:
//   a thing  on EVERY template the original is on (decided by the build: a second charger is packed
//            where the first is), each row copied with its own answers — its section, its bag, When and
//            how many there, its note, its conditions and its own Only on some trips — right after the
//            original's row, under the same heading. On a template twice, both rows are copied.
//   a bag    on Your bags only, right after it (`duplicateBag`): a bag's templates as a thing are NOT
//            copied — four of the same bag are not all packed on every trip.

/// Extra keys a copy does not take: what is inside the original (a kit's contents, what is out, the
/// check before a trip), and when a bag was last edited (a copy counts as edited when it was added).
public let COPY_LEAVES = [KIT_CONTENTS_KEY, KIT_OUT_KEY, KIT_CHECK_KEY, BAG_EDITED_KEY]

extension Library {
    /// "<name> 2", or the next number free among ALL his things (a bag is a thing, and two things
    /// never share a name). A copy of a copy counts on from the original: "Duffel 2" → "Duffel 3" —
    /// when "Duffel" is one of his things; "Size 40" alone stays a name and becomes "Size 40 2".
    public func duplicateName(of name: String) -> String {
        let clean = jsTrim(name)
        var base = clean
        if let r = clean.range(of: #" [0-9]{1,3}$"#, options: .regularExpression) {
            let stem = jsTrim(String(clean[..<r.lowerBound]))
            if !stem.isEmpty, items.contains(where: { normName($0.name) == normName(stem) }) { base = stem }
        }
        var n = 2
        while items.contains(where: { normName($0.name) == normName("\(base) \(n)") }) { n += 1 }
        return "\(base) \(n)"
    }

    /// Duplicate one of his things (see the top of this file): a new thing on every template the
    /// original is on, each row right after the original's. A bag goes the bag's way (`duplicateBag`).
    /// nil for an id that is no thing.
    @discardableResult
    public mutating func duplicateThing(id: String) -> Item? {
        guard let original = items.first(where: { $0.id == id }) else { return nil }
        if bags().contains(where: { $0.id == id }) { return duplicateBag(id: id) }
        let copy = copyRecord(of: original)
        items.append(copy)
        // Its rows: on every template it is on, in the order they are stored — the bag list never
        // (a thing that is no bag has no row there).
        let lists = Set(templatesForThings().map(\.id))
        for row in memberships where row.itemId == id && lists.contains(row.templateId) {
            copyRow(row, to: copy.id)
        }
        return items.first { $0.id == copy.id }
    }

    /// The copy's own record: a fresh id, the next free name, and nothing that belongs to the
    /// original alone (the top of this file). Not yet in the library.
    func copyRecord(of original: Item) -> Item {
        var copy = original
        copy.id = PackingEnv.makeId()
        copy.name = duplicateName(of: original.name)
        copy.photos = []
        copy.thumb = ""
        copy.stats = ItemStats()
        copy.keep = false
        copy.serial = ""
        copy.retired = false
        copy.retiredReason = ""
        copy.kit = ""
        if var care = copy.maintenance {
            care.lastDone = ""
            care.log = []
            copy.maintenance = care
        }
        for key in COPY_LEAVES { copy.extra[key] = nil }
        return coerceItem(copy)
    }

    /// One row of the original, copied for the copy: the same answers, with an id (and so a moment)
    /// of its own and in no kit — right after the original's row, under the same heading.
    mutating func copyRow(_ original: Membership, to copyId: String) {
        let list = original.templateId
        var row = original
        row.id = PackingEnv.makeId()
        row.itemId = copyId
        row.kit = ""
        row.order = (memberships.filter { $0.templateId == list }.map(\.order).max() ?? -1) + 1
        memberships.append(row)
        if let head = arrangedRows(templateId: list).first(where: { $0.rows.contains(original.id) }),
           let at = head.rows.firstIndex(of: original.id) {
            let next = head.rows.indices.contains(at + 1) ? head.rows[at + 1] : nil
            moveRow(templateId: list, memId: row.id, section: head.sectionId, before: next == row.id ? nil : next)
        }
    }
}
