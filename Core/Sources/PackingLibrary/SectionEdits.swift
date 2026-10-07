import Foundation
import PackingCore

// A template's sections changed from a thing's page (0.68) — his ask, with a picture of
// a Section list open on a thing's page: "I would like to be able to Rename, Change and
// Delete Sections from this here as well." The page holds them until Save (Cancel leaves
// the template as it was), then hands them here in one go. There is no second way of
// doing any of it: each change is Arrange's own — `removeSection`, `renameSection`,
// `moveSection` (Library.swift) — so a section renamed, moved or removed here is exactly
// what it would be on the template's page.

/// What a page did to ONE template's sections before it was saved.
public struct SectionEdits: Equatable, Sendable {
    /// Section id → its new name.
    public var names: [String: String] = [:]
    /// Every section id in the new order; nil = the order was not changed.
    public var order: [String]? = nil
    /// Section ids taken away (their things stay on the template, under no section).
    public var removed: Set<String> = []

    public init(names: [String: String] = [:], order: [String]? = nil, removed: Set<String> = []) {
        self.names = names; self.order = order; self.removed = removed
    }

    public var isEmpty: Bool { names.isEmpty && order == nil && removed.isEmpty }
}

extension Library {
    /// A template's sections as a page shows them while it holds `edits`: in the new
    /// order, under the new names, the removed ones still there (the page strikes them
    /// out) — `removed` says which. Sections the template no longer has are dropped, and
    /// any it gained since (on the other device) come last.
    public func sectionsAsEdited(templateId: String, _ edits: SectionEdits) -> [TemplateSection] {
        guard let t = templates.first(where: { $0.id == templateId }) else { return [] }
        let byId = Dictionary(t.sections.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let ordered = (edits.order ?? []).filter { byId[$0] != nil }
        let ids = ordered + t.sections.map(\.id).filter { !ordered.contains($0) }
        return ids.compactMap { id in
            guard var s = byId[id] else { return nil }
            if let name = edits.names[id] { s.name = name }
            return s
        }
    }

    /// Would this name be a second section of that name on the template, as the page
    /// shows it (`edits` held, the removed ones gone)? Blank is never taken.
    public func sectionNameTaken(templateId: String, name: String, except sectionId: String, _ edits: SectionEdits) -> Bool {
        let wanted = normName(name)
        guard !wanted.isEmpty else { return false }
        return sectionsAsEdited(templateId: templateId, edits)
            .contains { $0.id != sectionId && !edits.removed.contains($0.id) && normName($0.name) == wanted }
    }

    /// Writes a page's section edits to the template, through Arrange's own functions:
    /// the removed first (their things stay on it, under no section, and their names are
    /// free), then the names, then the order. Two sections that swap names both get
    /// theirs (each is parked under a name nobody has on the way). Returns whether
    /// anything changed. Nothing for an unknown template or empty edits.
    @discardableResult
    public mutating func applySectionEdits(templateId: String, _ edits: SectionEdits) -> Bool {
        guard !edits.isEmpty, let t = templates.firstIndex(where: { $0.id == templateId }) else { return false }
        let before = (templates[t].sections, memberships.filter { $0.templateId == templateId })
        let have = Set(templates[t].sections.map(\.id))
        for id in edits.removed.sorted() where have.contains(id) {
            removeSection(templateId: templateId, sectionId: id)
        }
        let current = Dictionary(templates[t].sections.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        var waiting = edits.names.filter { current[$0.key] != nil && jsTrim($0.value) != current[$0.key] && !jsTrim($0.value).isEmpty }
        var moved = true
        while !waiting.isEmpty && moved {
            moved = false
            for (id, name) in waiting.sorted(by: { $0.key < $1.key })
            where renameSection(templateId: templateId, sectionId: id, to: name) {
                waiting[id] = nil
                moved = true
            }
        }
        if !waiting.isEmpty {
            // A swap (A → B while B → A): each to a name of its own first, then to its new one.
            for id in waiting.keys.sorted() { renameSection(templateId: templateId, sectionId: id, to: "\u{2063}\(id)") }
            for (id, name) in waiting.sorted(by: { $0.key < $1.key }) { renameSection(templateId: templateId, sectionId: id, to: name) }
        }
        if let order = edits.order {
            let wanted = order.filter { id in templates[t].sections.contains { $0.id == id } }
            if wanted != templates[t].sections.map(\.id).filter({ wanted.contains($0) }) {
                for id in wanted { moveSection(templateId: templateId, sectionId: id, before: nil) }
            }
        }
        return before.0 != templates[t].sections || before.1 != memberships.filter { $0.templateId == templateId }
    }
}
