import Foundation
import PackingCore

// The trip ahead, counted down on Home, and the packing steps it reminds him of —
// his pre-trip ideas 6 and 7 (2 Oct 2026). A step (a "When") falls due its lead
// days before the trip starts: Preparations a month ahead, a week ahead, the day
// before, the morning, the front door. A step with nothing left says nothing, and
// the steps for after the trip (lead days below 0) are no reminders.

extension Library {
    public struct PackingStep: Equatable, Sendable {
        public var phaseId: String
        public var label: String
        /// A step of things to DO (Preparations) rather than to pack.
        public var task: Bool
        /// The day it falls due: the trip's start less the step's lead days.
        public var date: String
        /// Its lines not yet ticked or set aside.
        public var left: Int

        /// "≥1 week ahead: 12 to pack", "Preparations: 3 to do".
        public var says: String { "\(label): \(left) to \(task ? "do" : "pack")" }
    }

    public struct NextTrip: Equatable, Sendable {
        public var id: String
        public var name: String
        public var startDate: String
        /// Whole days until it starts; 0 = today.
        public var days: Int
        /// Lines still to pack, every step together.
        public var left: Int
        /// The first step with something left — due already, or still to come.
        public var step: PackingStep?
    }

    public struct PackingReminder: Equatable, Sendable {
        public var tripId: String
        public var tripName: String
        public var date: String
        public var steps: [PackingStep]
        /// Every step due that day, in the timeline's order.
        public var says: String { steps.map(\.says).joined(separator: " · ") }
    }

    /// Not reviewed, dated, and starting today or later.
    private func stillToLeave(_ t: TripEvent, _ today: String) -> Bool {
        t.status != "done" && t.reviewedAt.isEmpty && isYMD(t.startDate) && !jsStringLess(t.startDate, today)
    }

    /// One trip's steps that still have something left, soonest first (steps due
    /// the same day keep the timeline's order).
    public func packingSteps(tripId: String) -> [PackingStep] {
        guard let trip = trips.first(where: { $0.id == tripId }), isYMD(trip.startDate) else { return [] }
        var out: [PackingStep] = []
        for phase in PHASES where phase.leadDays >= 0 {
            let left = trip.entries.filter { $0.phase == phase.id && !$0.checked && !isSetAside($0) }.count
            guard left > 0 else { continue }
            out.append(PackingStep(phaseId: phase.id, label: phase.label, task: phase.task,
                                   date: Library.ymd(trip.startDate, plusDays: -phase.leadDays), left: left))
        }
        return out.stableSorted(by: { a, b in jsStringLess(a.date, b.date) })
    }

    /// The trip he leaves on next: the soonest one still to leave. A trip under way
    /// is no countdown.
    public func nextTrip(today: String) -> NextTrip? {
        let ahead = trips.filter { stillToLeave($0, today) }
            .stableSorted(by: { a, b in jsStringLess(a.startDate, b.startDate) })
        guard let t = ahead.first, let days = daysUntil(t.startDate, today) else { return nil }
        let left = t.entries.filter { !$0.checked && !isSetAside($0) }.count
        return NextTrip(id: t.id, name: t.name, startDate: t.startDate, days: days, left: left,
                        step: packingSteps(tripId: t.id).first)
    }

    /// What to remind him of: one reminder per trip per day a step falls due, from
    /// today on, soonest first — at most `limit` (an iPhone keeps 64 waiting
    /// notifications per app).
    public func reminderPlan(today: String, limit: Int = 48) -> [PackingReminder] {
        var out: [PackingReminder] = []
        for t in trips where stillToLeave(t, today) {
            var days: [PackingReminder] = []
            for s in packingSteps(tripId: t.id) where !jsStringLess(s.date, today) {
                if let n = days.firstIndex(where: { $0.date == s.date }) { days[n].steps.append(s) }
                else { days.append(PackingReminder(tripId: t.id, tripName: t.name, date: s.date, steps: [s])) }
            }
            out += days
        }
        return Array(out.stableSorted(by: { a, b in jsStringLess(a.date, b.date) }).prefix(max(0, limit)))
    }

    /// "2026-10-21" less 7 days is "2026-10-14".
    static func ymd(_ s: String, plusDays n: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = cal.timeZone
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: String(s.prefix(10))), let moved = cal.date(byAdding: .day, value: n, to: d) else { return s }
        return f.string(from: moved)
    }
}
