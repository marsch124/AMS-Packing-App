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

    /// The area that is not an activity area: "Always packed" (role "base") — the
    /// templates every Full trip brings, without being ticked.
    public static let ALWAYS_PACKED_AREA = "base"

    /// Move a template to another activity area (GA, WET, OE, or "" = none) — his
    /// choice on New, which could not be put right afterwards until the spec pass
    /// (5 Oct 2026) — or into and out of Always packed (0.71, `ALWAYS_PACKED_AREA`).
    ///
    /// 0.71 (8 Oct 2026): his always-packed template had grown too big for a short
    /// trip. The way out he agreed: a small always-packed core, and the big one a
    /// template he ticks for the longer trips. So an always-packed template can now
    /// go to GA / WET / OE / none, and any activity template can become always packed.
    /// Only the role and the area change: its things, sections, notes, reminders and
    /// every row's own answers are the template's and stay as they are. Into Always
    /// packed its area is cleared (it is filed by what it does); out of it, it gets
    /// the area picked. Several always-packed templates are fine (every Full trip
    /// brings each of them), and so is none. Transport templates stay where they are
    /// (refused, false), as does an area that is not one of his.
    @discardableResult
    public mutating func setTemplateArea(id: String, area: String) -> Bool {
        guard let n = templates.firstIndex(where: { $0.id == id }) else { return false }
        let role = templates[n].role
        guard role.isEmpty || role == Library.ALWAYS_PACKED_AREA else { return false }
        let always = area == Library.ALWAYS_PACKED_AREA
        guard always || area.isEmpty || GROUP_IDS.contains(area) else { return false }
        let newRole = always ? Library.ALWAYS_PACKED_AREA : "", newGroup = always ? "" : area
        guard templates[n].role != newRole || templates[n].group != newGroup else { return true }
        templates[n].role = newRole
        templates[n].group = newGroup
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
