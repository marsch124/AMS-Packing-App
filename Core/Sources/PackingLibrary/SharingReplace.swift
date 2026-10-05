import Foundation
import PackingCore

// "Replace your <name> instead" — a shared template in place of one of his own.
//
// Until the spec pass (2026-10-05) Replace took EVERYTHING from the sender: the icon he
// had picked, his sections, cover, group and default bag, and every answer on every row
// (bag, "When", amount, note, "only on some trips", kit) — while the question said only
// "Replace your <name>?". Now Replace takes the sender's THINGS — which are on it, and
// in which order — and keeps what is his: the template itself as he set it up, and the
// answers on every thing that was already on it. The things new to it come with the
// sender's answers. The question says how many come in and how many leave.

extension Library {
    /// What a Replace would do to his template: how many of the sender's things are new
    /// to it, and how many of its things are not in the share (they leave the template;
    /// the things themselves stay his). Matched by name, as the share links them.
    public func replacePreview(id: String, with shared: SharedList) -> (comeIn: Int, leave: Int)? {
        guard let mine = resolvedTemplate(id: id) else { return nil }
        var left: [String: Int] = [:]
        for row in mine.items where !jsTrim(row.name).isEmpty { left[normName(row.name), default: 0] += 1 }
        let had = left.values.reduce(0, +)
        var comeIn = 0, matched = 0
        for row in shared.items where !jsTrim(row.name).isEmpty {
            let key = normName(row.name)
            if let n = left[key], n > 0 { left[key] = n - 1; matched += 1 } else { comeIn += 1 }
        }
        return (comeIn, had - matched)
    }

    /// The sentence under "Replace your <name>?".
    public func replaceWords(id: String, with shared: SharedList) -> String {
        guard let (comeIn, leave) = replacePreview(id: id, with: shared) else { return "" }
        var parts: [String] = []
        if comeIn > 0 { parts.append("\(comeIn) thing\(comeIn == 1 ? " comes" : "s come") in") }
        if leave > 0 { parts.append("\(leave) thing\(leave == 1 ? " leaves" : "s leave") it") }
        let change = parts.isEmpty ? "It keeps the same things, in their order." : parts.joined(separator: " and ") + "."
        return change + " Your icon, sections, bags and answers on the things you had stay yours."
    }

    /// A shared template in place of his `id`: its things, his template.
    @discardableResult
    public mutating func replaceTemplate(id: String, with shared: SharedList) -> PackList? {
        guard let old = templates.first(where: { $0.id == id }) else { return nil }
        let oldPlaces = memberships.filter { $0.templateId == id }
        guard importTemplate(shared, replacing: id) != nil,
              let n = templates.firstIndex(where: { $0.id == id }) else { return nil }
        let theirs = templates[n]

        // The rows: a thing that was on it keeps his answers (the membership he had,
        // matched by id first — the save reuses it — then by thing); a thing new to it
        // keeps the sender's, its section matched to one of his by name.
        var hisSections: [String: String] = [:]
        for s in old.sections where hisSections[normName(s.name)] == nil { hisSections[normName(s.name)] = s.id }
        var waiting = oldPlaces
        var sectionsUsed = Set<String>()
        for k in memberships.indices where memberships[k].templateId == id {
            var m = memberships[k]
            let at = waiting.firstIndex { $0.id == m.id } ?? waiting.firstIndex { $0.itemId == m.itemId }
            if let at {
                var his = waiting.remove(at: at)
                his.id = m.id
                his.order = m.order
                m = his
            } else if !m.section.isEmpty,
                      let name = theirs.sections.first(where: { $0.id == m.section })?.name {
                if let mine = hisSections[normName(name)] { m.section = mine } else { sectionsUsed.insert(m.section) }
            }
            memberships[k] = m
        }

        // The template: his, as he set it up — with any section of the sender's that a
        // new thing sits in and he has no section of that name for.
        var t = old
        t.sections = old.sections + theirs.sections.filter { sectionsUsed.contains($0.id) }
        t.updatedAt = theirs.updatedAt
        templates[n] = coerceList(t)
        return templates[n]
    }
}
