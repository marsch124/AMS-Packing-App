import Foundation
import PackingCore

// Refine — the web app's screen for trimming lists, from what his trip reviews
// taught (roadmap stop E). A thing he keeps packing and never uses, or keeps
// listing and never packs, over at least TWO trips (one quiet trip is not
// evidence — the web app's v162 lesson), is offered: Keep (settled for good) or
// Drop from that one list (it stays his thing, and on his other lists).

extension Library {
    /// What Refine offers, most-trips first; one line per thing per list (a thing
    /// on a list twice is one thing with one history — the web app's v189). His bag
    /// list is not offered: bags are not packed "for nothing".
    public func refineSuggestions() -> [PruneSuggestion] {
        let lists = resolvedTemplates().filter { $0.role != CONTAINER_ROLE }
        var seen = Set<String>()
        return pruneSuggestions(lists).filter { s in
            seen.insert("\(s.listId)|\(s.item.itemId ?? s.item.id)").inserted
        }
    }

    /// Keep: the thing earned its place — never offered again.
    @discardableResult
    public mutating func keepThing(id: String) -> Bool {
        updateThing(id: id) { $0.keep = true }
    }

    /// Drop it from ONE list. The thing stays, and on every other list it is on.
    @discardableResult
    public mutating func dropFromList(itemId: String, listId: String) -> Bool {
        guard memberships.contains(where: { $0.itemId == itemId && $0.templateId == listId }) else { return false }
        return setOnTemplate(itemId: itemId, templateId: listId, on: false)
    }
}
