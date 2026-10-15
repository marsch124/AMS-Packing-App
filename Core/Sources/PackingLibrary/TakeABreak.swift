import Foundation
import PackingCore

// Take a break, and messages when a trip moves on — his yes of 13 Oct 2026, from his own
// packing walk-through: "then I get tired and just want to relax… if it is the day after I
// would like a reminder or a calendar event so that I feel calm. In this state I would like
// an overview of how far I have come"; and "I would like a message from the app when the
// Phase changes". (Spec 07, part 16.)
//
// Here is only WHAT the break shows and what the messages say, and WHEN; the device puts the
// messages in its list (the app's TripMessages) and puts them right whenever the library
// changes — as it does the door checks — so a count in a message is the one at the last
// change, and a message for a trip that was deleted, reviewed or packed goes.
//
// WHERE IT IS KEPT: the break in the trip's extra keys, so it is synced (a break taken on the
// Mac reminds him on the iPhone), backed up and restored with the trip, as "I leave at" is.
// The web app's model is untouched. The switch for the messages is the device's own.

/// A trip's extra key: when he goes back to packing after a break, "2026-10-13 19:00" — this
/// device's clock, as "I leave at" is. Absent: no break waiting. One per trip: a new choice
/// replaces it, and Just pause takes it away.
public let BREAK_UNTIL_KEY = "breakUntil"
/// "This evening" is at 19:00.
public let BREAK_EVENING_AT = "19:00"
/// "Tomorrow" is at 18:00 until he picks another time.
public let BREAK_TOMORROW_AT = "18:00"
/// "This evening" is offered while 19:00 is at least this far ahead — closer, "In an hour"
/// says it.
public let BREAK_EVENING_LEAD_MINUTES = 30
/// A calendar entry for a break lasts this long.
public let BREAK_CALENDAR_MINUTES = 30
/// How the break's reminder and its calendar entry begin (0.84, his ask of 15 Oct 2026: the
/// reminder's text starts with the backpack, 🎒) — "🎒 Back to packing <trip>". The emoji is
/// his explicit wish, here and nowhere else in the app (his rule: no stock art in the app).
public let BREAK_TITLE = "\u{1F392} Back to packing"
/// Pack → On site with no time he leaves: the first day at 08:00 (never at midnight, when
/// the loop itself turns).
public let SET_OFF_MESSAGE_AT = "08:00"
/// On site → Review: the day after the last day, at 10:00.
public let REVIEW_MESSAGE_AT = "10:00"
/// At most this many "moves on" messages wait in the device's list, the soonest — an iPhone
/// keeps 64 waiting notifications per app, and the packing reminders may take 48.
public let MOVES_ON_LIMIT = 6

/// How far he has come on a trip — the Take a break sheet's overview. The counts are the
/// trip's own: `done`/`total` are its header's ("41/63", every line not set aside, its
/// reminders too — so "everything packed" is the moment the trip turns green), and each
/// group's are its heading's in the trip's sorting.
public struct BreakOverview: Equatable, Sendable {
    public struct Group: Equatable, Sendable {
        public var label: String
        /// Lines not set aside, and how many of them are not ticked yet.
        public var lines: Int
        public var left: Int
        public init(label: String, lines: Int, left: Int) { self.label = label; self.lines = lines; self.left = left }
        /// "Bike ✓", "Golf 3 left".
        public var words: String { left == 0 ? "\(label) \u{2713}" : "\(label) \(left) left" }
    }

    public var done: Int
    public var total: Int
    /// The trip's groups in its sorting; a group whose every line is set aside is not here.
    public var groups: [Group]
    /// To charge, as the trip's To charge card shows it today (both 0: no card today).
    public var charged: Int
    public var toCharge: Int
    /// The trip's reminders (spec 07 part 12), not set aside: ticked, of all.
    public var todoDone: Int
    public var todo: Int

    public var left: Int { total - done }
    /// "41 of 63 packed".
    public var packedWords: String { "\(done) of \(total) packed" }
    /// "Bike ✓ · Run ✓ · Golf 3 left".
    public var groupWords: String { groups.map(\.words).joined(separator: " \u{00B7} ") }
    /// "To charge: 2 left" / "To charge: all charged"; "" when the trip shows no To charge card.
    public var chargeWords: String {
        guard toCharge > 0 else { return "" }
        return charged == toCharge ? "To charge: all charged" : "To charge: \(toCharge - charged) left"
    }
    /// "To do: 1 left" / "To do: all done"; "" when the trip has no reminders.
    public var todoWords: String {
        guard todo > 0 else { return "" }
        return todoDone == todo ? "To do: all done" : "To do: \(todo - todoDone) left"
    }
    /// What the break's message says: "22 things left", "1 thing left"; "" = nothing left.
    public var leftWords: String { left > 0 ? "\(left) thing\(left == 1 ? "" : "s") left" : "" }
}

