import Foundation
import PackingCore

// "Before you start" (spec 07 part 19) — his words of 14 Oct 2026, from his own packing
// walk-through: "Think if there is anything I need to buy or prepare well in advance." His yes
// the same day: ONE place, on a trip not yet being packed, for everything to buy or get ready
// ahead — until then it stood in three: To do → To buy, the reminders on his templates, and a
// thing's own Valid until and battery. Three parts, each only when it has something:
//   1. To buy — the trip's things that are on To buy, need replacing, run out before he is home
//      (Before you go's date rule), or were used up the last time they went;
//   2. To prepare — the trip's reminders and Preparations lines that fall due before the day he
//      leaves, and the To dos written on the trip;
//   3. To charge — the things with a battery not charged yet: the count and the names (charging
//      is ticked in Before you go, from the day before).
// It shows at the Plan step and at Pack until the first thing is packed. It stores nothing.

/// What a trip's Before you start holds.
public struct BeforeYouStart: Equatable, Sendable {
    /// One thing to buy, and why.
    public struct Buy: Equatable, Sendable {
        /// Why a thing is to buy — said in this order.
        public enum Why: Equatable, Sendable {
            /// An open line of To buy is for it.
            case onToBuy
            /// Its condition is one that replaces.
            case needsReplacing
            /// Before you go's date rule: out of date, running out before he is home, a document short of six months.
            case date(DateFlag)
            /// Used up on the last trip it went on (that trip's name), and not bought since.
            case usedUp(String)
        }
        /// The row's id: the trip line's — "<line>|<thing>" for a thing inside a kit.
        public var id: String
        /// The thing's name — "Lighter, in the Camp pouch" inside a kit.
        public var name: String
        /// The thing to open (nil: a line typed on the trip only).
        public var thingId: String?
        public var why: [Why]

        /// Will one of the reasons stop him? Needs replacing, or a red date.
        public var red: Bool {
            why.contains { w in
                if case .needsReplacing = w { return true }
                if case .date(let f) = w { return f.isRed }
                return false
            }
        }

        /// Wants a look: a document short of six months, or used up last time.
        public var orange: Bool {
            !red && why.contains { w in
                if case .usedUp = w { return true }
                if case .date = w { return true }
                return false
            }
        }
    }

    /// One thing to get ready: a trip line to DO.
    public struct Prepare: Equatable, Sendable {
        /// The trip's line (a reminder, a Preparations line, a To do written on the trip).
        public var line: Item
        /// The day it falls due, "YYYY-MM-DD" — "" on a trip without dates, and for a To do written on the trip.
        public var due: String
        /// A To do written on the trip (due at once).
        public var tripTodo: Bool
        /// The template a reminder comes from (what its arrow opens), when it is still there.
        public var templateId: String?
        /// The thing behind a Preparations line (what its arrow opens), when it is still there.
        public var thingId: String?
    }

    public var buy: [Buy]
    public var prepare: [Prepare]
    /// The things to charge not charged yet.
    public var charge: [ChargeRow]

    public init(buy: [Buy] = [], prepare: [Prepare] = [], charge: [ChargeRow] = []) {
        self.buy = buy; self.prepare = prepare; self.charge = charge
    }

    /// Nothing in any part: no door, no line on Home.
    public var isEmpty: Bool { buy.isEmpty && prepare.isEmpty && charge.isEmpty }

    /// The door's words: "2 to buy · 3 to prepare · 4 to charge", parts with nothing left out.
    public var words: String {
        var parts: [String] = []
        if !buy.isEmpty { parts.append("\(buy.count) to buy") }
        if !prepare.isEmpty { parts.append("\(prepare.count) to prepare") }
        if !charge.isEmpty { parts.append("\(charge.count) to charge") }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// Home's line: "Before you start: 2 to buy, 3 to prepare" — To charge left out (that is the
    /// day before's work); "" when there is nothing to buy or prepare.
    public var homeWords: String {
        var parts: [String] = []
        if !buy.isEmpty { parts.append("\(buy.count) to buy") }
        if !prepare.isEmpty { parts.append("\(prepare.count) to prepare") }
        return parts.isEmpty ? "" : "Before you start: " + parts.joined(separator: ", ")
    }
}

extension Library {
    // MARK: - When

