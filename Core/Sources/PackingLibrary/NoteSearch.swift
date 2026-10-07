import Foundation
import PackingCore

// Search also finds notes (0.69, with the places' codes): a thing is found by words in its
// own Notes and in the notes its templates keep for it (`rowNotes`) — "where did I
// write that the pump needs the blue adapter?". The screens show the line that matched
// under the thing, so a hit is never a puzzle.

/// Where a search's words were found in a thing's notes.
public struct NoteHit: Equatable, Sendable {
    /// The template whose own note it is; nil = the thing's own Notes.
    public let template: String?
    /// The line of the note that matched — cut down around the words in a long line.
    public let line: String
    public init(template: String?, line: String) { self.template = template; self.line = line }
}

extension Library {
    /// Every thing whose notes hold `query`, with its first matching line: its own Notes
    /// first, then its templates' notes in the order `rowNotes` lists them (a template's
    /// note that only repeats the thing's own is skipped there too). Words are matched as
    /// the names are (`normName`: case and spaces do not count). One pass over the
    /// templates' rows, not one per thing: Your things searches on every key press.
    public func noteHits(_ query: String) -> [String: NoteHit] {
        let needle = normName(query)
        guard !needle.isEmpty else { return [:] }
        var out: [String: NoteHit] = [:]
        var own: [String: String] = [:]
        for thing in items {
            own[thing.id] = jsTrim(thing.note)
            if let line = Library.matchingLine(thing.note, needle) { out[thing.id] = NoteHit(template: nil, line: line) }
        }
        var rowsOf: [String: [Membership]] = [:]
        for m in memberships { rowsOf[m.templateId, default: []].append(m) }
        for template in templatesForThings() {
            for row in (rowsOf[template.id] ?? []).sorted(by: { $0.order < $1.order }) {
                guard out[row.itemId] == nil, let mine = own[row.itemId] else { continue }
                let note = jsTrim(row.note)
                if note.isEmpty || note == mine { continue }
                if let line = Library.matchingLine(note, needle) { out[row.itemId] = NoteHit(template: template.name, line: line) }
            }
        }
        return out
    }

    /// The line of `note` that holds `needle` (already `normName`d), trimmed; a long one
    /// cut to start a little before the words, with "…" — so the words are on screen.
    static func matchingLine(_ note: String, _ needle: String, width: Int = 80) -> String? {
        for raw in note.split(whereSeparator: \.isNewline) {
            let line = jsTrim(String(raw))
            guard normName(line).contains(needle) else { continue }
            guard line.count > width,
                  let at = line.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) else { return line }
            let before = line.distance(from: line.startIndex, to: at.lowerBound)
            guard before > 24 else { return line }
            let start = line.index(at.lowerBound, offsetBy: -20)
            // From a word's beginning, not from the middle of one.
            let cut = line[start...].firstIndex(of: " ").map { line.index(after: $0) } ?? start
            return "\u{2026}" + line[(cut < at.lowerBound ? cut : start)...]
        }
        return nil
    }
}
