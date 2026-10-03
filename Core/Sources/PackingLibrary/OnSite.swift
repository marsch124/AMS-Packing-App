import Foundation
import PackingCore

// On site — a step of its own, right after Pack (their field test,
// 3 Oct 2026, mission 9.1): "During this phase, we could add stuff as: items bought
// there; items discarded there (not more needed); maintenance or other actions. I
// would also like to change the word 'there' to 'on site'." He then chose that it
// holds all four: Bought on site · Left on site · Maintenance notes · Pack to go home.
//
// Nothing new is stored on the trip: bought on site, used up / left and the line's
// note are the extra keys OnTheTrip.swift and WayHome.swift already keep. What is new
// is that a maintenance note ALSO lands on the thing behind the line, dated, so Care
// still has it once the trip is over and the trip is forgotten.

extension Library {
    /// Has the trip's On site begun? Once its first day has come — or as soon as
    /// something was bought on site, whatever the dates say.
    public func onSiteBegun(tripId: String, today: String) -> Bool {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return false }
        if isYMD(trip.startDate) && !jsStringLess(today, trip.startDate) { return true }
        return trip.entries.contains(where: Library.isBoughtOnSite)
    }

    /// What was used up or left on site, of what went — it does not come home.
    public func leftOnSite(tripId: String) -> [Item] {
        homeLines(tripId: tripId).filter(Library.isUsedUp)
    }

    /// Every line of the trip with a maintenance note, in the list's order.
    public func onSiteNotes(tripId: String) -> [Item] {
        trips.first { $0.id == tripId }?.entries.filter { !Library.homeNote($0).isEmpty } ?? []
    }

    /// The trip's On site door in one short line: "2 bought · 1 left · 3 notes · home 4/9".
    /// Only what there is, and the way home always — it is what is left to do.
    public func onSiteSummary(tripId: String) -> String {
        let bought = boughtOnSite(tripId: tripId).count
        let left = leftOnSite(tripId: tripId).count
        let notes = onSiteNotes(tripId: tripId).count
        let home = homeProgress(tripId: tripId)
        var parts: [String] = []
        if bought > 0 { parts.append("\(bought) bought") }
        if left > 0 { parts.append("\(left) left") }
        if notes > 0 { parts.append(notes == 1 ? "1 note" : "\(notes) notes") }
        parts.append("home \(home.done)/\(home.total)")
        return parts.joined(separator: " \u{00B7} ")
    }

    /// "On site 3 Oct 2026: zip broken" — the line a maintenance note leaves on the
    /// thing. Without a usable day it is just "On site: zip broken".
    public static func onSiteNoteLine(_ text: String, today: String) -> String {
        let note = jsTrim(text)
        let p = today.split(separator: "-").compactMap { Int($0) }
        guard isYMD(today), p.count == 3, (1...12).contains(p[1]) else { return "On site: \(note)" }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "On site \(p[2]) \(months[p[1] - 1]) \(p[0]): \(note)"
    }

    /// Does a thing's note already say this? A line counts when it says the same words
    /// — on its own, or after an "On site <day>:" of any day — so saving the same note
    /// again, today or tomorrow, never writes it twice.
    static func noteAlreadySays(_ note: String, _ text: String) -> Bool {
        let want = normName(text)
        guard !want.isEmpty else { return true }
        return note.split(whereSeparator: \.isNewline).contains { raw in
            let line = jsTrim(String(raw))
            if normName(line) == want { return true }
            guard line.hasPrefix("On site"), let colon = line.firstIndex(of: ":") else { return false }
            return normName(String(line[line.index(after: colon)...])) == want
        }
    }

    /// A maintenance note made on site — "zip broken", "wash before next trip". It is
    /// kept on the trip's line (as Pack to go home's Note always was), and, when the line
    /// has a thing behind it, it ALSO lands on that thing's own note as one dated line,
    /// for Care (his choice, 3 Oct 2026). Once: the same words already there are not
    /// written again. An empty note clears the trip's line only — what reached the thing
    /// is his now, and stays.
    @discardableResult
    public mutating func noteOnSite(_ text: String, tripId: String, entryId: String, today: String) -> Bool {
        guard setHomeNote(text, tripId: tripId, entryId: entryId) else { return false }
        let note = jsTrim(text)
        guard !note.isEmpty,
              let line = trips.first(where: { $0.id == tripId })?.entries.first(where: { $0.id == entryId }),
              let thing = thingBehind(line),
              let now = items.first(where: { $0.id == thing })?.note,
              !Library.noteAlreadySays(now, note) else { return true }
        let add = Library.onSiteNoteLine(note, today: today)
        let old = jsTrim(now)
        _ = updateThing(id: thing) { $0.note = old.isEmpty ? add : old + "\n" + add }
        return true
    }
}