    /// Is a line a thing to DO rather than to pack? A reminder (a To do written on the trip is
    /// one), or a line of a step of things to do (`Phase.task` — the factory Preparations).
    public static func isToDo(_ line: Item) -> Bool {
        isReminder(line) || (phase(line.phase)?.task ?? false)
    }

    /// Has the packing begun? A line ticked that is a thing to pack — not a thing to do
    /// (`isToDo`), not set aside — or something ticked inside a kit. A charge tick is no packing.
    public static func hasStartedPacking(_ trip: TripEvent) -> Bool {
        trip.entries.contains { line in
            guard !isSetAside(line), !isToDo(line) else { return false }
            return line.checked || !kitIds(line.extra[KIT_TICKED_KEY]).isEmpty
        }
    }

    /// Is it Before you start's time? The trip at Plan or Pack (`loopStep`, with `time` "HH:mm":
    /// not reviewed, not over, not set off, nothing bought on site) and nothing packed yet.
    public func beforeStartTime(tripId: String, today: String, time: String = END_OF_DAY) -> Bool {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return false }
        let step = loopStep(tripId: tripId, today: today, time: time)
        return (step == .plan || step == .pack) && !Library.hasStartedPacking(trip)
    }

    /// The trip's Before you start today — empty outside its time (`beforeStartTime`).
    public func beforeYouStart(tripId: String, today: String, time: String = END_OF_DAY) -> BeforeYouStart {
        guard beforeStartTime(tripId: tripId, today: today, time: time) else { return BeforeYouStart() }
        return BeforeYouStart(buy: toBuyBeforeStart(tripId: tripId, today: today),
                              prepare: toPrepare(tripId: tripId, today: today),
                              charge: toCharge(tripId: tripId).filter { !$0.charged })
    }

    // MARK: - To buy

