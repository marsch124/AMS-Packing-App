// Phases — WHEN things get packed / done: the process vector, in timeline order.
// Ported from js/model.js ("WHEN things get packed / done").
//
// EDITABLE AND SYNCED (v118). The seven below are only the factory setting: the
// live list is whatever the user has made of it in Settings → When. Unlike the
// Packers, Owners, Conditions and the storage places this list SYNCS, because a
// phase is stamped on every item, every membership, every trip entry and every
// to-do, so a phase missing on one device would make the same item read as a
// different "When" there.
//
// Each phase carries:
//   id        stable string — what items actually store. NEVER changes on a rename.
//   label     what you read
//   hint      the small line under it in the picker
//   emoji     his pick, like a template cover or a kit
//   color     one of TEMPLATE_COLORS, or any hex
//   task      true = holds to-dos rather than physical items (Preparations)
//   leadDays  how many days before departure this phase becomes due — drives the
//             "pack this now" nudge. -1 means "after the trip".
//   order     position in the timeline; the list is always sorted by it
//
// The built-in ids are DELIBERATELY STABLE ('prep', 'week', …) so that two devices
// seeding this table independently produce the same seven primary keys and merge
// into one list instead of doubling it — the lesson from the 880-item duplication.

import Foundation

public struct Phase: JSONModel, Hashable, Sendable {
    public var id: String
    public var label: String
    public var hint: String
    public var emoji: String
    public var color: String
    public var task: Bool
    public var leadDays: Int
    /// A JS number that is never floored (`setPhases` renumbers it 0…n-1 anyway).
    public var order: Double

    public init(id: String = "", label: String = "", hint: String = "", emoji: String = "",
                color: String = "", task: Bool = false, leadDays: Int = 0, order: Double = 0) {
        self.id = id; self.label = label; self.hint = hint; self.emoji = emoji
        self.color = color; self.task = task; self.leadDays = leadDays; self.order = order
    }

    /// `coercePhase(json, 0)`. For a position other than 0 use `coercePhase(json:_:)`.
    public init(json: JSONValue) { self = coercePhase(json: json, 0) }

    public var json: JSONValue {
        ["id": .string(id), "label": .string(label), "hint": .string(hint), "emoji": .string(emoji),
         "color": .string(color), "task": .bool(task), "leadDays": .number(Double(leadDays)), "order": .number(order)]
    }
}

public let PHASE_DEFAULT_EMOJI = "📦"

/// The factory seven. (In JS these carry no `order`; here each has its position,
/// which is what `coercePhase(p, i)` gives them the moment they are installed.)
public let DEFAULT_PHASES: [Phase] = [
    Phase(id: "prep", label: "Preparations", hint: "Book, cancel, charge, arrange — done ahead of time.", emoji: "📋", color: "#7c5cd6", task: true, leadDays: 30, order: 0),
    Phase(id: "week", label: "≥1 week ahead", hint: "Things you don’t use at home — pack early.", emoji: "📦", color: "#3b82f6", task: false, leadDays: 7, order: 1),
    Phase(id: "daybefore", label: "Day before (stage / move to RV)", hint: "Pack and stage the day before departure.", emoji: "🌙", color: "#06b6d4", task: false, leadDays: 1, order: 2),
    Phase(id: "morning", label: "Morning list", hint: "Packed the morning of — used the night before / that morning.", emoji: "☀️", color: "#f59e0b", task: false, leadDays: 0, order: 3),
    Phase(id: "door", label: "At the front door", hint: "Last check as you leave (Vid ytterdörren).", emoji: "🚪", color: "#22c55e", task: false, leadDays: 0, order: 4),
    Phase(id: "wear", label: "Wear / carry on the day", hint: "Worn or carried, not packed away.", emoji: "👕", color: "#ec4899", task: false, leadDays: 0, order: 5),
    Phase(id: "after", label: "After / recovery", hint: "For after the activity — shower, change, recovery (Efter).", emoji: "🛁", color: "#14b8a6", task: false, leadDays: -1, order: 6),
]

// The live list and its ids — module-level state, mirrored from the JS ON PURPOSE.
// Replaced only through `setPhases`. Tests that change them restore the defaults.
public private(set) var PHASES: [Phase] = DEFAULT_PHASES
public private(set) var PHASE_IDS: [String] = DEFAULT_PHASES.map { $0.id }

/// The value rules of `coercePhase`, for a phase built in memory.
public func coercePhase(_ p: Phase, _ i: Int = 0) -> Phase {
    let emoji = jsTrim(p.emoji)
    return Phase(
        id: jsSlice(jsTrim(p.id), 0, 40),
        label: jsSlice(jsTrim(p.label), 0, 60),
        hint: jsSlice(jsTrim(p.hint), 0, 200),
        emoji: emoji.isEmpty ? PHASE_DEFAULT_EMOJI : jsSlice(emoji, 0, 8),
        color: isHexColor(p.color) ? p.color : TEMPLATE_COLORS[max(i, 0) % TEMPLATE_COLORS.count],
        task: p.task,
        leadDays: max(-1, min(365, p.leadDays)),
        order: p.order.isFinite ? p.order : Double(i)
    )
}

/// `coercePhase(p, i)` for raw JSON — anything that is not an object reads as `{}`.
public func coercePhase(json p: JSONValue?, _ i: Int = 0) -> Phase {
    let o = p?.objectValue ?? [:]
    let lead = jsNumber(o["leadDays"])
    let order = jsNumber(o["order"])
    return coercePhase(Phase(
        id: jsStringOrEmpty(o["id"]),
        label: jsStringOrEmpty(o["label"]),
        hint: jsStringOrEmpty(o["hint"]),
        emoji: jsStringOr(o["emoji"]),
        color: jsStringOr(o["color"]),
        task: jsTruthy(o["task"]),
        leadDays: lead.isFinite ? jsInt(max(-1, min(365, jsRound(lead)))) : 0,
        order: order.isFinite ? order : Double(i)
    ), i)
}

