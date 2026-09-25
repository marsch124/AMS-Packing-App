import Foundation
import PackingCore

// Renaming a list, and getting rid of one.
//
// His ask: "You don't need to merge the content of the two templates — I can add
// items later on. Just delete one and rename the existing."
//
// Neither was possible in the app before this. The rules that matter: a rename
// refuses a name he already has (two lists with one name is what the health check
// reads as two libraries meeting), and a delete takes the list and its rows —
// never the THINGS, which live in the catalogue and are on other lists too.

extension Library {
    /// Rename a list. Refuses an empty name, and a name another list already has.
    @discardableResult
    public mutating func renameTemplate(id: String, to name: String) -> Bool {
        let wanted = jsTrim(name)
        guard !wanted.isEmpty, let n = templates.firstIndex(where: { $0.id == id }) else { return false }
        let taken = templates.contains { $0.id != id && normName($0.name) == normName(wanted) }
        guard !taken else { return false }
        templates[n].name = wanted
        templates[n].updatedAt = nowISO()
        return true
    }

    /// Take a list away. Its rows go with it; the things stay, because a thing
    /// belongs to the catalogue and is usually on other lists too. Trips already
    /// built from it are untouched — a trip's lines stand on their own.
    @discardableResult
    public mutating func deleteTemplate(id: String) -> Bool {
        guard templates.contains(where: { $0.id == id }) else { return false }
        memberships.removeAll { $0.templateId == id }
        templates.removeAll { $0.id == id }
        return true
    }
}
