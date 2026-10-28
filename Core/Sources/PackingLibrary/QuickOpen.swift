import Foundation
import PackingCore

// Quick open (0.105) — his yes of 28 Oct 2026 ("1. ⌘K - yes please") to the proposal: "⌘K quick open (Mac): type a
// few letters to jump to any thing, trip or template, or run a command like 'Group by Whose'".
//
// WHAT it finds, and in what order, is decided here, where the model's tests hold it; the panel that shows it is the
// app's (`Screens/QuickOpen.swift`), and so are the commands (they name the app's tabs and keys).
//
// MATCHING. Capitals and accents do not count — å ä ö are a a o, é is e — so "ost" finds "Östersund" and "ö" finds
// "Oslo". A name is found when what is typed is, best first:
//   100  the whole name                                  "tent"      → Tent
//    90  the start of the name                           "rai"       → Rain jacket
//    75  the start of a later word (and on from there)   "jack"      → Rain jacket, "jacket go" → Rain jacket Gore-Tex
//    60  the starts of several words, in any order       "ja ra"     → Rain jacket
//    45  the first letters of its words                  "rj"        → Rain jacket (two letters or more)
//    25  anywhere inside it                              "acke"      → Rain jacket (two letters or more)
// A word is a run of letters and digits: "T-shirt" is "t" and "shirt". A thing is also found by its Swedish name
// ("regnj" → Rain jacket, whose Swedish name is Regnjacka) one step below the same match on its own name, and its row
// then says the Swedish name; a command also by a few other words of its own ("icloud" → Sync details), not shown.
//
// ORDER. The groups always Things · Trips · Templates · Commands, an empty one left out; in a group the best match
// first, then the shorter name, then A to Z; at most five a group ("top 5 per group", his yes). Nothing typed: nothing
// listed — the panel says what it finds instead.

public enum QuickOpen {
    /// The groups, in the panel's order.
    public enum Kind: String, CaseIterable, Sendable {
        case thing, trip, template, command

        /// The group's heading.
        public var title: String {
            switch self {
            case .thing: return "Things"
            case .trip: return "Trips"
            case .template: return "Templates"
            case .command: return "Commands"
            }
        }
    }

    /// One thing the panel can open or run.
    public struct Entry: Equatable, Sendable {
        /// A thing's, trip's or template's id; a command's own name for the app.
        public var id: String
        public var kind: Kind
        public var title: String
        /// The line under the title ("Kept at home: Garage", "Lisbon · in 12 days", "14 things"); "" = none.
        public var under: String
        /// The other names it is found by: a thing's Swedish name, a command's other words.
        public var also: [String]
        /// The keys that do it too, as a menu shows them ("⌘1") — commands only; "" = none.
        public var keys: String
        /// A command that is the current choice (the Group by the trip shows now): ticked in the panel.
        public var current: Bool

        public init(id: String, kind: Kind, title: String, under: String = "", also: [String] = [], keys: String = "",
                    current: Bool = false) {
            self.id = id; self.kind = kind; self.title = title; self.under = under; self.also = also
            self.keys = keys; self.current = current
        }
    }

    /// An entry found, how well, and by which name.
    public struct Hit: Equatable, Sendable {
        public let entry: Entry
        public let score: Int
        /// A thing's Swedish name that found it while its own name did not ("Regnjacka"); nil otherwise.
        public let via: String?

        /// The line under the title: the Swedish name that found it, then the entry's own line.
        public var under: String {
            [via ?? "", entry.under].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
        }
    }

    /// One group of the panel: its kind and its hits, best first.
    public struct Group: Equatable, Sendable {
        public let kind: Kind
        public let hits: [Hit]
    }

    /// At most this many a group.
    public static let perGroup = 5

    /// The scores, best first (see the table at the top).
    public static let whole = 100, start = 90, laterWord = 75, wordStarts = 60, initials = 45, inside = 25
    /// Found by an other name (a Swedish name), this much lower than by its own.
    public static let byOtherName = 5

