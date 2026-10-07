import Foundation
import PackingCore

// His own lists changed from inside a drop-down (0.69) — his ask (7 Oct 2026): "work on
// all the drop-downs so that they can be edited, changed, added, and deleted from within
// the drop-downs." 0.68 gave a template's Section list a pen, ↑ ↓ and Remove; this gives
// the same to every pick-one list whose choices are his own: Kind of thing, Whose it is,
// Kept at home, Usually packed in (his bags), a bag's pockets, When and Condition.
//
// A page holds what was done in its lists until it is saved (Cancel leaves every list as
// it was), then hands it here. There is no second way of doing any of it: each change is
// the one Your choices, the bag's page or the pockets make — `renameChoice`/`moveChoice`
// (SettingsLists.swift), `renameThing` and `addBag` (a bag), `renamePocket`/`movePocket`/
// `addPocket`/`removePocket` (Pockets.swift) — so a place renamed from a thing's page is
// exactly what it would be from Your choices: every thing and trip line that said the old
// name says the new one, and its printed code still opens it.
//
// The lists, by their `kind`: "places", "owners", "conditions", "phases" (When),
// "categories" (Kind of thing), "bags" and "pockets" (one bag's — `bag` names it).

/// What a page did to ONE of his lists before it was saved.
public struct ChoiceEdits: Equatable, Sendable {
    public var kind: String
    /// For "pockets": the bag's name, as stored.
    public var bag: String
    /// Entry key → its new name. A key is the entry's stored name, or its id for a
    /// condition or a When step (an id never changes, so nothing pointing at it moves).
    public var names: [String: String] = [:]
    /// Every key in the new order (added ones by `addedKey`); nil = the order was not changed.
    public var order: [String]? = nil
    /// Keys taken away — each refused, when asked, while anything used it.
    public var removed: Set<String> = []
    /// New entries, as typed, in the order they were added.
    public var added: [String] = []

    public init(kind: String, bag: String = "") { self.kind = kind; self.bag = bag }

    public var isEmpty: Bool { names.isEmpty && order == nil && removed.isEmpty && added.isEmpty }

    /// The key of an entry added on the page and not made yet (made on Save).
    public static func addedKey(_ name: String) -> String { "\u{0}+" + jsTrim(name) }
    public static func isAdded(_ key: String) -> Bool { key.hasPrefix("\u{0}+") }
}

/// One entry of a list as a page shows it while it holds edits.
public struct ChoiceRow: Equatable, Sendable {
    public var key: String
    public var label: String
    /// Struck out, with Put back: taken away on Save.
    public var removed = false
    /// Typed on the page: made on Save.
    public var added = false
}

extension Library {
    /// Whether a list's order is his to set: every one but Owners, which is A–Z.
    public static func choiceOrders(_ kind: String) -> Bool { kind != "owners" }

    /// The entries of one of his lists as stored, in its order. "bags" is his OWN bags
    /// only — never the built-in names offered to a library that has none.
    public func choiceRows(_ kind: String, bag: String = "") -> [ChoiceRow] {
        switch kind {
        case "places": return storagePlaces().map { ChoiceRow(key: $0, label: $0) }
        case "owners": return owners().map { ChoiceRow(key: $0, label: $0) }
        case "categories": return categories().map { ChoiceRow(key: $0, label: $0) }
        case "conditions": return conditions().map { ChoiceRow(key: $0.id, label: $0.label) }
        case "phases": return timeline().map { ChoiceRow(key: $0.id, label: $0.label) }
        case "bags":
            var seen = Set<String>()
            return bags().map { jsTrim($0.name) }.filter { !$0.isEmpty && seen.insert(normName($0)).inserted }
                .map { ChoiceRow(key: $0, label: $0) }
        case "pockets": return pockets(bag: bag).map { ChoiceRow(key: $0, label: $0) }
        default: return []
        }
    }

