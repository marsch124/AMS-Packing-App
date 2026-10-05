import Foundation
import PackingCore

// The lists he authors himself: storage places, owners, packers, conditions, and
// the "When" timeline. They SYNC (web app v120: a list you author belongs to the
// account, not to a device), and the factory versions live in the CODE — a kind
// with no rows means "use the defaults", and writing a list that is still exactly
// the factory one REMOVES its rows rather than storing them. Nothing is ever
// seeded (the v118 lesson: seeded rows landed on top of his own and replaced them).

/// What uses one entry of his lists (`Library.usesOf`).
public struct ChoiceUse: Equatable, Sendable {
    /// Things that say it.
    public var things = 0
    /// For a "When" step: trips with a line in it, and templates that put a thing in it.
    public var trips = 0
    public var templates = 0
    public init(things: Int = 0, trips: Int = 0, templates: Int = 0) {
        self.things = things; self.trips = trips; self.templates = templates
    }
    public var inUse: Bool { things + trips + templates > 0 }

    /// Why `label` cannot be removed, saying what is counted — "Morning list is still
    /// used by 3 things, on 2 trips and on 1 template, so it stays." The number was
    /// once trip lines and template places called "things" (the spec pass, 5 Oct 2026).
    public func refusal(_ label: String) -> String {
        func n(_ count: Int, _ word: String) -> String { "\(count) \(word)\(count == 1 ? "" : "s")" }
        var parts: [String] = []
        if things > 0 { parts.append("by " + n(things, "thing")) }
        if trips > 0 { parts.append("on " + n(trips, "trip")) }
        if templates > 0 { parts.append("on " + n(templates, "template")) }
        let said = parts.count > 1 ? parts.dropLast().joined(separator: ", ") + " and " + parts.last! : (parts.first ?? "")
        return "\(label) is still used \(said), so it stays."
    }
}

extension Library {
    public func storagePlaces() -> [String] {
        let mine = orderedNamesFromRows(shared, "places")
        return mine.isEmpty ? DEFAULT_STORAGE_LOCATIONS : mine
    }
    /// His Owners, A–Z, as every Owner dropdown has always offered them. With no
    /// list of his own yet: the owners his things already name, A–Z.
    ///
    /// Why (the spec pass, 5 Oct 2026): Owners has no factory list, so on an account
    /// that never added one, Your choices showed an empty Owners part while "Whose it
    /// is" on a thing offered those very names — as Packers did before `people()` got
    /// the same step. Things only, not trip lines: every name shown is then in use by a
    /// thing, so none can be removed only to come straight back from an old trip.
    public func owners() -> [String] {
        let mine = namesFromRows(shared, "owners")
        return mine.isEmpty ? Library.eachNameOnce(then: items.map(\.ownedBy)) : mine
    }
    /// What "Whose it is" offers on a thing: his owners list, plus anyone a thing
    /// already names who is not on it — EACH ONCE. (The editor used to add every
    /// thing's owner as it came, so one name appeared once per thing he owns: a
    /// screenful of the same name, all lit up. His screenshot, 2026-09-26.)
    public func ownerChoices() -> [String] {
        Library.eachNameOnce(owners(), then: items.map(\.ownedBy))
    }
    /// `first` as it is, then `then` A–Z — trimmed, empties dropped, each normalised
    /// name once (the first spelling met wins).
    private static func eachNameOnce(_ first: [String] = [], then: [String]) -> [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for name in first + then.map(jsTrim).filter({ !$0.isEmpty })
                                .stableSorted(compare: { a, b in jsLocaleCompare(a, b) }) {
            let key = normName(name)
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            out.append(name)
        }
        return out
    }
    /// His Packers. With no list of his own yet: the people his things already name,
    /// A–Z, else the two starters in the code.
    ///
    /// Why the middle step (the spec pass, 5 Oct 2026): the starters used to be his own
    /// household by name, and an account that never edited Packers showed them straight
    /// from the code. The code now names two INVENTED people (the repository is public),
    /// so on such an account the names his things carry are what keeps his Packers his.
    public func people() -> [Person] {
        let mine = peopleFromRows(shared)
        if !mine.isEmpty { return mine }
        // Things only, not trip lines: then every name here is in use by a thing, so
        // none can be removed only to come straight back from an old trip.
        let named = assignedPeople(items)
            .stableSorted(compare: { a, b in jsLocaleCompare(a, b) })
        if !named.isEmpty {
            return named.enumerated().map { n, name in newPerson(name: name, color: PERSON_COLORS[n % PERSON_COLORS.count]) }
        }
        return DEFAULT_PEOPLE.map { newPerson(name: $0.name, color: $0.color) }
    }
    public func conditions() -> [ItemCondition] {
        let mine = conditionsFromRows(shared)
        return mine.isEmpty ? DEFAULT_ITEM_CONDITIONS : mine
    }
    /// The "When" timeline in force — his own, or the factory seven.
    public func timeline() -> [Phase] { phases.isEmpty ? DEFAULT_PHASES : phases }

