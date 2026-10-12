import Foundation
import PackingCore

// "Only on some trips", set once on the THING (spec 07 part 14). His words, 10 Oct 2026:
// "if I have an item on five templates, I need to change this in five places. Doesn't
// seem optimal."
//
// Until 0.73 Season, Context, Transport and Food lived on each template's ROW only (the
// membership's `seasons`, `contexts`, `transports`, `catering`). Now the thing has an
// answer of its own and every row FOLLOWS it — per kind — unless the row sets its own,
// the way How many and Note follow the thing ("Blank means the same as the thing").
//
// WHERE IT IS KEPT. On the THING, in four extra keys (`onlySeasons` …), so the web app's
// model reads a plain thing and the parity check is untouched; on a ROW, its own lists as
// before plus ONE extra key, `onlyAnyHere`: the kinds for which this row comes on ANY trip
// whatever the thing says (Swim's towel, "always on Swim"). A row's kind is its own when
// its list is not empty or `onlyAnyHere` names it; otherwise it follows the thing.
//
// THE RULE THAT KEEPS STORAGE AND SCREEN IN STEP. A row never keeps an own answer equal to
// the thing's: equal IS "the same as the thing" (rule 4). `saveRow`, `saveTemplate` (for a
// changed or new row) and `setThingLimits` (for every row of the thing) fold such an answer
// back to following. So "this row has its own" and "this row says something else than the
// thing" are the same question everywhere.
//
// Effective answers are put into the resolved rows in ONE place, `Library.resolveOne`;
// everything that reads a resolved template — trip building, the rebuild, a change that
// follows to trips ahead, the template's page, Apple Health's review, a shared template,
// the backup's `lists` — reads what the row really does.

/// The four kinds of "Only on some trips", named by the membership field that holds each.
public enum TripLimit: String, CaseIterable, Sendable {
    case seasons, contexts, transports, catering

    /// The thing's own key for this kind.
    public var thingKey: String {
        switch self {
        case .seasons: return "onlySeasons"
        case .contexts: return "onlyContexts"
        case .transports: return "onlyTransports"
        case .catering: return "onlyCatering"
        }
    }

    /// The app's own words, as stored, in the app's order.
    public var vocabulary: [String] {
        switch self {
        case .seasons: return SEASONS
        case .contexts: return CONTEXTS
        case .transports: return TRANSPORTS
        case .catering: return CATERING.map(\.id)
        }
    }

    /// The heading of its pills.
    public var title: String {
        switch self {
        case .seasons: return "Season"
        case .contexts: return "Context"
        case .transports: return "Transport"
        case .catering: return "Food"
        }
    }

    /// What no limit means, in his words: "any season".
    public var anyWords: String { "any " + (self == .catering ? "food" : title.lowercased()) }

    /// A stored word as he reads it — food in its short words ("self" → "Self-sufficient").
    public static func label(_ word: String) -> String {
        switch word {
        case "self": return "Self-sufficient"
        case "eatout": return "Eating out"
        case "mixed": return "Mix of both"
        default: return word
        }
    }

    /// "Winter", "Car, Plane" — or "any season" for none.
    public func words(_ list: [String]) -> String {
        list.isEmpty ? anyWords : list.map(TripLimit.label).joined(separator: ", ")
    }

    public func list(_ m: Membership) -> [String] {
        switch self {
        case .seasons: return m.seasons
        case .contexts: return m.contexts
        case .transports: return m.transports
        case .catering: return m.catering
        }
    }
    public func set(_ m: inout Membership, _ v: [String]) {
        switch self {
        case .seasons: m.seasons = v
        case .contexts: m.contexts = v
        case .transports: m.transports = v
        case .catering: m.catering = v
        }
    }
    public func list(_ row: Item) -> [String] {
        switch self {
        case .seasons: return row.seasons
        case .contexts: return row.contexts
        case .transports: return row.transports
        case .catering: return row.catering
        }
    }
    public func set(_ row: inout Item, _ v: [String]) {
        switch self {
        case .seasons: row.seasons = v
        case .contexts: row.contexts = v
        case .transports: row.transports = v
        case .catering: row.catering = v
        }
    }
}

/// On a template's row: the kinds for which it comes on ANY trip, whatever the thing says.
public let ONLY_ANY_HERE_KEY = "onlyAnyHere"

/// The four answers together — a thing's, or what a page holds until Save.
public struct TripLimits: Equatable, Sendable {
    public var seasons: [String] = []
    public var contexts: [String] = []
    public var transports: [String] = []
    public var catering: [String] = []
    public init(seasons: [String] = [], contexts: [String] = [], transports: [String] = [], catering: [String] = []) {
        self.seasons = seasons; self.contexts = contexts; self.transports = transports; self.catering = catering
    }
    public subscript(_ k: TripLimit) -> [String] {
        get {
            switch k {
            case .seasons: return seasons
            case .contexts: return contexts
            case .transports: return transports
            case .catering: return catering
            }
        }
        set {
            switch k {
            case .seasons: seasons = newValue
            case .contexts: contexts = newValue
            case .transports: transports = newValue
            case .catering: catering = newValue
            }
        }
    }
    public var isEmpty: Bool { TripLimit.allCases.allSatisfy { self[$0].isEmpty } }
}

