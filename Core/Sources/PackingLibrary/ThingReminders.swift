import Foundation
import PackingCore

// Reminders on things (0.101, spec 07 part 21 — his yes to the picture, 26 Oct 2026: "build it").
//
// A · "Remember with it": short reminders on a THING, each with a When — "Camera: Empty the SD
//     card", a week ahead. Only on trips where the thing is on the list; at its When it stands in
//     Before you go's To do with the template reminders, and under the thing's line once the thing
//     is ticked ("Before it goes: …"). ONE tick per trip, kept on the thing's line.
// B · "Goes with": other things that belong to it. When the thing is on a trip, each of them is on
//     that trip too, as its own ordinary line in its own bag, place and When, marked "with Camera".
//
// Nothing new is stored but keys: the reminders and the companions ride in the thing's own record
// (`extra`), a trip's ticks and "with" marks on the trip's lines — the web app's model reads none
// of them (they ride through `coerceItem` as unknown keys), so the parity check stays as it was.

/// A thing's reminders: `[{"id", "text", "when"}]`, his order (item `extra`).
public let THING_REMINDERS_KEY = "remindWith"
/// The things that go with a thing: `[item id]`, his order (item `extra`).
public let GOES_WITH_KEY = "goesWith"
/// On a trip line: the thing reminders ticked on this trip, `[reminder id]` / absent.
public let REMINDERS_DONE_KEY = "remindDone"
/// On a trip line: the things that brought it along ("with Camera"), `[item id]` / absent.
public let WITH_THINGS_KEY = "withThings"

/// One reminder on a thing.
public struct ThingReminder: Equatable, Hashable, Sendable, Identifiable {
    public var id: String
    public var text: String
    /// A "When" step id (his timeline); one this device does not know is kept.
    public var when: String

    public init(id: String = PackingEnv.makeId(), text: String, when: String) {
        self.id = id; self.text = text; self.when = when
    }

    public var json: JSONValue { .object(["id": .string(id), "text": .string(text), "when": .string(when)]) }

    /// Read leniently: an entry without an id or words is no reminder.
    public init?(json: JSONValue) {
        guard let id = json["id"]?.stringValue, !id.isEmpty,
              let text = json["text"]?.stringValue, !jsTrim(text).isEmpty else { return nil }
        self.id = id
        self.text = text
        self.when = json["when"]?.stringValue ?? ""
    }
}

/// A thing's reminder on one trip: the line that carries it (the thing's first line there that is
/// not set aside — or its kit's), and whether it is ticked on this trip.
public struct ThingReminderOnTrip: Equatable, Sendable, Identifiable {
    public var lineId: String
    public var thingId: String
    public var thingName: String
    public var reminder: ThingReminder
    public var done: Bool

    public var id: String { "\(lineId)|\(reminder.id)" }
    /// "Camera: Empty the SD card" — the thing's name, then the words.
    public var name: String { "\(thingName): \(reminder.text)" }
}

extension Library {
    // MARK: - On the thing

    /// The thing's reminders, his order (each id once).
    public static func thingReminders(_ thing: Item) -> [ThingReminder] {
        var seen = Set<String>()
        return (thing.extra[THING_REMINDERS_KEY]?.arrayValue ?? []).compactMap(ThingReminder.init(json:))
            .filter { seen.insert($0.id).inserted }
    }

    /// Write a thing's reminders; none = no key.
    public static func setThingReminders(_ thing: inout Item, _ list: [ThingReminder]) {
        thing.extra[THING_REMINDERS_KEY] = list.isEmpty ? JSONValue?.none : .array(list.map(\.json))
    }

