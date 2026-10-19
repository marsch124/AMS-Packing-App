import Foundation
import PackingCore

// Cancel everywhere (0.92). His words, 19 Oct 2026: "I open an item and change some property. How
// do I cancel that? There is only a Done button, right?" — and "the cancel function should be
// existing throughout the whole app right?"
//
// A page whose controls change the library at once (a template's page, Your choices) works on a
// COPY of the library while it is open (`PageDraft` in the app). Cancel throws the copy away. Save
// hands over what the page changed — only that: every record the page did not touch keeps what the
// real library holds now, so a change from the other device while the page was open is not undone.

extension Library {
    /// This library with what a page changed on its copy — the copy as it opened (`from`) and as
    /// it is now (`to`) — put in. Per record, by id: one the page added or changed is the page's,
    /// one it deleted goes, every other one stays as it is here. Nothing changed = this library.
    public func applyingPage(from: Library, to: Library) -> Library {
        guard from != to else { return self }
        var out = self
        out.items = Library.merge(items, from: from.items, to: to.items, id: \.id)
        out.memberships = Library.merge(memberships, from: from.memberships, to: to.memberships, id: \.id)
        out.templates = Library.merge(templates, from: from.templates, to: to.templates, id: \.id)
        out.trips = Library.merge(trips, from: from.trips, to: to.trips, id: \.id)
        out.actions = Library.merge(actions, from: from.actions, to: to.actions, id: \.id)
        out.kits = Library.merge(kits, from: from.kits, to: to.kits, id: \.id)
        out.phases = Library.merge(phases, from: from.phases, to: to.phases, id: \.id)
        out.shared = Library.merge(shared, from: from.shared, to: to.shared, id: \.id)
        out.photos = Library.merge(photos, from: from.photos, to: to.photos, id: \.id)
        for (key, value) in to.meta where from.meta[key] != value { out.meta[key] = value }
        for key in from.meta.keys where to.meta[key] == nil { out.meta[key] = nil }
        return out
    }

    /// One table: `live` with the page's changes (`from` → `to`) put in, in `live`'s order; what
    /// the page added comes last, in the page's order.
    static func merge<T: Equatable>(_ live: [T], from: [T], to: [T], id: (T) -> String) -> [T] {
        guard from != to else { return live }
        var before: [String: T] = [:]
        for x in from { before[id(x)] = x }
        var after: [String: T] = [:]
        for x in to { after[id(x)] = x }
        // What the page changed or added, and what it deleted.
        var changed: [String: T] = [:]
        for x in to where before[id(x)] != x { changed[id(x)] = x }
        let deleted = Set(before.keys.filter { after[$0] == nil })
        guard !changed.isEmpty || !deleted.isEmpty else { return live }
        var out: [T] = []
        var placed = Set<String>()
        for x in live {
            let key = id(x)
            if deleted.contains(key) { continue }
            out.append(changed[key] ?? x)
            placed.insert(key)
        }
        for x in to where changed[id(x)] != nil && !placed.contains(id(x)) {
            out.append(x)
            placed.insert(id(x))
        }
        return out
    }
}