extension Library {
    // MARK: - Reading

    /// The words a stored list holds: strings only, each once, blanks dropped, in its order.
    static func limitWords(_ v: JSONValue?) -> [String] {
        var seen = Set<String>()
        return (v?.arrayValue ?? []).compactMap(\.stringValue).filter { !jsTrim($0).isEmpty && seen.insert($0).inserted }
    }

    /// The thing's own answer for one kind ([] = no limit).
    public static func thingLimit(_ thing: Item, _ k: TripLimit) -> [String] { limitWords(thing.extra[k.thingKey]) }

    /// The thing's four answers.
    public static func thingLimits(_ thing: Item) -> TripLimits {
        var out = TripLimits()
        for k in TripLimit.allCases { out[k] = thingLimit(thing, k) }
        return out
    }

    /// The kinds for which this row comes on any trip, whatever the thing says.
    public static func anyHere(_ m: Membership) -> Set<TripLimit> {
        Set(limitWords(m.extra[ONLY_ANY_HERE_KEY]).compactMap(TripLimit.init(rawValue:)))
    }

    /// Does this row decide this kind itself? Its list says something, or it is its own "any".
    public static func rowOwns(_ m: Membership, _ k: TripLimit) -> Bool {
        !k.list(m).isEmpty || anyHere(m).contains(k)
    }

    /// What a trip reads for this row and kind: its own answer, else the thing's.
    public static func effectiveLimit(_ m: Membership, thing: Item, _ k: TripLimit) -> [String] {
        rowOwns(m, k) ? k.list(m) : thingLimit(thing, k)
    }

    /// The row's four effective answers.
    public static func effectiveLimits(_ m: Membership, thing: Item) -> TripLimits {
        var out = TripLimits()
        for k in TripLimit.allCases { out[k] = effectiveLimit(m, thing: thing, k) }
        return out
    }

    /// Two answers mean the same when they hold the same words, in any order.
    public static func sameLimit(_ a: [String], _ b: [String]) -> Bool { Set(a) == Set(b) }

    /// A resolved row (PackingCore's `resolveMembership` copies the membership's lists as
    /// they are) made to carry what it really does: the thing's answer where it follows.
    static func applyThingLimits(_ row: inout Item, _ m: Membership, _ thing: Item) {
        for k in TripLimit.allCases where !rowOwns(m, k) {
            let own = thingLimit(thing, k)
            if !own.isEmpty { k.set(&row, own) }
        }
    }

    // MARK: - Writing

    /// Mark or unmark this row's own "any" for one kind. The key is removed when empty.
    static func setAnyHere(_ m: inout Membership, _ k: TripLimit, _ on: Bool) {
        var now = anyHere(m)
        if on { now.insert(k) } else { now.remove(k) }
        let ordered = TripLimit.allCases.filter(now.contains).map(\.rawValue)
        m.extra[ONLY_ANY_HERE_KEY] = ordered.isEmpty ? JSONValue?.none : JSONValue(ordered)   // JSONValue takes nil as null
    }

    /// What a row stores for one kind, given the answer it shows now (rules 4 and 5):
    /// the thing's answer → follows; nothing while the thing has a limit → its own "any";
    /// anything else → its own list.
    static func storeRowLimit(_ m: inout Membership, _ k: TripLimit, shown: [String], thing: Item) {
        let own = thingLimit(thing, k)
        if sameLimit(shown, own) {
            k.set(&m, []); setAnyHere(&m, k, false)
        } else if shown.isEmpty {
            k.set(&m, []); setAnyHere(&m, k, true)
        } else {
            k.set(&m, shown); setAnyHere(&m, k, false)
        }
    }

    /// `saveTemplate`'s guard: `membershipFromResolved` (the web app's) stores a row's
    /// RESOLVED lists — with the thing's answers in them — which would cut every row off
    /// from its thing. Per kind: a row showing what it resolved to keeps exactly what it
    /// stored; a new row showing nothing or the thing's answer follows; anything else is
    /// stored by `storeRowLimit`. `before` = the place as stored, nil for a new one.
    static func keepRowLimits(_ m: inout Membership, row: Item, before: Membership?, thing: Item) {
        for k in TripLimit.allCases {
            let shown = k.list(row)
            if let b = before, sameLimit(shown, effectiveLimit(b, thing: thing, k)) {
                k.set(&m, k.list(b)); setAnyHere(&m, k, anyHere(b).contains(k))
            } else if before == nil && shown.isEmpty {
                k.set(&m, []); setAnyHere(&m, k, false)
            } else {
                storeRowLimit(&m, k, shown: shown, thing: thing)
            }
        }
    }

