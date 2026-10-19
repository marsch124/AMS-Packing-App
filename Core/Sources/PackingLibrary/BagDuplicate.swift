import Foundation
import PackingCore

// A bag's Notes and Duplicate (0.90) — two of his four bag asks of 19 Oct 2026 (spec 05, a bag's
// page; spec 07 §11).
//
// NOTES — "Add Notes under Bag Name": a bag is a thing, so its Notes ARE the thing's own `note` —
// the field a thing's page has under its name. One value: the bag's page and Its details show the
// same words, Search finds the bag by them, and they travel with the thing's record (sync, backups).
//
// DUPLICATE — "Add possibility to duplicate a bag/container (use case: if I buy four of the same and
// just want to change colour and name...)". A copy of the bag's own thing, on Your bags right after
// it, named "<name> 2" (the next free number), with everything that describes the bag:
//   copied   max kg, litres, empty weight, brand, colour, its size's note, type, size class,
//            distinctive marks, pockets, Goes in the cabin, Has an AirTag, Has a battery, Notes, kind of
//            thing, whose it is, kept at home, the bag it usually goes in (and pocket), condition,
//            bought (when, price, link), warranty, care (what to do and how often), its row on Your
//            bags (heading, answers) — and any key a later version adds, unless listed below;
//   NOT      its photos (`photos`, `thumb`) — a picture of THAT bag; its trips — they are kept on the
//            trips under the bag's name, which the copy does not have; what is inside it — the things
//            whose "Usually packed in" is the original stay there, and a kit's contents
//            (`KIT_CONTENTS_KEY`, `KIT_OUT_KEY`, `KIT_CHECK_KEY`) are the original's; its review counts
//            (`stats`) and Refine's Keep it; its serial number; the care log (when it was last done);
//            retired; the templates it is ALSO packed on as a thing (a copy never joins a trip by
//            itself); the kit it is part of; the edit stamp (`BAG_EDITED_KEY`: a copy counts as edited
//            when it was added).

/// Extra keys a bag's copy does not take: what is inside the original (a kit's contents), and when
/// the original was last edited.
public let BAG_COPY_LEAVES = [KIT_CONTENTS_KEY, KIT_OUT_KEY, KIT_CHECK_KEY, BAG_EDITED_KEY]

extension Library {
    /// The id of his bag with this name (as `normName` sees it), nil for a name that is no bag of his
    /// — "Other", a built-in name on the lines, "".
    public func bagId(named name: String) -> String? {
        let key = normName(name)
        guard !key.isEmpty else { return nil }
        return bags().first { normName($0.name) == key }?.id
    }

    /// A thing's own Notes, trimmed — the bag's page writes its Notes here. False for no such thing.
    @discardableResult
    public mutating func setThingNote(id: String, _ note: String) -> Bool {
        guard let it = items.first(where: { $0.id == id }) else { return false }
        let want = jsTrim(note)
        guard it.note != want else { return true }
        return updateThing(id: id) { $0.note = want }
    }

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

    /// Duplicate one of his bags (see the top of this file for what the copy takes). The copy is a
    /// new thing on Your bags, right after the original in his own order. nil for anything that is
    /// not one of his bags.
    @discardableResult
    public mutating func duplicateBag(id: String) -> Item? {
        guard let list = bagList, let row = bags().first(where: { $0.id == id }), let mem = row.memId,
              let original = items.first(where: { $0.id == id }),
              let originalRow = memberships.first(where: { $0.id == mem }) else { return nil }
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
        for key in BAG_COPY_LEAVES { copy.extra[key] = nil }
        items.append(coerceItem(copy))
        // Its row on Your bags: the original's, with an id (and so a moment) of its own.
        var copyRow = originalRow
        copyRow.id = PackingEnv.makeId()
        copyRow.itemId = copy.id
        copyRow.order = (memberships.filter { $0.templateId == list.id }.map(\.order).max() ?? -1) + 1
        memberships.append(copyRow)
        // Right after the original, under the same heading of Your bags.
        if let head = arrangedRows(templateId: list.id).first(where: { $0.rows.contains(mem) }),
           let at = head.rows.firstIndex(of: mem) {
            let next = head.rows.indices.contains(at + 1) ? head.rows[at + 1] : nil
            moveRow(templateId: list.id, memId: copyRow.id, section: head.sectionId, before: next == copyRow.id ? nil : next)
        }
        return items.first { $0.id == copy.id }
    }
}