    /// A list as a page shows it while it holds `e`: in the new order, under the new names,
    /// the removed still there (struck out), the added last unless moved. Entries the list
    /// gained since (on the other device) come after the ordered ones.
    public func choicesAsEdited(_ e: ChoiceEdits) -> [ChoiceRow] {
        var rows = choiceRows(e.kind, bag: e.bag)
        let stored = Set(rows.map(\.key))
        for name in e.added { rows.append(ChoiceRow(key: ChoiceEdits.addedKey(name), label: name, added: true)) }
        for n in rows.indices {
            if let name = e.names[rows[n].key] { rows[n].label = name }
            rows[n].removed = e.removed.contains(rows[n].key)
        }
        guard let order = e.order else { return rows }
        let byKey = Dictionary(rows.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        let first = order.filter { byKey[$0] != nil && (stored.contains($0) || ChoiceEdits.isAdded($0)) }
        return first.compactMap { byKey[$0] } + rows.filter { !first.contains($0.key) }
    }

    /// Why an entry of a list cannot be renamed, moved or removed at all — nil for nearly
    /// all. (Documents & money and Reminders: the app reads them by their words.)
    public func choiceFixed(_ kind: String, _ key: String) -> String? {
        kind == "categories" ? Library.fixedCategory(key) : nil
    }

    /// What is wrong with `name` as the new name of entry `key` while the page holds `e` —
    /// nil when it may be taken. The same answers Your choices gives: blank, a name the list
    /// already has (as the page shows it), a name things already carry, a bag's name that
    /// another thing has.
    public func choiceNameProblem(_ e: ChoiceEdits, key: String, name: String) -> String? {
        let clean = jsTrim(name)
        if clean.isEmpty { return "Type a name first." }
        if let fixed = choiceFixed(e.kind, key) { return fixed }
        let want = Library.choiceKey(clean)
        if let twin = choicesAsEdited(e).first(where: { $0.key != key && !$0.removed && Library.choiceKey($0.label) == want }) {
            return "You already have \(twin.label)."
        }
        switch e.kind {
        case "places", "owners", "categories":
            // A name his things carry that is none of the list's would merge them.
            let listed = choiceRows(e.kind).contains { Library.choiceKey($0.key) == want }
            if !listed, want != Library.choiceKey(key), (usesOf(e.kind)[normName(clean)]?.things ?? 0) > 0 {
                return "Some of your things already say \(clean). Pick another name."
            }
        case "bags":
            // Bags are joined to things by name: a bag may not take another thing's name.
            let bagId = bags().first { normName($0.name) == normName(key) }?.id
            if items.contains(where: { $0.id != bagId && normName($0.name) == normName(clean) }) {
                return "You already have something called \(clean)."
            }
        default:
            break
        }
        return nil
    }

    /// What uses one entry, not counting the thing `except` (the page's own thing — its
    /// choice on the page counts instead). Things for every list; for a When step also the
    /// trips and templates (`usesOf`); for a pocket the trip lines packed in it.
    public func choiceUse(_ kind: String, key: String, bag: String = "", except: String? = nil) -> ChoiceUse {
        var lib = self
        if let except { lib.items.removeAll { $0.id == except } }
        switch kind {
        case "pockets":
            let b = normName(bag), p = normName(key)
            var use = ChoiceUse()
            use.things = lib.items.filter { normName($0.container) == b && normName(Library.usualPocket($0)) == p }.count
            use.trips = lib.trips.filter { t in
                t.entries.contains { e in
                    normName(e.container) == b
                        && (normName(e.extra[POCKET_KEY]?.stringValue ?? "") == p || normName(e.extra[HOME_POCKET_KEY]?.stringValue ?? "") == p)
                }
            }.count
            return use
        case "bags":
            let k = normName(key)
            var use = ChoiceUse()
            use.things = lib.items.filter { normName($0.container) == k }.count
            use.templates = lib.templates.filter { t in
                normName(t.defaultContainer) == k || lib.memberships.contains { $0.templateId == t.id && normName($0.container) == k }
            }.count
            use.trips = lib.trips.filter { t in
                t.entries.contains { e in
                    [e.container, e.ovContainer ?? "", e.tplContainer ?? "", e.defContainer ?? ""].contains { normName($0) == k }
                }
            }.count
            return use
        default:
            return lib.usesOf(kind)[normName(key)] ?? ChoiceUse()
        }
    }

    /// Why entry `key` cannot be taken away, in his words — nil when it can. `pageSays`:
    /// the page's own choice is this entry (it counts as one thing). A bag goes from here
    /// only when its page would let it go without a question: nothing packed in it, on no
    /// trip, and on none of his templates as something he packs; otherwise its page asks.
    public func choiceRemoveProblem(_ kind: String, key: String, label: String, bag: String = "",
                                    except: String? = nil, pageSays: Bool = false) -> String? {
        if let fixed = choiceFixed(kind, key) { return fixed }
        var use = choiceUse(kind, key: key, bag: bag, except: except)
        if pageSays { use.things += 1 }
        if kind == "bags" {
            if use.inUse {
                return use.refusal(label).replacingOccurrences(of: ", so it stays.", with: ". Its page asks where they go instead.")
            }
            if let id = bags().first(where: { normName($0.name) == normName(key) })?.id {
                let lists = listsHoldingBag(id: id)
                if !lists.isEmpty {
                    return "\(label) is also on your \(lists.joined(separator: ", ")) template\(lists.count == 1 ? "" : "s"), as something you pack. Its page asks what happens to it there."
                }
            }
            return nil
        }
        return use.inUse ? use.refusal(label) : nil
    }

    /// A new entry at the end of a list — the way Your choices, Your bags and a bag's
    /// pockets add one. Answers its key (its name, or a new id), or nil when refused: blank,
    /// one the list already has, or (a bag) one that cannot be made.
    @discardableResult
    public mutating func addChoice(_ kind: String, _ name: String, bag: String = "") -> String? {
        let clean = jsTrim(name)
        guard !clean.isEmpty else { return nil }
        if kind != "bags", kind != "pockets", existingChoice(kind, clean) != nil { return nil }
        switch kind {
        case "places": setNames("places", storagePlaces() + [clean]); return clean
        case "owners": setNames("owners", owners() + [clean]); return clean
        case "categories":
            guard !categories().contains(where: { Library.choiceKey($0) == Library.choiceKey(clean) }) else { return nil }
            setCategories(categories() + [clean]); return clean
        case "people":
            setPeople(people() + [newPerson(name: clean, color: PERSON_COLORS[people().count % PERSON_COLORS.count])])
            return clean
        case "conditions":
            let made = newCondition(clean, conditions().map(\.id))
            setConditions(conditions() + [made])
            return made.id
        case "phases":
            // Its colour from the app's own cover colours (`newStep`).
            let made = newStep(named: clean)
            setTimeline(timeline() + [made])
            return made.id
        case "bags": return addBag(name: clean).map { jsTrim($0.name) }
        case "pockets":
            guard let id = bagRecord(named: bag)?.id, addPocket(bagId: id, name: clean) else { return nil }
            return clean
        default: return nil
        }
    }

    /// Takes an entry away — refused, with the reason, while anything uses it
    /// (`choiceRemoveProblem`). nil = done. A bag goes as its page lets an unused one go.
    @discardableResult
    public mutating func removeChoice(_ kind: String, key: String, bag: String = "") -> String? {
        let label = choiceRows(kind, bag: bag).first { $0.key == key }?.label ?? key
        if let problem = choiceRemoveProblem(kind, key: key, label: label, bag: bag) { return problem }
        switch kind {
        case "places": setNames("places", storagePlaces().filter { $0 != key })
        case "owners": setNames("owners", owners().filter { $0 != key })
        case "categories": setCategories(categories().filter { $0 != key })
        case "people": setPeople(people().filter { $0.name != key })
        case "conditions": setConditions(conditions().filter { $0.id != key })
        case "phases": setTimeline(timeline().filter { $0.id != key })
        case "bags":
            guard let id = bags().first(where: { normName($0.name) == normName(key) })?.id else { return nil }
            deleteBag(id: id, moveTo: "")
        case "pockets":
            guard let id = bagRecord(named: bag)?.id else { return nil }
            removePocket(bagId: id, name: key)
        default: break
        }
        return nil
    }

    /// One entry renamed through its list's own rename. False when refused.
    private mutating func renameOne(_ e: ChoiceEdits, _ key: String, _ name: String) -> Bool {
        switch e.kind {
        case "bags":
            guard let id = bags().first(where: { normName($0.name) == normName(key) })?.id else { return false }
            return renameThing(id: id, to: name)
        case "pockets":
            guard let id = bagRecord(named: e.bag)?.id else { return false }
            return renamePocket(bagId: id, from: key, to: name)
        default:
            return renameChoice(e.kind, key: key, to: name) == nil
        }
    }

    /// One entry one place up (−1) or down (1) through its list's own move.
    private mutating func moveOne(_ e: ChoiceEdits, _ key: String, by step: Int) -> Bool {
        switch e.kind {
        case "bags": return moveBag(named: key, by: step)
        case "pockets":
            guard let id = bagRecord(named: e.bag)?.id, let at = pockets(bagId: id).firstIndex(of: key) else { return false }
            return movePocket(bagId: id, from: at, to: at + step)
        default:
            return moveChoice(e.kind, key: key, by: step)
        }
    }

    /// A bag one place up or down on Your bags — Arrange's own `moveRow`, among the bags
    /// under the same heading (a bag never jumps to another heading from a drop-down).
    @discardableResult
    public mutating func moveBag(named name: String, by step: Int) -> Bool {
        guard let list = bagList, step == 1 || step == -1 else { return false }
        let order = choiceRows("bags").map(\.key)
        guard let at = order.firstIndex(where: { normName($0) == normName(name) }), order.indices.contains(at + step) else { return false }
        func row(_ bagName: String) -> Membership? {
            guard let id = bags().first(where: { normName($0.name) == normName(bagName) })?.id else { return nil }
            return memberships.first { $0.templateId == list.id && $0.itemId == id }
        }
        // Up: this one before the one above. Down: the one below before this one.
        let (moving, before) = step < 0 ? (order[at], order[at - 1]) : (order[at + 1], order[at])
        guard let m = row(moving), let b = row(before) else { return false }
        let heading = arrangedSection(list.id, m)
        guard heading == arrangedSection(list.id, b) else { return false }
        return moveRow(templateId: list.id, memId: m.id, section: heading, before: b.id)
    }

    /// The heading a row sits under as the page shows it ("" for none or an unknown one).
    private func arrangedSection(_ templateId: String, _ m: Membership) -> String {
        arrangedRows(templateId: templateId).first { $0.rows.contains(m.id) }?.sectionId ?? ""
    }

    /// Writes a page's edits to one list — everything but the removals: the names first
    /// (two that swap names both get theirs — each is parked under a name nobody has on
    /// the way), then the added, then the order. Answers, for the page's own choice, where
    /// each key went: a renamed entry's old key → its new key (its new name; an id stays),
    /// an added one's `addedKey` → the key it was made under.
    ///
    /// The removals come after the page's thing is written (`applyChoiceRemovals`): until
    /// then the thing may still say the entry it is moving away from.
    @discardableResult
    public mutating func applyChoiceEdits(_ e: ChoiceEdits) -> [String: String] {
        var map: [String: String] = [:]
        let byName = !["conditions", "phases"].contains(e.kind)
        let stored = Dictionary(choiceRows(e.kind, bag: e.bag).map { ($0.key, $0.label) }, uniquingKeysWith: { a, _ in a })
        var waiting = e.names.filter { stored[$0.key] != nil && !jsTrim($0.value).isEmpty && jsTrim($0.value) != stored[$0.key] }
        func took(_ key: String, _ name: String) {
            if byName { map[key] = jsTrim(name) }
            waiting[key] = nil
        }
        var moved = true
        while !waiting.isEmpty && moved {
            moved = false
            for (key, name) in waiting.sorted(by: { $0.key < $1.key }) where renameOne(e, key, name) {
                took(key, name)
                moved = true
            }
        }
        if !waiting.isEmpty {
            // A swap (A → B while B → A): each to a name of its own first, then to its new one.
            var parked: [String: String] = [:]
            for key in waiting.keys.sorted() {
                let park = "\u{2063}\(key)\u{2063}"
                if renameOne(e, key, park) { parked[key] = byName ? park : key }
            }
            for (key, name) in waiting.sorted(by: { $0.key < $1.key }) {
                if let at = parked[key], renameOne(e, at, name) { took(key, name) }
            }
        }
        for name in e.added {
            if let made = addChoice(e.kind, name, bag: e.bag) { map[ChoiceEdits.addedKey(name)] = made }
            else if let have = choiceRows(e.kind, bag: e.bag).first(where: { Library.choiceKey($0.label) == Library.choiceKey(name) }) {
                map[ChoiceEdits.addedKey(name)] = have.key       // made meanwhile (the other device): that one
            }
        }
        if let order = e.order {
            // Each in turn moved up to its place, by the list's own one-step move.
            let wanted = order.map { map[$0] ?? $0 }
            for (n, key) in wanted.enumerated() {
                var guardSteps = 0
                while let at = choiceRows(e.kind, bag: e.bag).firstIndex(where: { $0.key == key }), at > n, guardSteps < 500 {
                    guardSteps += 1
                    if !moveOne(e, key, by: -1) { break }
                }
            }
        }
        return map
    }

    /// The page's removals, after its thing is written. One still in use by then (the
    /// other device) stays.
    public mutating func applyChoiceRemovals(_ e: ChoiceEdits, renamed map: [String: String] = [:]) {
        for key in e.removed.sorted() {
            let now = map[key] ?? key
            if ChoiceEdits.isAdded(key) { continue }
            _ = removeChoice(e.kind, key: now, bag: e.bag)
        }
    }

    /// The page's own value after its list's edits were written: a renamed entry's new
    /// key, an added one's made key — matched as the list matches names.
    public static func choiceValue(_ value: String, after map: [String: String]) -> String {
        if let hit = map[value] { return hit }
        if let hit = map.first(where: { !ChoiceEdits.isAdded($0.key) && !value.isEmpty && normName($0.key) == normName(value) }) { return hit.value }
        return value
    }
}
