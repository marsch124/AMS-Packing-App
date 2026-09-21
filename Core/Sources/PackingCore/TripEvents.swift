// TripEvents — the order trips are listed in, the "pack this now" nudge, which
// finished trips still wait for their review, and the steps Packing Mode walks.
// Ported from js/model.js (`sortEventsForList`, `tripNudge`, `tripsAwaitingReview`, `packSteps`).

import Foundation

// MARK: - Ordering events

/// Order events for the Home preview and the Events tab: nearest upcoming trip
/// first, then undated drafts (most recently created first), then past trips
/// (most recent first). This puts "what I'm packing for next" at the top.
public func sortEventsForList(_ events: [TripEvent], _ todayISO: String? = nil) -> [TripEvent] {
    // Read "today" ONCE. (The JS reads the clock inside every comparison; with a
    // `todayISO` given — or a clock that does not cross midnight mid-sort — it is the same.)
    let today = todayYMD(todayISO)
    func rank(_ e: TripEvent) -> Int {
        guard let d = daysUntil(e.startDate, today) else { return 1 }   // undated drafts sit between upcoming and past
        return d >= 0 ? 0 : 2                                            // 0 = today/upcoming, 2 = past
    }
    return events.stableSorted(compare: { a, b in
        let ra = rank(a), rb = rank(b)
        if ra != rb { return ra < rb ? -1 : 1 }
        let da = daysUntil(a.startDate, today) ?? 0, db = daysUntil(b.startDate, today) ?? 0
        if ra == 0 { return jsSign(Double(da - db)) }                    // soonest first
        if ra == 2 { return jsSign(Double(db - da)) }                    // most recent past first
        return jsLocaleCompare(b.createdAt, a.createdAt)                 // undated: newest draft first
    })
}

// MARK: - The "pack now" nudge

/// `{ daysToGo, label, focusPhaseId, focusLabel, dueCount }`
public struct TripNudge: Equatable, Hashable, Sendable {
    /// Negative once the trip has started — Home filters on `daysToGo >= 0`.
    public var daysToGo: Int
    public var label: String
    /// nil = nothing is due (JS `null`).
    public var focusPhaseId: String?
    public var focusLabel: String
    public var dueCount: Int
    public init(daysToGo: Int, label: String, focusPhaseId: String? = nil, focusLabel: String = "", dueCount: Int = 0) {
        self.daysToGo = daysToGo; self.label = label; self.focusPhaseId = focusPhaseId
        self.focusLabel = focusLabel; self.dueCount = dueCount
    }
    public var json: JSONValue {
        ["daysToGo": .number(Double(daysToGo)), "label": .string(label), "focusPhaseId": JSONValue(focusPhaseId),
         "focusLabel": .string(focusLabel), "dueCount": .number(Double(dueCount))]
    }
}

/// What to pack right now: the earliest timeline phase that is "due" (its lead time has
/// arrived) and still has unpacked items. Returns nil when there's no date or nothing to read.
public func tripNudge(_ event: TripEvent?, _ todayISO: String? = nil) -> TripNudge? {
    guard let event = event, !event.startDate.isEmpty else { return nil }
    guard let daysToGo = daysUntil(event.startDate, todayISO) else { return nil }
    let due = packSteps(event.entries).filter { phaseLeadDays($0.phase.id) >= daysToGo && $0.remaining > 0 }
    let dueCount = due.reduce(0) { $0 + $1.remaining }
    let focus = due.first   // packSteps is timeline-ordered, so this is the earliest due phase
    return TripNudge(daysToGo: daysToGo, label: countdownLabel(daysToGo), focusPhaseId: focus?.phase.id,
                     focusLabel: focus?.phase.label ?? "", dueCount: dueCount)
}

// MARK: - Trips awaiting their review

/// How long after a trip ends the app still offers to review it. Beyond a month
/// the answers stop being memory and start being guesswork, and a wrong "used"
/// is worse for the learning than no answer at all — so the offer expires.
public let REVIEW_WINDOW_DAYS = 30

/// The day a trip is over: its return date if it has one, else the day it began
/// (a day trip is finished the evening it starts).
public func tripEndDate(_ event: TripEvent?) -> String {
    guard let event = event else { return "" }
    return jsSlice(event.endDate.isEmpty ? event.startDate : event.endDate, 0, 10)
}

/// `{ event, endedDaysAgo }` — one row of `tripsAwaitingReview`.
public struct TripAwaitingReview: Equatable, Sendable {
    public var event: TripEvent
    public var endedDaysAgo: Int
    public init(event: TripEvent, endedDaysAgo: Int) { self.event = event; self.endedDaysAgo = endedDaysAgo }
    public var json: JSONValue { ["event": event.json, "endedDaysAgo": .number(Double(endedDaysAgo))] }
}

/// Trips that are over and have never been reviewed, most recently finished first.
///
/// 🚨 WHY THIS EXISTS. The review is the ONLY thing that feeds the learning engine
/// — applyReview writes the packed/used counts that pruneSuggestions later reads —
/// and from v5 until v161 nothing in the app ever asked for it. The button sat on
/// the trip screen and Refine sat empty, so the oldest feature in the app had
/// quietly never run. This is what the Home screen asks from.
///
/// A trip ending TODAY is left alone: he is probably still driving home.
public func tripsAwaitingReview(_ events: [TripEvent], _ todayISO: String? = nil,
                                _ windowDays: Int = REVIEW_WINDOW_DAYS) -> [TripAwaitingReview] {
    var out: [TripAwaitingReview] = []
    for e in events {
        if !e.reviewedAt.isEmpty || e.status == "done" { continue }
        let end = tripEndDate(e)
        if end.isEmpty { continue }                              // an undated draft is never "over"
        guard let days = daysUntil(end, todayISO), days < 0 else { continue }   // still to come, or ending today
        let endedDaysAgo = -days
        if endedDaysAgo > windowDays { continue }                // too long ago to answer honestly
        // Reminders and tasks are not reviewable gear; a trip of nothing but those
        // has no question to ask.
        if !e.entries.contains(where: { $0.itemType != "reminder" }) { continue }
        out.append(TripAwaitingReview(event: e, endedDaysAgo: endedDaysAgo))
    }
    return out.stableSorted(compare: { a, b in jsSign(Double(a.endedDaysAgo - b.endedDaysAgo)) })
}

// MARK: - Packing Mode steps

/// `{ phase, entries, total, done, remaining }` — one step of Packing Mode.
public struct PackStep: Equatable, Sendable {
    public var phase: Phase
    public var entries: [Item]
    public var total: Int
    public var done: Int
    public var remaining: Int
    public init(phase: Phase, entries: [Item], total: Int, done: Int, remaining: Int) {
        self.phase = phase; self.entries = entries; self.total = total; self.done = done; self.remaining = remaining
    }
    public var json: JSONValue {
        ["phase": phase.json, "entries": .array(entries.map { $0.json }), "total": .number(Double(total)),
         "done": .number(Double(done)), "remaining": .number(Double(remaining))]
    }
}

/// Packing Mode steps: one per non-empty timeline phase, with packed/remaining counts.
/// The UI walks these one at a time.
/// Packing Mode walks what you are packing — anything set aside is not part of
/// the walk, and a phase left with nothing to pack drops out of it entirely.
public func packSteps(_ entries: [Item]) -> [PackStep] {
    entriesByPhase(packable(entries)).map { g in
        let total = g.entries.count
        let done = g.entries.filter { $0.checked }.count
        return PackStep(phase: g.phase, entries: g.entries, total: total, done: done, remaining: total - done)
    }
}