/// A new phase earns its id from its name (so it reads sensibly in a backup),
/// falling back to a timestamp when the name is all punctuation. `taken` are ids
/// already in use, which the new one must not collide with. `partial` is laid over
/// `{ id, label }` exactly as the JS spreads it (the app passes `["order": n]`).
public func newPhase(_ label: String, _ taken: [String] = [], _ partial: JSONValue = [:]) -> Phase {
    let base = jsSlug(label)
    var candidate = base.isEmpty ? "phase-\(jsBase36(jsDateNow()))" : base
    var n = 2
    while taken.contains(candidate) {
        candidate = "\(base.isEmpty ? "phase" : base)-\(n)"
        n += 1
    }
    var o: [String: JSONValue] = ["id": .string(candidate), "label": .string(label)]
    for (k, v) in partial.objectValue ?? [:] { o[k] = v }
    return coercePhase(json: .object(o), taken.count)
}

/// Install a phase list. Anything unusable (no id, no label, a duplicate id) is
/// dropped; an empty result falls back to the factory seven rather than leaving the
/// app with no phases at all — every item would then have nowhere to be.
/// The result is always sorted by `order`, and the orders renumbered 0..n-1 so two
/// devices that edited the list independently still agree on the timeline.
@discardableResult
public func setPhases(_ list: [Phase]) -> [Phase] {
    installPhases(list.enumerated().map { coercePhase($0.element, $0.offset) })
}
/// `setPhases` for raw JSON (a backup's `phases`, or a test written the JS way).
@discardableResult
public func setPhases(json list: JSONValue?) -> [Phase] {
    installPhases(asArray(list).enumerated().map { coercePhase(json: $0.element, $0.offset) })
}

private func installPhases(_ coerced: [Phase]) -> [Phase] {
    var seen = Set<String>()
    let clean = coerced.filter { p in
        if p.id.isEmpty || p.label.isEmpty || seen.contains(p.id) { return false }
        seen.insert(p.id)
        return true
    }
    // Sort by order, then by ID as a tiebreak. The tiebreak is load-bearing, not
    // tidiness: two phases can genuinely end up sharing an order (an added one is
    // appended at the end, and the other device may append too), and without a
    // deterministic second key each device would renumber them in whatever order it
    // happened to read them — then write that back and fight the other device.
    let source = clean.isEmpty ? DEFAULT_PHASES.enumerated().map { coercePhase($0.element, $0.offset) } : clean
    let next = source
        .stableSorted(compare: { a, b in jsOr(jsSign(a.order - b.order), jsLocaleCompare(a.id, b.id)) })
        .enumerated().map { (i, p) -> Phase in var q = p; q.order = Double(i); return q }
    PHASES = next
    PHASE_IDS = next.map { $0.id }
    return PHASES
}

/// Have the phases been changed from the factory seven? (Drives the Settings
/// summary line, and whether a backup bothers to carry them.)
public func phasesCustomised(_ list: [Phase] = PHASES) -> Bool {
    if list.count != DEFAULT_PHASES.count { return true }
    for (i, p) in list.enumerated() {
        let d = DEFAULT_PHASES[i]
        if p.id != d.id || p.label != d.label || p.emoji != d.emoji
            || p.color != d.color || p.task != d.task || p.leadDays != d.leadDays { return true }
    }
    return false
}

/// The phase record for an id. Unlike before v118 this does NOT fall back to a real
/// phase for an unknown id — callers that need something to draw use `phaseOrFallback`
/// — because silently answering "≥1 week ahead" is what used to retag items.
public func phase(_ id: String?) -> Phase? { PHASES.first { $0.id == id } }

/// Something drawable for any id at all, including one this device doesn't know
/// (set on the other device, or on a phase since removed). It keeps the raw id as
/// its label so nothing ever disappears from a packing list.
public func phaseOrFallback(_ id: String?) -> Phase {
    if let p = phase(id) { return p }
    let raw = id ?? ""
    return Phase(id: raw, label: raw.isEmpty ? "Unsorted" : raw, hint: "", emoji: "❓", color: "#64748b",
                 task: false, leadDays: 0, order: Double(PHASES.count))
}
public func phaseLabel(_ id: String?) -> String { phaseOrFallback(id).label }
public func phaseEmoji(_ id: String?) -> String { phaseOrFallback(id).emoji }
public func phaseColor(_ id: String?) -> String { phaseOrFallback(id).color }
/// How many days before departure this phase is due. Was the fixed PHASE_LEAD_DAYS
/// table until phases became editable.
public func phaseLeadDays(_ id: String?) -> Int { phaseOrFallback(id).leadDays }
/// Where a phase sits in the timeline. An id this device doesn't know sorts to the
/// END rather than into the middle of the list, so it is visible, not buried.
public func phaseOrder(_ id: String?) -> Int {
    guard let id = id, let i = PHASE_IDS.firstIndex(of: id) else { return PHASE_IDS.count }
    return i
}
/// The id a brand-new item should get: the first non-task phase, so a new thing
/// lands somewhere you actually pack. Falls back to the first phase of any kind.
public func defaultPhaseId() -> String {
    (PHASES.first { !$0.task } ?? PHASES.first)?.id ?? ""
}
