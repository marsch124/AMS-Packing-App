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
// it, named "<name> 2" (the next free number), with everything that describes the bag — max kg,
// litres, empty weight, its details, pockets, Goes in the cabin, Has an AirTag, Notes, its row on Your
// bags (heading, answers) and all a thing's copy takes. Since 0.92 it is the copy of ANY thing
// (ThingDuplicate.swift: `copyRecord`, `copyRow`, what is and is not copied) — a bag's own place is
// Your bags: NOT the templates it is ALSO packed on as a thing (a copy never joins a trip by itself),
// and the things whose "Usually packed in" is the original stay there.

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

    /// Duplicate one of his bags (see the top of this file for what the copy takes). The copy is a
    /// new thing on Your bags, right after the original in his own order. nil for anything that is
    /// not one of his bags.
    @discardableResult
    public mutating func duplicateBag(id: String) -> Item? {
        guard let row = bags().first(where: { $0.id == id }), let mem = row.memId,
              let original = items.first(where: { $0.id == id }),
              let originalRow = memberships.first(where: { $0.id == mem }) else { return nil }
        let copy = copyRecord(of: original)
        items.append(copy)
        // Its row on Your bags: the original's, with an id (and so a moment) of its own, right after
        // it under the same heading of Your bags.
        copyRow(originalRow, to: copy.id)
        return items.first { $0.id == copy.id }
    }
}
