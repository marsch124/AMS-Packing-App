import Foundation
import PackingCore

// HIS OWN small headings in a grab list (0.85), set in Edit, as a template's headings are.
//
// His words, 15 Oct 2026: "How do I define the small headings, and how do I group the items
// in the various headings? I need to be able to do that, I believe." — and on 0.84, which
// grouped an open list by each thing's Kind of thing by itself: "I think you have
// misunderstood the grab list, and you have made the sections wrong." His grab lists are free
// text ("Start fans", "Open windows" are no things of his), so a kind of thing said nothing
// about them; he was already making groups by hand, with prefixes in the names. The 0.84
// grouping (`GrabKinds.swift`) is gone; this replaces it.
//
// A heading is a LINE of the list, as a thing is: a thing belongs to the heading above it, so
// he groups things by moving them under a heading. Headings are never ticked, skipped or
// counted — `GrabDefinition.items` holds the THINGS alone, so everything that ticks, counts,
// marks "1 in 10", says what is still missing or makes a list's link from a definition's
// `items` sees no heading, by construction.
//
// WHERE A HEADING IS KEPT: inside the list's own stored names, in a reserved form. Why not a
// field of its own — the checks of 15 Oct 2026:
//   • the store and iCloud keep a `grab` row's `data` whole (the record is the row's JSON),
//     but PackingCore reads a row into `GrabList` — `{ id, items, label, icon, tone }` and
//     nothing else — and every save of a list writes the row afresh from that shape
//     (`grabToRows`), so a field of ours would be dropped by the next edit;
//   • the backup writes a factory list as `prefs.grab.items` / `prefs.grab.meta` and his own
//     lists field by field (`own`), and the web app reads the same shape: a new field would
//     need a new key in the backup, the import and the share link, each a place to forget;
//   • PackingCore is the web app's model ported and held to it by the parity check.
// The names travel everywhere already — store, iCloud, the backup and its restore (both
// kinds of list), a share link and its import — so a heading kept AMONG them travels too,
// with nothing new to forget. And it is read back into a heading at the one door
// (`GrabLine.lines(stored:)`), so the reserved form is never shown.
//
// THE RESERVED FORM: U+2063 INVISIBLE SEPARATOR, "##", a space, the name. No keyboard types
// U+2063, so no name he ever typed can be read as a heading (his "- Sunscreen" and "❄️Hat"
// stay things, exactly as they were); JS's and our `jsTrim` leave it alone; it is a
// character XML and JSON both allow. Where it IS seen — the web app opening a shared link,
// or a device still on 0.84 — the line reads "## On me", which still says "a heading".

/// The start of a heading among a grab list's stored names (0.85).
public let GRAB_HEADING_MARK = "\u{2063}##"
/// The longest heading kept, in UTF-16 units: whole in a share link, which cuts every name at
/// `GRAB_SHARE_ITEM_MAX` (60) — the mark and its space take four.
public let GRAB_HEADING_MAX = GRAB_SHARE_ITEM_MAX - 4

/// One line of a grab list as he arranges it: a thing, or one of his headings.
public enum GrabLine: Equatable, Hashable, Sendable {
    case thing(String)
    case heading(String)

    /// The words on the line.
    public var name: String {
        get { switch self { case .thing(let n), .heading(let n): return n } }
        set { self = isHeading ? .heading(newValue) : .thing(newValue) }
    }

    public var isHeading: Bool {
        if case .heading = self { return true }
        return false
    }

    /// A heading as it is stored among the names.
    public static func storedHeading(_ name: String) -> String { GRAB_HEADING_MARK + " " + name }

    /// The heading's name when this stored name is one — nil for a thing.
    public static func headingName(stored: String) -> String? {
        let t = jsTrim(stored).unicodeScalars
        let mark = GRAB_HEADING_MARK.unicodeScalars
        guard t.starts(with: mark) else { return nil }
        return jsTrim(String(String.UnicodeScalarView(t.dropFirst(mark.count))))
    }

    /// The stored names, read as lines. A heading with no name is no line; a thing's name is
    /// kept exactly as stored.
    public static func lines(stored: [String]) -> [GrabLine] {
        stored.compactMap { s in
            guard let h = headingName(stored: s) else { return .thing(s) }
            return h.isEmpty ? nil : .heading(h)
        }
    }

    /// The lines, as they are stored.
    public static func stored(_ lines: [GrabLine]) -> [String] {
        lines.map { line in
            switch line {
            case .thing(let n): return n
            case .heading(let h): return storedHeading(h)
            }
        }
    }

    /// How many THINGS stored names hold — a shared list's "7 things".
    public static func thingCount(stored: [String]) -> Int {
        lines(stored: stored).filter { !$0.isHeading }.count
    }

    /// What a save keeps (0.85): every name trimmed and blanks dropped; a thing named twice
    /// (by its plain form) kept once, the first; a heading cut to `GRAB_HEADING_MAX`. Two
    /// headings may share a name — each is its own line.
    public static func cleaned(_ lines: [GrabLine]) -> [GrabLine] {
        var seen = Set<String>()
        return lines.compactMap { line in
            switch line {
            case .thing(let n):
                let name = jsTrim(n)
                guard !name.isEmpty, seen.insert(normName(name)).inserted else { return nil }
                return .thing(name)
            case .heading(let h):
                let name = jsTrim(jsSlice(jsTrim(h), 0, GRAB_HEADING_MAX))
                return name.isEmpty ? nil : .heading(name)
            }
        }
    }
}

/// One of his headings over its things, as an open list shows it.
public struct GrabGroup: Equatable, Sendable {
    /// His heading — "" for the things above his first heading, which stand under none.
    public var heading: String
    /// The things' places in the list's `items`, in his order.
    public var rows: [Int]

    public init(heading: String, rows: [Int]) { self.heading = heading; self.rows = rows }
}

extension GrabDefinition {
    /// The open list, under his headings: the things above his first heading first, under
    /// no heading; then each heading with the things under it, down to the next. A heading
    /// with nothing under it is not shown (Edit still has it). A list with no headings is
    /// ONE group under no heading — flat, exactly as before 0.85.
    public var groups: [GrabGroup] {
        var out: [GrabGroup] = []
        var current = GrabGroup(heading: "", rows: [])
        var n = 0
        for line in lines {
            switch line {
            case .heading(let h):
                if !current.rows.isEmpty { out.append(current) }
                current = GrabGroup(heading: h, rows: [])
            case .thing:
                current.rows.append(n)
                n += 1
            }
        }
        if !current.rows.isEmpty { out.append(current) }
        return out
    }

    /// Does he have a heading on it?
    public var hasHeadings: Bool { lines.contains { $0.isHeading } }
}