    /// As names are compared: capitals and accents gone ("Öl-kåsa" → "ol-kasa"), runs of spaces one space, trimmed.
    public static func fold(_ s: String) -> String {
        let f = s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return f.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// The words of a folded name: runs of letters and digits.
    public static func words(_ folded: String) -> [Substring] {
        folded.split(whereSeparator: { !($0.isLetter || $0.isNumber) })
    }

    /// How well `query` finds `name` (see the table at the top); nil = not at all.
    public static func score(_ query: String, name: String) -> Int? {
        let q = fold(query), n = fold(name)
        guard !q.isEmpty, !n.isEmpty else { return nil }
        if n == q { return whole }
        if n.hasPrefix(q) { return start }
        let nameWords = words(n)
        // From the start of a later word on: "jacket go" in "rain jacket gore-tex".
        for w in nameWords.dropFirst() where n[w.startIndex...].hasPrefix(q) { return laterWord }
        let typed = words(q)
        if typed.count > 1, typed.allSatisfy({ t in nameWords.contains { $0.hasPrefix(t) } }) { return wordStarts }
        if q.count >= 2, !q.contains(" "), String(nameWords.compactMap(\.first)).hasPrefix(q) { return initials }
        if q.count >= 2, n.contains(q) { return inside }
        return nil
    }

    /// How well `query` finds an entry — by its title, or a step lower by one of its other names — and which other
    /// name did it (a thing's Swedish name is said in its row; a command's other words are not).
    static func hit(_ query: String, _ entry: Entry) -> Hit? {
        let own = score(query, name: entry.title)
        var best: (score: Int, name: String)?
        for other in entry.also where !jsTrim(other).isEmpty {
            if let s = score(query, name: other).map({ $0 - byOtherName }), s > (best?.score ?? Int.min) { best = (s, other) }
        }
        if let own, own >= (best?.score ?? Int.min) { return Hit(entry: entry, score: own, via: nil) }
        guard let best else { return nil }
        return Hit(entry: entry, score: best.score, via: entry.kind == .thing ? jsTrim(best.name) : nil)
    }

    /// What `query` finds among `entries`: a group for each kind that has hits, in `Kind`'s order; in a group the best
    /// first, then the shorter name, then A to Z (capitals and accents not counting), at most `perGroup`.
    public static func find(_ query: String, in entries: [Entry], perGroup: Int = perGroup) -> [Group] {
        guard !fold(query).isEmpty else { return [] }
        let hits = entries.compactMap { hit(query, $0) }
        return Kind.allCases.compactMap { kind in
            let mine = hits.filter { $0.entry.kind == kind }.sorted { a, b in
                if a.score != b.score { return a.score > b.score }
                if a.entry.title.count != b.entry.title.count { return a.entry.title.count < b.entry.title.count }
                let fa = fold(a.entry.title), fb = fold(b.entry.title)
                return fa != fb ? fa < fb : a.entry.id < b.entry.id
            }
            return mine.isEmpty ? nil : Group(kind: kind, hits: Array(mine.prefix(perGroup)))
        }
    }
}

extension Library {
    /// Everything quick open can open: his things (not a template's reminders, not one without a name) with the place
    /// they are kept at home and their Swedish name; his trips with where they go and when; his templates as the
    /// Templates tab shows them (not the bag list), with how many things are on each. `today` (yyyy-mm-dd) says when
    /// a trip is.
    public func quickOpenEntries(today: String) -> [QuickOpen.Entry] {
        var out: [QuickOpen.Entry] = []
        for thing in ownThings() where !Library.isReminder(thing) && !jsTrim(thing.name).isEmpty {
            let kept = jsTrim(thing.storage)
            out.append(QuickOpen.Entry(id: thing.id, kind: .thing, title: jsTrim(thing.name),
                                       under: kept.isEmpty ? "" : "Kept at home: \(kept)",
                                       also: jsTrim(thing.swedish).isEmpty ? [] : [thing.swedish]))
        }
        for trip in trips where !jsTrim(trip.name).isEmpty {
            let when = trip.startDate.isEmpty ? "" : countdownLabel(daysUntil(trip.startDate, today))
            out.append(QuickOpen.Entry(id: trip.id, kind: .trip, title: jsTrim(trip.name),
                                       under: [jsTrim(trip.destination), when].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")))
        }
        for list in shownTemplates() where !jsTrim(list.name).isEmpty {
            let n = list.items.count
            out.append(QuickOpen.Entry(id: list.id, kind: .template, title: jsTrim(list.name),
                                       under: "\(n) thing\(n == 1 ? "" : "s")"))
        }
        return out
    }
}