    /// What uses each entry of a list, by its normalised key, so a screen can show how
    /// many THINGS use it and refuse to remove one that is in use.
    ///
    /// Things, for every kind. For a "When" step ALSO the trips with a line in it and
    /// the templates that put a thing in it — a step that vanished would leave those
    /// lines and places pointing at nothing — counted apart, so the number shown next
    /// to a step is its things alone (the spec pass, 5 Oct 2026: "used by 40 things"
    /// counted trip lines and template places). To-dos are not counted: a to-do's
    /// When is only a label, and it reads as the fallback step when its own is gone.
    public func usesOf(_ kind: String) -> [String: ChoiceUse] {
        var n: [String: ChoiceUse] = [:]
        for it in items {
            let v: String
            switch kind {
            case "places": v = it.storage
            case "owners": v = it.ownedBy
            case "people": v = it.packer
            case "conditions": v = it.condition
            case "phases": v = it.phase
            default: continue
            }
            let k = normName(v)
            if !k.isEmpty { n[k, default: ChoiceUse()].things += 1 }
        }
        if kind == "phases" {
            for t in trips {
                for k in Set(t.entries.map { normName($0.phase) }) where !k.isEmpty { n[k, default: ChoiceUse()].trips += 1 }
            }
            var byTemplate: [String: Set<String>] = [:]
            for m in memberships {
                let k = normName(m.phase)
                if !k.isEmpty { byTemplate[k, default: []].insert(m.templateId) }
            }
            for (k, ids) in byTemplate { n[k, default: ChoiceUse()].templates = ids.count }
        }
        return n
    }

    /// The entry of his list that `name` would repeat, as the list spells it — nil when
    /// it is new. Places, owners and packers are the same when the store could not tell
    /// them apart (`choiceKey`); a condition or a step when its words are the same.
    /// `except` is the key of the entry being renamed, which may keep its own name.
    public func existingChoice(_ kind: String, _ name: String, except: String? = nil) -> String? {
        let want = Library.choiceKey(name)
        if want.isEmpty { return nil }
        switch kind {
        case "places", "owners", "people":
            let names = kind == "places" ? storagePlaces() : kind == "owners" ? owners() : people().map(\.name)
            return names.first { $0 != except && Library.choiceKey($0) == want }
        case "conditions":
            return conditions().first { $0.id != except && Library.choiceKey($0.label) == want }?.label
        case "phases":
            return timeline().first { $0.id != except && Library.choiceKey($0.label) == want }?.label
        default:
            return nil
        }
    }

    /// The key a place, owner or packer is STORED under: the normalised name cut to 60
    /// UTF-16 units, as `coerceSharedRow` cuts it. Two names alike that far are one row
    /// to the store, so here they are one name (the spec pass, 5 Oct 2026: two long
    /// names shared a record and the next load kept only one).
    public static func choiceKey(_ name: String) -> String { jsSlice(normName(name), 0, 60) }

