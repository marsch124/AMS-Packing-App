import PackingCore

// A trip line's menu (0.104) — his words, 28 Oct 2026: "During my packing, I sometimes don't understand
// what the English word means, so I would need to have a way to see the notes for an item. I can't click
// the item … because that would check the radio button indicating that the item is packed." So a line
// has a menu (right-click on the Mac, a press held on the iPhone), and its Show note gathers everything
// written about the line's thing, each under a small label. Spec 03, "A line's menu".

/// One thing said about a trip line, under its label.
public struct LineNote: Equatable, Sendable {
    public enum Kind: String, Sendable {
        /// The thing's Swedish name — the web app's original wording — when it is not the line's name.
        case swedish
        /// The thing's own Notes.
        case thing
        /// A note one of his templates keeps for the thing (`rowNotes`).
        case template
        /// The line's own note on this trip, when it says something none of the above says (a line sent
        /// by someone else, or one packed with a note that has changed since).
        case line
        /// The line's note for the way home (On site, 0.88).
        case home
    }
    public let kind: Kind
    /// The small words above it: "In Swedish", "Note", "Note on the Hiking template", "Note on this
    /// trip", "Note for the way home".
    public let label: String
    public let text: String
    public init(kind: Kind, label: String, text: String) {
        self.kind = kind
        self.label = label
        self.text = text
    }
}

extension Library {
    /// Everything written about each line of a trip, for the lines that have something — asked once for
    /// the whole list, the templates' rows read once (not once per line). Lines with nothing are absent.
    public func lineNotes(tripId: String) -> [String: [LineNote]] {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return [:] }
        let things = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let templates = templatesForThings()
        var rows: [String: [Membership]] = [:]
        for m in memberships { rows[m.itemId, default: []].append(m) }
        var out: [String: [LineNote]] = [:]
        for line in trip.entries where out[line.id] == nil {
            let thing = line.sourceItemId.flatMap { things[$0] }
            let notes = Library.notes(on: line, thing: thing,
                                      templateNotes: thing.map { Library.rowNotes(of: $0, rows: rows[$0.id] ?? [], templates: templates) } ?? [])
            if !notes.isEmpty { out[line.id] = notes }
        }
        return out
    }

    /// The same for one line.
    public func lineNotes(tripId: String, entryId: String) -> [LineNote] {
        guard let line = trips.first(where: { $0.id == tripId })?.entries.first(where: { $0.id == entryId }) else { return [] }
        let thing = line.sourceItemId.flatMap { id in items.first { $0.id == id } }
        return Library.notes(on: line, thing: thing, templateNotes: thing.map { rowNotes(itemId: $0.id) } ?? [])
    }

    /// In this order: the Swedish name, the thing's own note, its templates' notes (in their order), the
    /// line's own note when it says something new, the note for the way home. Each trimmed; blank = none.
    /// The thing is the one the line was built from (`thingBehind`) — a line typed on the trip has none,
    /// and only its own words.
    static func notes(on line: Item, thing: Item?, templateNotes: [RowNote]) -> [LineNote] {
        var out: [LineNote] = []
        let swedish = jsTrim(thing.map(\.swedish) ?? "").isEmpty ? jsTrim(line.swedish) : jsTrim(thing?.swedish ?? "")
        if !swedish.isEmpty, normName(swedish) != normName(line.name) {
            out.append(LineNote(kind: .swedish, label: "In Swedish", text: swedish))
        }
        let own = jsTrim(thing?.note ?? "")
        if !own.isEmpty { out.append(LineNote(kind: .thing, label: "Note", text: own)) }
        for said in templateNotes {
            out.append(LineNote(kind: .template, label: "Note on the \(said.template) template", text: said.note))
        }
        let mine = jsTrim(line.note)
        if !mine.isEmpty, mine != own, !templateNotes.contains(where: { $0.note == mine }) {
            out.append(LineNote(kind: .line, label: "Note on this trip", text: mine))
        }
        let home = jsTrim(Library.homeNote(line))
        if !home.isEmpty { out.append(LineNote(kind: .home, label: "Note for the way home", text: home)) }
        return out
    }

    /// What the Mac shows when the pointer rests on a line (0.104): every note, one per line, its label first.
    public static func lineNotesTip(_ notes: [LineNote]) -> String {
        notes.map { "\($0.label): \($0.text)" }.joined(separator: "\n")
    }
}
