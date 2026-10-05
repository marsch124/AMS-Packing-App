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
        // The bag list's stored name ("Containers") is not one he can see, so it
        // does not count as taken (the spec pass, 5 Oct 2026).
        guard !templateNameTaken(wanted, except: id) else { return false }
        templates[n].name = wanted
        templates[n].updatedAt = nowISO()
        return true
    }

    /// Move a template to another activity area (GA, WET, OE, or "" = none) — his
    /// choice on New, which could not be put right afterwards until the spec pass
    /// (5 Oct 2026). Only an activity template has an area: always packed and
    /// transport templates are filed by what they do, so they are refused (false),
    /// as is an area that is not one of his.
    @discardableResult
    public mutating func setTemplateArea(id: String, area: String) -> Bool {
        guard let n = templates.firstIndex(where: { $0.id == id }), templates[n].role.isEmpty,
              area.isEmpty || GROUP_IDS.contains(area) else { return false }
        guard templates[n].group != area else { return true }
        templates[n].group = area
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
