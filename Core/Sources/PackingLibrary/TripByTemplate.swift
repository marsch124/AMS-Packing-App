import Foundation
import PackingCore

// A trip sorted by Template (0.74, his ask of 12 Oct 2026: "pack focused on e.g. Bike,
// Run or Golf"): its lines under the templates they come from. Native only — the web
// app's `groupBy` knows no such sorting, and stays as the parity check holds it.
// Spec 03, "Sorting and grouping".

extension Library {
    /// The heading of the lines no template brings: typed on the trip, Bought on site,
    /// sent (a shared trip's lines carry no template), or from a template that is gone.
    public static let addedOnTheTrip = "Added on the trip"

    /// Each line of the trip (by its id) → the templates it comes from, in the trip's
    /// template order (`listsForEvent`: the base template, the transport's, the ticked
    /// ones), resolved — so a template's icon can be read from it (`Library.icon(of:)`):
    ///
    /// - the template the line was made from (`sourceListId`) AND every other trip template
    ///   that brings the SAME thing (`sourceItemId`) onto this trip;
    /// - a line whose own template is no longer on the trip but still exists: that template;
    /// - a line added on the trip (typed, Bought on site, sent), or whose template is gone:
    ///   no entry.
    ///
    /// ONE answer for "Sorted by Template" and for the template icons on each line (0.74).
    public func lineTemplates(tripId: String) -> [String: [PackList]] {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return [:] }
        let all = templatesForTrips()
        let onTrip = listsForEvent(trip, all)
        // What each of the trip's templates brings onto THIS trip: the things a rebuild
        // would take from it (buildTotalEntries' own rules, without the de-duplication).
        var brings: [String: Set<String>] = [:]
        for list in onTrip {
            var things = Set<String>()
            for row in list.items where Library.comesAlong(row, trip, list) {
                let id = row.itemId ?? row.id
                if !id.isEmpty { things.insert(id) }
            }
            brings[list.id] = things
        }
        var out: [String: [PackList]] = [:]
        for line in trip.entries where out[line.id] == nil {
            var here: [PackList] = []
            for list in onTrip {
                let own = line.sourceListId == list.id
                let same = !line.custom && (line.sourceItemId.map { brings[list.id]?.contains($0) ?? false } ?? false)
                if own || same { here.append(list) }
            }
            // Its own template, no longer on the trip but still there.
            if here.isEmpty, !line.custom, let own = line.sourceListId, !own.isEmpty,
               let list = all.first(where: { $0.id == own }) {
                here = [list]
            }
            if !here.isEmpty { out[line.id] = here }
        }
        return out
    }

    /// `lines` (the trip's, as the screen shows them — the place filter and "only what is
    /// still unticked" already applied) under the templates they come from
    /// (`lineTemplates`): the trip's templates in its order, then templates no longer on
    /// the trip, then "Added on the trip". A line can stand under several headings — it is
    /// the same line, one tick. Within a heading the lines keep the order they are given
    /// in; empty headings are left out.
    public func linesByTemplate(tripId: String, lines: [Item]) -> [EntryGroup] {
        let from = lineTemplates(tripId: tripId)
        var order: [String] = []                                  // template ids, headings in this order
        var names: [String: String] = [:]
        if let trip = trips.first(where: { $0.id == tripId }) {
            for list in listsForEvent(trip, templates) { order.append(list.id); names[list.id] = list.name }
        }
        var under: [String: [Item]] = [:]
        var added: [Item] = []
        for line in lines {
            guard let lists = from[line.id], !lists.isEmpty else { added.append(line); continue }
            for list in lists {
                if !order.contains(list.id) { order.append(list.id) }
                names[list.id] = list.name
                under[list.id, default: []].append(line)
            }
        }
        var out: [EntryGroup] = []
        for id in order {
            guard let entries = under[id], !entries.isEmpty else { continue }
            let name = names[id] ?? ""
            out.append(EntryGroup(label: jsTrim(name).isEmpty ? "Untitled template" : name, entries: entries))
        }
        if !added.isEmpty { out.append(EntryGroup(label: Library.addedOnTheTrip, entries: added)) }
        return out
    }

    /// Would this row of `list` come onto `trip` when it is built? A name, not retired
    /// ("Not in use"), the trip's season, transport, catering and Context, and — for
    /// weather gear — a condition the trip forces on (`buildTotalEntries`).
    static func comesAlong(_ row: Item, _ trip: TripEvent, _ list: PackList) -> Bool {
        if jsTrim(row.name).isEmpty || row.retired { return false }
        if !itemMatchesEvent(row, trip, list) { return false }
        let tags = row.weather
        return tags.isEmpty || tags.contains(where: { trip.weatherOn.contains($0) })
    }
}