    /// The thing's own answers into its keys: the app's words in the app's order, then any
    /// word it does not know that was stored and is still picked; a kind with nothing is
    /// no key at all.
    static func writeThingLimits(_ thing: inout Item, _ limits: TripLimits) {
        for k in TripLimit.allCases {
            let keep = keptConditions(Set(limits[k]), k.vocabulary, thingLimit(thing, k) + limits[k])
            thing.extra[k.thingKey] = keep.isEmpty ? JSONValue?.none : JSONValue(keep)
        }
    }

    /// Set the thing's "Only on some trips" (its page's Save). Every row of it whose own
    /// answer is now the same as the thing's goes back to following it (rule 4) — the five
    /// rows he set to Winter one by one follow the thing once it says Winter. `follow`:
    /// bring the thing's open lines on trips still ahead up to date (its page leaves that to
    /// `updateThing`, which runs right after). Returns whether anything was written.
    @discardableResult
    public mutating func setThingLimits(id: String, _ limits: TripLimits, follow: Bool = true) -> Bool {
        guard let n = items.firstIndex(where: { $0.id == id }) else { return false }
        let thingBefore = items[n]
        Library.writeThingLimits(&items[n], limits)
        let thing = items[n]
        var rows = false
        for r in memberships.indices where memberships[r].itemId == id {
            var m = memberships[r]
            for k in TripLimit.allCases where Library.rowOwns(m, k)
                && Library.sameLimit(k.list(m), Library.thingLimit(thing, k)) {
                k.set(&m, []); Library.setAnyHere(&m, k, false)
            }
            if m != memberships[r] { memberships[r] = m; rows = true }
        }
        let changed = rows || items[n] != thingBefore
        if changed && follow { followThing(id: id) }
        return changed
    }

    // MARK: - Showing

    /// The templates (his, the bag list left out) where a row of this thing sets its own
    /// answer — the kinds of each, in the order of the four — measured against `against`
    /// (the thing's page passes what it holds before Save; nil = the thing as stored).
    /// `on`: only these templates (the page passes the ones lit in On these templates).
    public func ownLimits(thingId: String, against: TripLimits? = nil, on: Set<String>? = nil) -> [(template: PackList, kinds: [TripLimit])] {
        guard let thing = items.first(where: { $0.id == thingId }) else { return [] }
        let theirs = against ?? Library.thingLimits(thing)
        let shown = templatesForThings()
            .filter { on?.contains($0.id) ?? true }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
        var out: [(template: PackList, kinds: [TripLimit])] = []
        for t in shown {
            var kinds = Set<TripLimit>()
            for m in memberships where m.itemId == thingId && m.templateId == t.id {
                for k in TripLimit.allCases where Library.rowOwns(m, k) && !Library.sameLimit(k.list(m), theirs[k]) {
                    // Context counts only on a workout template; elsewhere it says nothing.
                    if k == .contexts && !contextApplies(t) { continue }
                    kinds.insert(k)
                }
            }
            if !kinds.isEmpty { out.append((t, TripLimit.allCases.filter(kinds.contains))) }
        }
        return out
    }

    /// "Set on the template instead: Hiking (Season), Swim (Season, Food)." — or "".
    public func ownLimitWords(thingId: String, against: TripLimits? = nil, on: Set<String>? = nil) -> String {
        let own = ownLimits(thingId: thingId, against: against, on: on)
        guard !own.isEmpty else { return "" }
        let parts = own.map { "\(shownName($0.template)) (\($0.kinds.map(\.title).joined(separator: ", ")))" }
        return "Set on the template instead: " + parts.joined(separator: ", ") + "."
    }

    /// Under a kind's pills on a template's row: where its answer comes from.
    /// "Same as the thing: Winter" while it follows (or "…: any season"); "Own choice on
    /// this template. The thing says: Winter." while the row has its own.
    public static func limitFromWords(_ k: TripLimit, shown: [String], thing: [String]) -> String {
        sameLimit(shown, thing)
            ? "Same as the thing: \(k.words(thing))"
            : "Own choice on this template. The thing says: \(k.words(thing))."
    }

    // MARK: - Older files

    /// A file rebuilt from its rows (the web app's, or ours from before 0.61) brings each
    /// row in with the answers it SHOWS, and the thing's keys only afterwards
    /// (`carryRowExtras`). Settled here so every row reads exactly what the file said: a
    /// row equal to its thing's answer follows it; an empty row while the thing has a
    /// limit is that row's own "any". Returns how many rows changed.
    @discardableResult
    public mutating func settleRowsOnThingsLimits() -> Int {
        var things: [String: Item] = [:]
        for i in items where things[i.id] == nil { things[i.id] = i }
        var changed = 0
        for r in memberships.indices {
            guard let thing = things[memberships[r].itemId] else { continue }
            var m = memberships[r]
            for k in TripLimit.allCases where !Library.thingLimit(thing, k).isEmpty {
                Library.storeRowLimit(&m, k, shown: k.list(m), thing: thing)
            }
            if m != memberships[r] { memberships[r] = m; changed += 1 }
        }
        return changed
    }
}