/// One message as it would be put in the device's list.
public struct TripMessage: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        /// Back to packing after a break.
        case breakOver = "break"
        /// Pack → On site: "Have a good trip".
        case setOff = "onsite"
        /// On site → Review: "Welcome home".
        case home = "review"
        /// The evening before the trip: "Charge tonight" (0.87, `ChargeTonight.swift`).
        case charge = "charge"
    }
    /// "break-<trip id>", "moves-onsite-<trip id>", "moves-review-<trip id>", "charge-<trip
    /// id>" — the notification's own id, so a new plan replaces the old one.
    public var id: String
    public var tripId: String
    public var kind: Kind
    /// The day, "2026-10-14", and the time, "08:00", on this device's clock.
    public var day: String
    public var time: String
    public var title: String
    public var body: String
    public var moment: String { "\(day) \(time)" }
}

extension Library {
    // MARK: - Groups as the trip shows them

    /// The lines in groups as the trip screen shows them under `sorting` — "when",
    /// "container" (Into), "stored" (From where), "category", "section" or "template":
    /// Template is the library's own grouping (`linesByTemplate`); the others the web app's
    /// `groupBy`, where sorted by Into a reminder goes in no bag — it stands under "To do"
    /// (spec 07, part 12).
    public func linesGrouped(tripId: String, sorting: String, lines: [Item]) -> [EntryGroup] {
        if sorting == "template" { return linesByTemplate(tripId: tripId, lines: lines) }
        guard sorting == "container" else { return groupBy(sorting, lines) }
        return groupBy(sorting, lines.map { line in
            guard Library.isReminder(line) else { return line }
            var l = line
            l.container = "To do"
            return l
        })
    }

    // MARK: - The overview

