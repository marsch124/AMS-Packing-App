import Foundation
import PackingCore

// The lists he authors himself: storage places, owners, packers, conditions, and
// the "When" timeline. They SYNC (web app v120: a list you author belongs to the
// account, not to a device), and the factory versions live in the CODE — a kind
// with no rows means "use the defaults", and writing a list that is still exactly
// the factory one REMOVES its rows rather than storing them. Nothing is ever
// seeded (the v118 lesson: seeded rows landed on top of his own and replaced them).

extension Library {
    public func storagePlaces() -> [String] {
        let mine = orderedNamesFromRows(shared, "places")
        return mine.isEmpty ? DEFAULT_STORAGE_LOCATIONS : mine
    }
    /// A–Z, as every Owner dropdown has always offered them.
    public func owners() -> [String] { namesFromRows(shared, "owners") }
    public func people() -> [Person] {
        let mine = peopleFromRows(shared)
        return mine.isEmpty ? DEFAULT_PEOPLE.map { newPerson(name: $0.name, color: $0.color) } : mine
    }
    public func conditions() -> [ItemCondition] {
        let mine = conditionsFromRows(shared)
        return mine.isEmpty ? DEFAULT_ITEM_CONDITIONS : mine
    }
    /// The "When" timeline in force — his own, or the factory seven.
    public func timeline() -> [Phase] { phases.isEmpty ? DEFAULT_PHASES : phases }

    /// How many things, trip lines and to-dos point at each entry of a list, so a
    /// screen can refuse to remove one that is in use.
    public func usesOf(_ kind: String) -> [String: Int] {
        var n: [String: Int] = [:]
        func add(_ v: String) { let k = normName(v); if !k.isEmpty { n[k, default: 0] += 1 } }
        for it in items {
            switch kind {
            case "places": add(it.storage)
            case "owners": add(it.ownedBy)
            case "people": add(it.packer)
            case "conditions": add(it.condition)
            case "phases": add(it.phase)
            default: break
            }
        }
        if kind == "phases" {
            for t in trips { for e in t.entries { add(e.phase) } }
            for m in memberships { add(m.phase) }
        }
        return n
    }

    // MARK: - Writing a list back

    @discardableResult
    public mutating func setNames(_ kind: String, _ names: [String]) -> Bool {
        guard kind == "places" || kind == "owners" else { return false }
        let clean = names.map(jsTrim).filter { !$0.isEmpty }
        shared.removeAll { $0.kind == kind }
        if !isFactoryList(kind, clean.map { JSONValue($0) }) {
            shared.append(contentsOf: namesToRows(kind, clean))
        }
        return true
    }

    @discardableResult
    public mutating func setPeople(_ list: [Person]) -> Bool {
        shared.removeAll { $0.kind == "people" }
        if !isFactoryList("people", list.map { $0.json }) { shared.append(contentsOf: peopleToRows(list)) }
        return true
    }

    @discardableResult
    public mutating func setConditions(_ list: [ItemCondition]) -> Bool {
        shared.removeAll { $0.kind == "conditions" }
        if !isFactoryList("conditions", list.map { $0.json }) { shared.append(contentsOf: conditionsToRows(list)) }
        _ = setItemConditions(list.isEmpty ? DEFAULT_ITEM_CONDITIONS : list)
        return true
    }

    /// The "When" steps. Stored only when they differ from the factory seven — and
    /// the live PHASES are set from them, because every item points into this list.
    @discardableResult
    public mutating func setTimeline(_ list: [Phase]) -> Bool {
        let settled = setPhases(list.isEmpty ? DEFAULT_PHASES : list)
        phases = phasesCustomised(settled) ? settled : []
        return true
    }
}
