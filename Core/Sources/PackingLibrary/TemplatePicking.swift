import PackingCore

// His tests H.9 and H.3 (2026-09-28): "How do we add things to a template? We need
// the list of things … choose from existing ones and also define new ones … order,
// sort and group the things to pick from in a variety of ways, the same as when
// packing" — and a template's own things grouped and sorted the same ways.

/// The ways a set of things can be grouped: as a template reads (its sections), by
/// the packing timeline, by bag, by where it is kept at home, by kind, or A–Z.
public enum ThingGrouping: String, CaseIterable, Sendable {
    case section, when, into, fromWhere, kind, name

    /// The words on its button — the same words as the trip's sorting.
    public var label: String {
        switch self {
        case .section: return "Section"
        case .when: return "When"
        case .into: return "Into"
        case .fromWhere: return "From where"
        case .kind: return "Kind"
        case .name: return "A–Z"
        }
    }

    /// Group `items` this way. Titles are what the screen shows over each group;
    /// "not said" groups come last. Inside a group the things read A–Z — except by
    /// Section, where they keep the template's own order (his order, as the trip
    /// reads it). The template page groups When with `entriesByPhase` itself, so
    /// there too the rows keep the template's order; only the picker's When is A–Z,
    /// to find a thing among all he owns (decided by the spec pass, 5 Oct 2026).
    public func groups(_ items: [Item], sections: [TemplateSection] = []) -> [(title: String, items: [Item])] {
        let az: ([Item]) -> [Item] = { $0.stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) }) }
        switch self {
        case .section:
            return groupItemsBySection(items, sections).map { ($0.section?.name ?? "Everything else", $0.items) }
        case .when:
            return entriesByPhase(items).map { ($0.phase.label, az($0.entries)) }
        case .into:
            return groupByContainer(items).map { ($0.container, az($0.entries)) }
        case .fromWhere:
            return ThingGrouping.byWords(items, { $0.storage }, notSaid: "No place set").map { ($0.0, az($0.1)) }
        case .kind:
            return ThingGrouping.byWords(items, { $0.category }, notSaid: "No kind set").map { ($0.0, az($0.1)) }
        case .name:
            return items.isEmpty ? [] : [("A–Z", az(items))]
        }
    }

    /// Groups by a word the thing carries, A–Z, with the ones that say nothing last.
    static func byWords(_ items: [Item], _ word: (Item) -> String, notSaid: String) -> [(String, [Item])] {
        var groups: [(String, [Item])] = []
        var loose: [Item] = []
        for it in items {
            let w = jsTrim(word(it))
            if w.isEmpty { loose.append(it); continue }
            if let i = groups.firstIndex(where: { normName($0.0) == normName(w) }) { groups[i].1.append(it) }
            else { groups.append((w, [it])) }
        }
        let sorted = groups.stableSorted(compare: { a, b in jsLocaleCompare(a.0, b.0, sensitivity: .base) })
        return loose.isEmpty ? sorted : sorted + [(notSaid, loose)]
    }
}

extension Library {
    /// Put things he already owns on a template, in one go. A thing already on it
    /// is left as it is (never twice from the picker). Returns how many were put on.
    @discardableResult
    public mutating func putOnTemplate(templateId: String, itemIds: [String]) -> Int {
        guard var list = resolvedTemplate(id: templateId) else { return 0 }
        let already = Set(memberships.filter { $0.templateId == templateId }.map(\.itemId))
        var added = 0
        var seen = Set<String>()
        for id in itemIds where !already.contains(id) && !seen.contains(id) {
            guard let thing = items.first(where: { $0.id == id }) else { continue }
            seen.insert(id)
            var row = resolveItemAlone(thing)      // the thing's own defaults come along
            row.memId = nil
            list.items.append(row)
            added += 1
        }
        if added > 0 { saveTemplate(list) }
        return added
    }

    /// The ids of the things on a template — what the picker shows as already there.
    public func thingIds(onTemplate templateId: String) -> Set<String> {
        Set(memberships.filter { $0.templateId == templateId }.map(\.itemId))
    }
}