    /// Each name once by `choiceKey`, first spelling wins — so no two rows ever share an id.
    private static func onePerKey(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert(choiceKey($0)).inserted }
    }

    // MARK: - Renaming and moving an entry (his own lists, the spec pass, 5 Oct 2026)

    /// Renames one entry, and everything that carries its name with it: for a place,
    /// an owner or a packer, every thing and every trip line that says the old name
    /// (whatever its spelling) says the new one. A condition or a step is pointed at by
    /// its id, which stays, so only its words change. `key` is the entry's stored
    /// spelling (places, owners, packers) or its id (conditions, steps).
    ///
    /// Returns what was wrong, in his words, or nil when it is done. A name he already
    /// has is refused rather than merged: two entries becoming one could not be undone
    /// by renaming back.
    @discardableResult
    public mutating func renameChoice(_ kind: String, key: String, to newName: String) -> String? {
        let name = jsTrim(newName)
        if name.isEmpty { return "Type a name first." }
        if let twin = existingChoice(kind, name, except: key) { return "You already have \(twin)." }
        switch kind {
        case "places", "owners", "people":
            // A name that things already carry, though it is not on the list, would
            // merge them too.
            if Library.choiceKey(name) != Library.choiceKey(key), (usesOf(kind)[normName(name)]?.things ?? 0) > 0 {
                return "Some of your things already say \(name). Pick another name."
            }
            let old = normName(key)
            func carry(_ v: inout String) { if !old.isEmpty && normName(v) == old { v = name } }
            if kind == "people" {
                var list = people()
                guard let n = list.firstIndex(where: { $0.name == key }) else { return nil }
                list[n].name = name
                setPeople(list)
                for i in items.indices { carry(&items[i].packer) }
                for t in trips.indices { for e in trips[t].entries.indices { carry(&trips[t].entries[e].packer) } }
            } else {
                var list = kind == "places" ? storagePlaces() : owners()
                guard let n = list.firstIndex(of: key) else { return nil }
                list[n] = name
                setNames(kind, list)
                for i in items.indices { kind == "places" ? carry(&items[i].storage) : carry(&items[i].ownedBy) }
                for t in trips.indices {
                    for e in trips[t].entries.indices {
                        kind == "places" ? carry(&trips[t].entries[e].storage) : carry(&trips[t].entries[e].ownedBy)
                    }
                }
            }
        case "conditions":
            var list = conditions()
            guard let n = list.firstIndex(where: { $0.id == key }) else { return nil }
            list[n].label = jsSlice(name, 0, 60)
            setConditions(list)
        case "phases":
            var list = timeline()
            guard let n = list.firstIndex(where: { $0.id == key }) else { return nil }
            list[n].label = jsSlice(name, 0, 60)
            setTimeline(list)
        default:
            return nil
        }
        return nil
    }

    /// Whether a list's order is his to set. Owners are always A–Z (as every Owner
    /// dropdown offers them); the others keep the order he gives them.
    public static func canMove(_ kind: String) -> Bool { ["places", "people", "conditions", "phases"].contains(kind) }

    /// Moves one entry one place up (`by: -1`) or down (`by: 1`). False when it cannot
    /// move (the first up, the last down, an owner, an unknown key). Moving a list back
    /// into the factory order stores nothing again, like every other edit here.
    @discardableResult
    public mutating func moveChoice(_ kind: String, key: String, by step: Int) -> Bool {
        func moved<T>(_ list: [T], _ at: (T) -> Bool) -> [T]? {
            guard let n = list.firstIndex(where: at), list.indices.contains(n + step), step == 1 || step == -1 else { return nil }
            var out = list
            out.swapAt(n, n + step)
            return out
        }
        switch kind {
        case "places":
            guard let list = moved(storagePlaces(), { $0 == key }) else { return false }
            return setNames("places", list)
        case "people":
            guard let list = moved(people(), { $0.name == key }) else { return false }
            return setPeople(list)
        case "conditions":
            guard let list = moved(conditions(), { $0.id == key }) else { return false }
            return setConditions(list)
        case "phases":
            // `setPhases` sorts by `order`, so the new order is written into it.
            guard var list = moved(timeline(), { $0.id == key }) else { return false }
            for i in list.indices { list[i].order = Double(i) }
            return setTimeline(list)
        default:
            return false
        }
    }

    // MARK: - Writing a list back

    @discardableResult
    public mutating func setNames(_ kind: String, _ names: [String]) -> Bool {
        guard kind == "places" || kind == "owners" else { return false }
        let clean = Library.onePerKey(names.map(jsTrim).filter { !$0.isEmpty })
        shared.removeAll { $0.kind == kind }
        if !isFactoryList(kind, clean.map { JSONValue($0) }) {
            shared.append(contentsOf: namesToRows(kind, clean))
        }
        return true
    }

    @discardableResult
    public mutating func setPeople(_ list: [Person]) -> Bool {
        var seen = Set<String>()
        let list = list.filter { jsTrim($0.name).isEmpty || seen.insert(Library.choiceKey($0.name)).inserted }
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