    /// How far he has come on a trip, its groups in `sorting` (the trip's Sorting on this
    /// device), To charge as the card shows it `today`. Nil for no such trip.
    public func breakOverview(tripId: String, sorting: String, today: String) -> BreakOverview? {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return nil }
        let p = progress(trip.entries)
        let groups: [BreakOverview.Group] = linesGrouped(tripId: tripId, sorting: sorting, lines: trip.entries).compactMap { g in
            let mine = g.entries.filter { !isSetAside($0) }
            guard !mine.isEmpty else { return nil }
            return BreakOverview.Group(label: g.label, lines: mine.count, left: mine.filter { !$0.checked }.count)
        }
        let charge = chargeCard(tripId: tripId, today: today)
        let todo = trip.entries.filter { Library.isReminder($0) && !isSetAside($0) }
        return BreakOverview(done: p.done, total: p.total, groups: groups,
                             charged: charge.filter(\.charged).count, toCharge: charge.count,
                             todoDone: todo.filter(\.checked).count, todo: todo.count)
    }

    // MARK: - The break

    /// "2026-10-13 19:00" (a time like "1900" or "19:00" is cleaned) → itself; anything else nil.
    public static func cleanMoment(_ s: String) -> String? {
        let t = jsTrim(s)
        guard t.count > 11 else { return nil }
        let day = String(t.prefix(10))
        guard isYMD(day), let time = cleanTime(String(t.dropFirst(11))) else { return nil }
        return "\(day) \(time)"
    }

    /// A moment `minutes` later (or earlier), over midnight as it must. Nil for no moment.
    public static func moment(_ s: String, plusMinutes minutes: Int) -> String? {
        guard let m = cleanMoment(s) else { return nil }
        let h = Int(m.dropFirst(11).prefix(2)) ?? 0, mm = Int(m.suffix(2)) ?? 0
        var total = h * 60 + mm + minutes
        var day = String(m.prefix(10))
        while total < 0 { total += 24 * 60; day = addDays(day, -1) }
        while total >= 24 * 60 { total -= 24 * 60; day = addDays(day, 1) }
        return "\(day) \(String(format: "%02d:%02d", total / 60, total % 60))"
    }

    /// When he means to go back to packing a trip: "2026-10-13 19:00"; "" = no break waiting.
    public static func breakUntil(_ trip: TripEvent) -> String {
        cleanMoment(trip.extra[BREAK_UNTIL_KEY]?.stringValue ?? "") ?? ""
    }

    /// The choices "Continue when?" offers.
    public enum BreakChoice: String, Sendable, CaseIterable {
        case hour, evening, tomorrow, pause
    }

    /// The moment a choice means, from `now` ("2026-10-13 14:20"): In an hour = now + 60
    /// minutes; This evening = today at 19:00, only while that is at least 30 minutes ahead
    /// (nil after); Tomorrow = tomorrow at `tomorrowAt` (18:00 unless he picks another time);
    /// Just pause = nil (no reminder).
    public static func breakMoment(_ choice: BreakChoice, now: String, tomorrowAt: String = BREAK_TOMORROW_AT) -> String? {
        guard let now = cleanMoment(now) else { return nil }
        let today = String(now.prefix(10))
        switch choice {
        case .hour: return moment(now, plusMinutes: 60)
        case .evening:
            let evening = "\(today) \(BREAK_EVENING_AT)"
            guard let soonest = moment(now, plusMinutes: BREAK_EVENING_LEAD_MINUTES), !jsStringLess(evening, soonest) else { return nil }
            return evening
        case .tomorrow:
            guard let time = cleanTime(tomorrowAt) else { return nil }
            return "\(addDays(today, 1)) \(time)"
        case .pause: return nil
        }
    }

    /// Why a break until `until` cannot be, as of `now` — nil when it can: the moment is no
    /// time, or has passed; the trip has set off by then (`hasSetOff` — a reminder to pack
    /// after he left says nothing useful); or everything is packed already.
    public func breakRefusal(tripId: String, until: String, now: String) -> String? {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return "No such trip." }
        guard let at = Library.cleanMoment(until) else { return "That is not a time." }
        guard let now = Library.cleanMoment(now), jsStringLess(now, at) else { return "That time has passed \u{2014} pick a later one." }
        if Library.hasSetOff(trip, today: String(at.prefix(10)), time: String(at.suffix(5))) {
            return "You leave before then \u{2014} pick an earlier time."
        }
        let p = progress(trip.entries)
        if p.done == p.total { return "Everything is packed." }
        return nil
    }

    /// Take a break until `until` ("2026-10-13 19:00"), replacing any break waiting; nil (Just
    /// pause) takes it away. A moment that is no moment is refused. (When it may be is
    /// `breakRefusal`'s question — asked by the sheet before it calls this.)
    @discardableResult
    public mutating func setBreak(until: String?, tripId: String) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }) else { return false }
        if let until {
            guard let at = Library.cleanMoment(until) else { return false }
            guard trips[n].extra[BREAK_UNTIL_KEY]?.stringValue != at else { return true }
            trips[n].extra[BREAK_UNTIL_KEY] = .string(at)
        } else {
            guard trips[n].extra[BREAK_UNTIL_KEY] != nil else { return true }
            trips[n].extra[BREAK_UNTIL_KEY] = nil
        }
        trips[n].updatedAt = nowISO()
        return true
    }

    /// The trip's name for a message: its name, else "your trip".
    static func messageName(_ trip: TripEvent) -> String {
        jsTrim(trip.name).isEmpty ? "your trip" : jsTrim(trip.name)
    }

    // MARK: - The messages

    /// Every message still to come, as of `now` ("2026-10-13 14:20", this device's clock),
    /// soonest first.
    ///
    /// Back to packing (a break): at the trip's `breakUntil`, while that is still ahead, the
    /// trip is at Pack now and not set off by then, is not reviewed, and something is left —
    /// "🎒 Back to packing Weekend in the hills" / "22 things left" (`BREAK_TITLE`, 0.84).
    ///
    /// With `movesOn` (the device's switch), for every trip not reviewed, dated, with lines:
    /// Pack → On site, "Have a good trip — <trip>", on its first day at the time he leaves
    /// (else 08:00), while it is at Pack now; On site → Review, "Welcome home — review <trip>
    /// in two minutes?", the day after its last day at 10:00. A moment already past has none;
    /// only the six soonest of these wait. Review → Refine says nothing: he saves the review
    /// in the app, and the app is in front of him.
    ///
    /// With `movesOn` too (0.87, his yes of 15 Oct 2026): "Charge tonight" the evening before
    /// the first day at 20:00, naming what is still to charge (`chargeTonight`) — one of the
    /// six soonest, as the moves-on messages are.
    public func tripMessages(now: String, movesOn: Bool) -> [TripMessage] {
        guard let now = Library.cleanMoment(now) else { return [] }
        let today = String(now.prefix(10)), time = String(now.suffix(5))
        var breaks: [TripMessage] = []
        var moves: [TripMessage] = []
        for trip in trips where !Library.isReviewed(trip) {
            let name = Library.messageName(trip)
            let step = loopStep(tripId: trip.id, today: today, time: time)
            // A break: back to packing.
            let until = Library.breakUntil(trip)
            if !until.isEmpty, step == .pack, breakRefusal(tripId: trip.id, until: until, now: now) == nil,
               let o = breakOverview(tripId: trip.id, sorting: "when", today: today) {
                breaks.append(TripMessage(id: "break-\(trip.id)", tripId: trip.id, kind: .breakOver,
                                          day: String(until.prefix(10)), time: String(until.suffix(5)),
                                          title: "\(BREAK_TITLE) \(name)", body: o.leftWords))
            }
            guard movesOn, !trip.entries.isEmpty, isYMD(trip.startDate) else { continue }
            // The evening before: what still needs charging (0.87).
            if let charge = chargeTonight(tripId: trip.id, now: now) { moves.append(charge) }
            // Pack → On site: when he sets off.
            let leave = Library.leaveTime(trip, home: false)
            let setOff = "\(trip.startDate) \(leave.isEmpty ? SET_OFF_MESSAGE_AT : leave)"
            if step == .pack, jsStringLess(now, setOff) {
                moves.append(TripMessage(id: "moves-onsite-\(trip.id)", tripId: trip.id, kind: .setOff,
                                         day: trip.startDate, time: String(setOff.suffix(5)),
                                         title: "Have a good trip \u{2014} \(name)",
                                         body: "The trip is On site now: what you buy, use up or want to fix goes there."))
            }
            // On site → Review: the morning after.
            let last = trip.endDate.isEmpty ? trip.startDate : trip.endDate
            if isYMD(last) {
                let back = Library.ymd(last, plusDays: 1)
                if jsStringLess(now, "\(back) \(REVIEW_MESSAGE_AT)") {
                    moves.append(TripMessage(id: "moves-review-\(trip.id)", tripId: trip.id, kind: .home,
                                             day: back, time: REVIEW_MESSAGE_AT,
                                             title: "Welcome home \u{2014} review \(name) in two minutes?",
                                             body: "What did you use, what did you miss? The next list learns from it."))
                }
            }
        }
        let soonest = Array(moves.stableSorted(by: { a, b in jsStringLess(a.moment, b.moment) }).prefix(MOVES_ON_LIMIT))
        return (breaks + soonest).stableSorted(by: { a, b in jsStringLess(a.moment, b.moment) })
    }

    // MARK: - In the calendar

    /// The break as a calendar entry: "🎒 Back to packing <trip>" (0.84), at `breakUntil`, 30 minutes,
    /// what is left as its note. Nil when no break is waiting.
    public func breakEvent(tripId: String) -> (title: String, notes: String, start: String, end: String)? {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return nil }
        let at = Library.breakUntil(trip)
        guard !at.isEmpty, let end = Library.moment(at, plusMinutes: BREAK_CALENDAR_MINUTES) else { return nil }
        let o = breakOverview(tripId: tripId, sorting: "when", today: String(at.prefix(10)))
        let notes = o.map { [$0.packedWords, $0.leftWords].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ") } ?? ""
        return ("\(BREAK_TITLE) \(Library.messageName(trip))", notes, at, end)
    }

    /// The break as a calendar file (.ics, RFC 5545) — what the Mac hands to Calendar. Its
    /// times are "floating": the calendar's own time zone, as the break's are the device's. An
    /// alert at the start. Nil when no break is waiting.
    public func breakCalendarFile(tripId: String) -> String? {
        guard let e = breakEvent(tripId: tripId) else { return nil }
        func stamp(_ m: String) -> String { m.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "T") + "00" }
        func text(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ";", with: "\\;")
                .replacingOccurrences(of: ",", with: "\\,").replacingOccurrences(of: "\n", with: "\\n")
        }
        // DTSTAMP: when the file was made, in UTC ("2026-10-13T12:00:00.000Z" → "20261013T120000Z").
        let made = nowISO().prefix(19).replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "") + "Z"
        let lines = [
            "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//AMS Packing//Take a break//EN", "CALSCALE:GREGORIAN",
            "BEGIN:VEVENT",
            "UID:break-\(tripId)-\(stamp(e.start))@ams-packing",
            "DTSTAMP:\(made)",
            "DTSTART:\(stamp(e.start))", "DTEND:\(stamp(e.end))",
            "SUMMARY:\(text(e.title))",
            "DESCRIPTION:\(text(e.notes))",
            "BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:\(text(e.title))", "TRIGGER:PT0M", "END:VALARM",
            "END:VEVENT", "END:VCALENDAR",
        ]
        return lines.joined(separator: "\r\n") + "\r\n"
    }
}