    /// The ids of the things that go with it, his order (each once, never itself).
    public static func goesWith(_ thing: Item) -> [String] {
        var seen: Set<String> = [thing.id]
        return (thing.extra[GOES_WITH_KEY]?.arrayValue ?? []).compactMap(\.stringValue)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public static func setGoesWith(_ thing: inout Item, _ ids: [String]) {
        thing.extra[GOES_WITH_KEY] = ids.isEmpty ? JSONValue?.none : JSONValue(ids)
    }

    /// What is wrong with a reminder's words on a thing that has `others` already — nil when they will do.
    public static func thingReminderProblem(_ text: String, others: [ThingReminder], except id: String = "") -> String? {
        let clean = jsTrim(text)
        if clean.isEmpty { return "Type the reminder first." }
        if others.contains(where: { $0.id != id && normName($0.text) == normName(clean) }) { return "This thing has that reminder already." }
        return nil
    }

    /// The When a new reminder on a thing starts with: the last one's, else the day before (the
    /// first step one day ahead), else the step a new thing gets — as on a template.
    public static func whenForNewThingReminder(_ list: [ThingReminder]) -> String {
        if let last = list.last, !last.when.isEmpty { return last.when }
        return PHASES.first { $0.leadDays == 1 }?.id ?? defaultPhaseId()
    }

    /// The things that can go with this one (`thingId`): his things, not itself, not a bag, not a
    /// reminder, not one chosen already — A–Z.
    public func goesWithCandidates(thingId: String, chosen: [String]) -> [Item] {
        let bagIds = Set(bags().compactMap { $0.itemId ?? $0.id })
        let taken = Set(chosen).union([thingId])
        return ownThings()
            .filter { !taken.contains($0.id) && !bagIds.contains($0.id) && !Library.isReminder($0) && !jsTrim($0.name).isEmpty }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
    }

    /// The things that go with this one, as they are now (a thing deleted since is left out).
    public func companions(of thingId: String) -> [Item] {
        guard let thing = items.first(where: { $0.id == thingId }) else { return [] }
        var byId: [String: Item] = [:]
        for i in items where byId[i.id] == nil { byId[i.id] = i }
        return Library.goesWith(thing).compactMap { byId[$0] }
    }

    /// The thing page's Save (0.101): its reminders and its companions as the page has them, put
    /// onto the thing AS IT IS NOW by the list rule of a page's Save (0.95, `mergeList`) — what the
    /// other device added meanwhile stays, what the page removed goes, a reminder both kept takes
    /// what the page changed on it (its words, its When). Only a list the page changed is written.
    @discardableResult
    public mutating func saveThingRemembers(id: String, openedReminders: [ThingReminder], reminders: [ThingReminder],
                                            openedWith: [String], with: [String]) -> Bool {
        guard openedReminders != reminders || openedWith != with,
              let n = items.firstIndex(where: { $0.id == id }) else { return false }
        if openedReminders != reminders {
            let merged = Library.mergeList(Library.thingReminders(items[n]), was: openedReminders, now: reminders,
                                           id: \.id) { here, was, page in
                var out = here
                if was.text != page.text { out.text = page.text }
                if was.when != page.when { out.when = page.when }
                return out
            }
            Library.setThingReminders(&items[n], merged)
        }
        if openedWith != with {
            let merged = Library.mergeList(Library.goesWith(items[n]), was: openedWith, now: with, id: { $0 }) { _, _, page in page }
            Library.setGoesWith(&items[n], merged.filter { $0 != id })
        }
        return true
    }

    // MARK: - Which things a trip line carries

    /// The thing behind a trip line: the thing it was built from — or, for a line he typed on the
    /// trip, the thing of that name (`names`: `normName` → id, his things).
    func lineThing(_ line: Item, byId: [String: Item], names: [String: String]) -> String? {
        if let sid = line.sourceItemId, !sid.isEmpty, byId[sid] != nil { return sid }
        if line.custom { return names[normName(line.name)] }
        return nil
    }

    /// The things a line carries: its own thing, and — a kit — what is inside it now and not taken out.
    func thingsOn(_ line: Item, byId: [String: Item], names: [String: String], index: KitIndex) -> [String] {
        guard let t = lineThing(line, byId: byId, names: names) else { return [] }
        let inside = (index.contents[t] ?? []).filter { !$0.takenOut }.map(\.thing.id)
        return [t] + inside
    }

    private func thingNames() -> [String: String] {
        var names: [String: String] = [:]
        for i in ownThings() where !Library.isReminder(i) {
            let k = normName(i.name)
            if !k.isEmpty, names[k] == nil { names[k] = i.id }
        }
        return names
    }

    // MARK: - A · the reminders on a trip

    /// Every thing reminder on a trip, by the line that carries it, in the trip's order — the line
    /// of the thing (its first one not set aside), or its kit's. None on a reviewed trip, and none
    /// for a thing set aside on it.
    public func thingReminders(tripId: String) -> [String: [ThingReminderOnTrip]] {
        guard items.contains(where: { $0.extra[THING_REMINDERS_KEY] != nil }),
              let trip = trips.first(where: { $0.id == tripId }), !Library.isReviewed(trip) else { return [:] }
        var byId: [String: Item] = [:]
        for i in items where byId[i.id] == nil { byId[i.id] = i }
        let names = thingNames(), index = kitIndex()
        var out: [String: [ThingReminderOnTrip]] = [:]
        var placed = Set<String>()
        for line in trip.entries where !isSetAside(line) && !Library.isReminder(line) {
            let done = Set(Library.kitIds(line.extra[REMINDERS_DONE_KEY]))
            for t in thingsOn(line, byId: byId, names: names, index: index) where !placed.contains(t) {
                guard let thing = byId[t] else { continue }
                let list = Library.thingReminders(thing)
                guard !list.isEmpty else { continue }
                placed.insert(t)
                out[line.id, default: []] += list.map {
                    ThingReminderOnTrip(lineId: line.id, thingId: t, thingName: thing.name, reminder: $0, done: done.contains($0.id))
                }
            }
        }
        return out
    }

    /// The thing reminders due on a trip and not ticked: their step's day — the trip's start less
    /// its lead days — is today or past (the template reminders' rule, `dueReminders`). In the
    /// timeline's order, then the trip's. None on a trip without a start date; a When this device
    /// does not know is never due.
    public func dueThingReminders(tripId: String, today: String) -> [ThingReminderOnTrip] {
        guard let trip = trips.first(where: { $0.id == tripId }), isYMD(trip.startDate) else { return [] }
        let all = thingReminders(tripId: tripId)
        guard !all.isEmpty else { return [] }
        let open = trip.entries.flatMap { all[$0.id] ?? [] }.filter { !$0.done }
        var out: [ThingReminderOnTrip] = []
        for phase in PHASES {
            let day = Library.ymd(trip.startDate, plusDays: -phase.leadDays)
            guard !jsStringLess(today, day) else { continue }
            out += open.filter { $0.reminder.when == phase.id }
        }
        return out
    }

    /// Tick (or untick) a thing reminder for this trip — under the thing's line or in Before you
    /// go, the same tick: kept on the line that carries it.
    @discardableResult
    public mutating func setThingReminderDone(_ on: Bool, tripId: String, lineId: String, reminderId: String) -> Bool {
        guard let t = trips.firstIndex(where: { $0.id == tripId }),
              let e = trips[t].entries.firstIndex(where: { $0.id == lineId }) else { return false }
        var done = Library.kitIds(trips[t].entries[e].extra[REMINDERS_DONE_KEY])
        if on { if !done.contains(reminderId) { done.append(reminderId) } } else { done.removeAll { $0 == reminderId } }
        trips[t].entries[e].extra[REMINDERS_DONE_KEY] = done.isEmpty ? JSONValue?.none : JSONValue(done)
        return true
    }

    // MARK: - B · the things that go with it

    /// `lines` with the things that go with theirs added, each as its own line in its own bag,
    /// place, When and section, marked with the things that brought it (`WITH_THINGS_KEY`). A thing
    /// already on the trip — from a template, typed by him (`custom`), or brought by another thing —
    /// is not added twice; one brought by two things names both. One level: what goes with a thing
    /// that came along is not followed (so no chain and no loop). A thing inside a kit is never a
    /// line of its own: its kit comes instead. A thing inside a kit on the trip is on the trip, and
    /// what goes with it comes along too. Lines set aside bring nothing.
    public func withCompanions(_ lines: [Item], typed: [Item] = []) -> [Item] {
        guard items.contains(where: { $0.extra[GOES_WITH_KEY] != nil }) else { return lines }
        var byId: [String: Item] = [:]
        for i in items where byId[i.id] == nil { byId[i.id] = i }
        let names = thingNames(), index = kitIndex()
        let bagIds = Set(bags().compactMap { $0.itemId ?? $0.id })
        let bringers = (lines + typed).filter { !isSetAside($0) }
        // On the trip already: any line, one set aside too (he said "not this time" to it).
        var present = Set<String>()
        for l in lines + typed { present.formUnion(thingsOn(l, byId: byId, names: names, index: index)) }
        var out = lines
        var added: [String: Int] = [:]
        for line in bringers {
            for t in thingsOn(line, byId: byId, names: names, index: index) {
                guard let thing = byId[t] else { continue }
                for c in Library.goesWith(thing) {
                    let target = index.kitOf(c) ?? c
                    guard target != t, let what = byId[target], !bagIds.contains(target), !Library.isReminder(what),
                          !jsTrim(what.name).isEmpty, !what.retired else { continue }
                    if let k = added[target] {
                        var with = Library.kitIds(out[k].extra[WITH_THINGS_KEY])
                        if !with.contains(t) { with.append(t); out[k].extra[WITH_THINGS_KEY] = JSONValue(with) }
                        continue
                    }
                    guard !present.contains(target) else { continue }
                    var l = entryFromItem(resolveItemAlone(what), nil)
                    l.section = companionSection(target)
                    l.extra[WITH_THINGS_KEY] = JSONValue([t])
                    out.append(l)
                    added[target] = out.count - 1
                    present.insert(target)
                    present.formUnion((index.contents[target] ?? []).map(\.thing.id))
                }
            }
        }
        return out
    }

    /// A thing that came along: its section as its first template that gives it one names it.
    private func companionSection(_ thingId: String) -> String {
        for m in memberships where m.itemId == thingId && !m.section.isEmpty {
            if let t = templates.first(where: { $0.id == m.templateId }), let s = t.sections.first(where: { $0.id == m.section }) {
                return s.name
            }
        }
        return ""
    }

    /// The things that brought a line along ("with Camera"), as they are named now.
    public func withNames(_ line: Item) -> [String] {
        let ids = Library.kitIds(line.extra[WITH_THINGS_KEY])
        guard !ids.isEmpty else { return [] }
        return ids.compactMap { id in items.first { $0.id == id }?.name }
    }

    /// After a line was added to a trip by hand ("Add a thing"): what goes with its thing comes too.
    /// Returns how many lines came.
    @discardableResult
    public mutating func bringCompanions(tripId: String) -> Int {
        guard let t = trips.firstIndex(where: { $0.id == tripId }) else { return 0 }
        let before = trips[t].entries.count
        trips[t].entries = withCompanions(trips[t].entries)
        return trips[t].entries.count - before
    }

    /// ⊘ "not this time" on a line: what came along ONLY with what it carries, and is not packed,
    /// is set aside with it; ↻ brings back what came along with it and was set aside. A line that
    /// is on the trip for its own sake — a template's, one he typed — never carries a "with" mark,
    /// so it is never touched.
    mutating func followAside(_ aside: Bool, trip t: Int, entry e: Int) {
        guard items.contains(where: { $0.extra[GOES_WITH_KEY] != nil }) else { return }
        var byId: [String: Item] = [:]
        for i in items where byId[i.id] == nil { byId[i.id] = i }
        let names = thingNames(), index = kitIndex()
        let carried = Set(thingsOn(trips[t].entries[e], byId: byId, names: names, index: index))
        guard !carried.isEmpty else { return }
        // What the trip still carries, lines set aside left out.
        var still = Set<String>()
        for l in trips[t].entries where !isSetAside(l) { still.formUnion(thingsOn(l, byId: byId, names: names, index: index)) }
        for k in trips[t].entries.indices where k != e {
            let with = Set(Library.kitIds(trips[t].entries[k].extra[WITH_THINGS_KEY]))
            guard !with.isDisjoint(with: carried) else { continue }
            if aside {
                guard !trips[t].entries[k].checked, !isSetAside(trips[t].entries[k]), with.isDisjoint(with: still) else { continue }
                trips[t].entries[k].skipped = true
            } else if isSetAside(trips[t].entries[k]) {
                trips[t].entries[k].skipped = false
            }
        }
    }
}
