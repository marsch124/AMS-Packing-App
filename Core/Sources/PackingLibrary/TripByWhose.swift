import Foundation
import PackingCore

// A trip grouped by Whose it is (0.103, his idea of 27 Oct 2026: "When I am in packing mode, I
// sometimes want to pack on my own without my wife, even if she is going on the trip. I would
// like to pack everything that we share on my own, so that when she comes home, I have already
// packed a lot of things"). Native only, like Template: the web app's `groupBy` knows no such
// grouping and stays as the parity check holds it. Spec 03, "Sorting and grouping".

extension Library {
    /// `lines` (the trip's, as the screen shows them — the place filter and "only what is still
    /// unticked" already applied) under the owner of the THING behind each one.
    ///
    /// - **Whose a line is** is read from its thing as it is NOW (`thingNow`): a line carries no
    ///   owner of its own (`entryFromItem`), so a change on the thing reaches an open trip at once.
    ///   A line typed on the trip has no thing and so no owner.
    /// - **Headings:** the owners of Your choices in their order (A–Z), then every owner the lines
    ///   name that the list does not hold (a name removed from Your choices, or never on it), A–Z,
    ///   then "Both have one" (`OWNER_BOTH`) — the words the app already has for no owner — last.
    /// - Names are matched as everywhere (`normName`: case and spaces do not split a heading);
    ///   the heading is the list's spelling, else the first spelling met. An owner typed as the
    ///   words for no owner is no owner.
    /// - Within a heading the lines keep the order they are given in, as under every grouping;
    ///   empty headings are left out.
    public func linesByWhose(lines: [Item]) -> [EntryGroup] {
        let none = normName(OWNER_BOTH)
        var byId: [String: Item] = [:]
        for thing in items where byId[thing.id] == nil { byId[thing.id] = thing }
        var order: [String] = []                                   // normalised owners, headings in this order
        var names: [String: String] = [:]                          // normalised owner → the heading's words
        for name in owners() {
            let key = normName(name)
            if key.isEmpty || key == none || names[key] != nil { continue }
            order.append(key); names[key] = jsTrim(name)
        }
        var under: [String: [Item]] = [:]
        var strays: [String] = []
        for line in lines {
            let thing = line.sourceItemId.flatMap { byId[$0] } ?? line
            let who = jsTrim(thing.ownedBy)
            var key = normName(who)
            if key.isEmpty || key == none { key = "" }
            else if names[key] == nil { names[key] = who; strays.append(key) }
            under[key, default: []].append(line)
        }
        order += strays.stableSorted(compare: { a, b in jsLocaleCompare(names[a] ?? a, names[b] ?? b) })
        var out: [EntryGroup] = []
        for key in order {
            guard let entries = under[key], !entries.isEmpty else { continue }
            out.append(EntryGroup(label: names[key] ?? key, entries: entries))
        }
        if let entries = under[""], !entries.isEmpty { out.append(EntryGroup(label: OWNER_BOTH, entries: entries)) }
        return out
    }
}