    /// The trip's things to buy before it, in its order, a thing once: each line not set aside and
    /// not a reminder (its thing as it is now), and each thing inside a kit on it (not taken out),
    /// for any of: an open To buy line for it; a condition that replaces; Before you go's date rule;
    /// used up the last time it went and not bought since. Whatever the trip's step.
    public func toBuyBeforeStart(tripId: String, today: String) -> [BeforeYouStart.Buy] {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return [] }
        let kits = kitIndex()
        // Before you go's date flags, by the line they are about (inside a kit: "<line>|<thing>").
        var dated: [String: DateFlag] = [:]
        for f in dateCheck(tripId: tripId, todayISO: today) where dated[f.line.id] == nil { dated[f.line.id] = f }
        let openBuys = actions.filter { $0.kind == "shopping" && !$0.done }
        let usedUp = usedUpLastTime(before: trip, today: today)
        var seen = Set<String>()
        var out: [BeforeYouStart.Buy] = []
        for line in trip.entries where !isSetAside(line) && !Library.isReminder(line) {
            // The line itself, then what is inside its kit.
            var rows: [(id: String, name: String, thing: Item?)] = []
            let src = line.sourceItemId.flatMap { $0.isEmpty ? nil : $0 }
            let own = src.flatMap { s in items.first { $0.id == s } }
            rows.append((line.id, own.map { jsTrim($0.name).isEmpty ? line.name : $0.name } ?? line.name, own))
            for c in insideLines(line, index: kits) {
                rows.append((c.id, c.name, c.sourceItemId.flatMap { s in items.first { $0.id == s } }))
            }
            for row in rows {
                let key = row.thing?.id ?? "line:\(row.id)"
                guard seen.insert(key).inserted else { continue }
                // The thing as it is now — or, typed on the trip only, the line itself.
                let now = row.thing ?? line
                var why: [BeforeYouStart.Buy.Why] = []
                let name = normName(now.name)
                if openBuys.contains(where: { a in
                    if let t = row.thing, a.itemId == t.id { return true }
                    return a.itemId.isEmpty && !name.isEmpty && normName(a.text) == name
                }) { why.append(.onToBuy) }
                if conditionReplaces(now.condition) { why.append(.needsReplacing) }
                if let f = dated[row.id] { why.append(.date(f)) }
                if let t = row.thing, let last = usedUp[t.id] {
                    why.append(.usedUp(last.name))
                }
                guard !why.isEmpty else { continue }
                out.append(BeforeYouStart.Buy(id: row.id, name: row.name, thingId: row.thing?.id, why: why))
            }
        }
        return out
    }

    /// Each thing's LAST trip before `trip` — by start date, before `trip`'s (or, when it has none,
    /// on or before today); a trip on which its line went (ticked and not set aside, or used up) —
    /// when it was USED UP there and no To buy line for it was ticked bought since that trip began
    /// (`doneAt` on or after its start date). Things never used up, gone again since and not used
    /// up, or bought since are not in it. One pass over the trips and To buy for all the things.
    func usedUpLastTime(before trip: TripEvent, today: String) -> [String: TripEvent] {
        let limit = isYMD(trip.startDate) ? trip.startDate : Library.ymd(today, plusDays: 1)
        let earlier = trips.filter { t in t.id != trip.id && isYMD(t.startDate) && jsStringLess(t.startDate, limit) }
            .stableSorted(by: { a, b in jsStringLess(a.startDate, b.startDate) })
        // Thing → (its last trip, used up there); a later trip writes over an earlier one.
        var last: [String: (trip: TripEvent, usedUp: Bool)] = [:]
        for t in earlier {
            var here: [String: Bool] = [:]
            for l in t.entries {
                guard let s = l.sourceItemId, !s.isEmpty else { continue }
                let used = Library.isUsedUp(l)
                guard (l.checked && !isSetAside(l)) || used else { continue }
                here[s] = (here[s] ?? false) || used
            }
            for (s, used) in here { last[s] = (t, used) }
        }
        // Thing → the latest day a To buy line for it was ticked bought.
        var bought: [String: String] = [:]
        for a in actions where a.kind == "shopping" && a.done && !a.itemId.isEmpty {
            let day = String(a.doneAt.prefix(10))
            if jsStringLess(bought[a.itemId] ?? "", day) { bought[a.itemId] = day }
        }
        var out: [String: TripEvent] = [:]
        for (thing, l) in last where l.usedUp {
            if let day = bought[thing], !jsStringLess(day, l.trip.startDate) { continue }
            out[thing] = l.trip
        }
        return out
    }

    // MARK: - To prepare

    /// The trip's things to DO before the day he leaves: its lines not ticked and not set aside that
    /// are a reminder or a line of a `task` step, whose When falls due before the start (lead days 1
    /// or more) — by the day it falls due, then the trip's order — and then every To do written on
    /// the trip, in the order written. Each with the day it falls due ("" without dates), and what
    /// its arrow opens: a reminder's template, a Preparations line's thing.
    public func toPrepare(tripId: String, today: String) -> [BeforeYouStart.Prepare] {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return [] }
        func open(_ l: Item) -> Bool { Library.isToDo(l) && !l.checked && !isSetAside(l) }
        let from = lineTemplates(tripId: tripId)
        let dated = isYMD(trip.startDate)
        func row(_ l: Item, due: String, todo: Bool) -> BeforeYouStart.Prepare {
            let thing = Library.isReminder(l) ? nil : l.sourceItemId.flatMap { s in items.contains { $0.id == s } ? s : nil }
            let template = Library.isReminder(l) && !todo ? from[l.id]?.first?.id : nil
            return BeforeYouStart.Prepare(line: l, due: due, tripTodo: todo, templateId: template, thingId: thing)
        }
        var out: [BeforeYouStart.Prepare] = []
        // Most lead days first; the same lead days in the timeline's order.
        let ahead = PHASES.enumerated().filter { $0.element.leadDays >= 1 }.sorted { a, b in
            a.element.leadDays != b.element.leadDays ? a.element.leadDays > b.element.leadDays : a.offset < b.offset
        }.map(\.element)
        for phase in ahead {
            let due = dated ? Library.ymd(trip.startDate, plusDays: -phase.leadDays) : ""
            out += trip.entries.filter { open($0) && !Library.isTripTodo($0) && $0.phase == phase.id }
                .map { row($0, due: due, todo: false) }
        }
        return out + trip.entries.filter { open($0) && Library.isTripTodo($0) }.map { row($0, due: "", todo: true) }
    }
}
