import PackingCore

// A thing's own note and the notes its templates keep for it (spec 05, item 18 —
// the spec pass of 5 Oct 2026). A row's note wins on a template and on the trips
// built from it, and a library from the web app keeps its notes there, not on the
// thing; so the thing's page could show an empty Notes while its templates said
// something. The page now lists them under its own note.

/// One template's own note for a thing.
public struct RowNote: Equatable {
    public let template: String
    public let note: String
}

extension Library {
    /// The notes this thing's templates keep for it on their own rows, in the order
    /// of the templates, then of the rows: only a note that says something the thing's
    /// own note does not (blank = "the same as the thing"). The bag list holds no
    /// things and is left out; one note said twice on one template is listed once.
    public func rowNotes(itemId: String) -> [RowNote] {
        guard let thing = items.first(where: { $0.id == itemId }) else { return [] }
        let own = jsTrim(thing.note)
        var notes: [RowNote] = []
        for template in templatesForThings() {
            let rows = memberships
                .filter { $0.templateId == template.id && $0.itemId == itemId }
                .sorted { $0.order < $1.order }
            for row in rows {
                let note = jsTrim(row.note)
                let said = RowNote(template: template.name, note: note)
                if note.isEmpty || note == own || notes.contains(said) { continue }
                notes.append(said)
            }
        }
        return notes
    }
}
