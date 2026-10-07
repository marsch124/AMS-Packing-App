import Foundation
import PackingCore

// Apple Health fills in the review (0.70 — chapter 07, part 7). After a trip, the review
// shows the workouts Apple Health logged on the trip's days and offers "Use these", which
// marks the lines of the workout templates: a workout done → used, not done (or done only
// in the other context) → didn't use. Everything else is left exactly as it was.
//
// Nothing here touches Apple Health. The app reads it (iPhone only, read only) and hands
// this file plain records — the same records the UI tests invent — so every rule below is
// tested with invented workouts and no device.

// MARK: - The kinds of workout a template can meet

/// A kind of workout, as the review names it. Each Apple Health workout type the app reads
/// belongs to one; each template meets at most one (by its name, or by the "Counts as" link
/// he sets on the template's page).
public enum WorkoutKind: String, CaseIterable, Sendable {
    case swim, bike, run, strength, mobility, hiking, golf, climbing, diving

    /// The name on the review's rows and in the "Counts as" drop-down.
    public var label: String {
        switch self {
        case .swim: return "Swim"
        case .bike: return "Bike"
        case .run: return "Run"
        case .strength: return "Strength"
        case .mobility: return "Mobility & breath work"
        case .hiking: return "Hiking"
        case .golf: return "Golf"
        case .climbing: return "Climbing"
        case .diving: return "Diving"
        }
    }

    /// The template names that meet this kind by themselves, written the way `WorkoutTone`
    /// compares a workout's name: lower case, no white space ("Breath work" = "breathwork").
    /// His own names are here ("Mobility & Breath work", "Diving and Freediving") and the
    /// plain words for each kind; any other name needs the "Counts as" link.
    static let names: [WorkoutKind: Set<String>] = [
        .swim: ["swim", "swimming"],
        .bike: ["bike", "biking", "cycling", "cycle"],
        .run: ["run", "running"],
        .strength: ["strength", "strengthtraining", "gym"],
        .mobility: ["mobility", "breathwork", "breath", "mobility&breathwork", "mobilityandbreathwork",
                    "mobility&breath", "yoga", "stretching"],
        .hiking: ["hiking", "hike"],
        .golf: ["golf"],
        .climbing: ["climbing", "climb"],
        .diving: ["diving", "freediving", "divingandfreediving", "diving&freediving", "scubadiving", "dive"],
    ]

    /// A template's name, compared as the workout colours compare it.
    static func key(_ name: String) -> String { normName(name).filter { !$0.isWhitespace } }

    /// The kind a template's NAME meets; nil = none.
    public static func named(_ name: String) -> WorkoutKind? {
        let k = key(name)
        guard !k.isEmpty else { return nil }
        return allCases.first { names[$0]?.contains(k) == true }
    }

    /// The kind an Apple Health workout type is (its `HKWorkoutActivityType` number);
    /// nil = a workout the review does not use (a walk, tennis…).
    public static func of(activityType: UInt) -> WorkoutKind? {
        switch activityType {
        case HealthActivity.swimming: return .swim
        case HealthActivity.cycling: return .bike
        case HealthActivity.running: return .run
        case HealthActivity.traditionalStrengthTraining, HealthActivity.functionalStrengthTraining,
             HealthActivity.coreTraining: return .strength
        case HealthActivity.yoga, HealthActivity.mindAndBody, HealthActivity.flexibility,
             HealthActivity.cooldown, HealthActivity.preparationAndRecovery: return .mobility
        case HealthActivity.hiking: return .hiking
        case HealthActivity.golf: return .golf
        case HealthActivity.climbing: return .climbing
        case HealthActivity.underwaterDiving: return .diving
        default: return nil
        }
    }
}

/// Apple Health's numbers for the workout types the review reads (`HKWorkoutActivityType`'s
/// raw values — fixed by Apple, the same on every device). Written out here so the model can
/// be tested without Apple Health.
public enum HealthActivity {
    public static let climbing: UInt = 9
    public static let cycling: UInt = 13
    public static let functionalStrengthTraining: UInt = 20
    public static let golf: UInt = 21
    public static let hiking: UInt = 24
    public static let mindAndBody: UInt = 29
    public static let preparationAndRecovery: UInt = 33
    public static let running: UInt = 37
    public static let swimming: UInt = 46
    public static let traditionalStrengthTraining: UInt = 50
    public static let walking: UInt = 52
    public static let yoga: UInt = 57
    public static let coreTraining: UInt = 59
    public static let flexibility: UInt = 62
    public static let cooldown: UInt = 80
    /// A multisport workout (a triathlon): its parts are read one by one.
    public static let swimBikeRun: UInt = 82
    /// The change-over inside a multisport workout — never a workout of its own.
    public static let transition: UInt = 83
    public static let underwaterDiving: UInt = 84
}

/// Apple Health's swimming location (`HKWorkoutSwimmingLocationType`).
public enum SwimmingLocation {
    public static let unknown = 0
    public static let pool = 1
    public static let openWater = 2
}

// MARK: - A workout, as read from Apple Health

/// One workout as the app reads it from Apple Health — plain values, nothing of HealthKit.
public struct HealthWorkout: Equatable, Sendable {
    /// `HKWorkoutActivityType`'s number (see `HealthActivity`).
    public var activityType: UInt
    /// The day it STARTED, YYYY-MM-DD, in the device's time zone.
    public var day: String
    /// Apple Health's "indoor workout" (or the workout's own location); nil = not said.
    public var indoor: Bool?
    /// Apple Health's swimming location (`SwimmingLocation`); nil = not said.
    public var swimmingLocation: Int?
    /// A multisport workout's parts, in order (swim, transition, bike, transition, run).
    public var parts: [HealthWorkout]

    public init(activityType: UInt, day: String, indoor: Bool? = nil, swimmingLocation: Int? = nil,
                parts: [HealthWorkout] = []) {
        self.activityType = activityType; self.day = day; self.indoor = indoor
        self.swimmingLocation = swimmingLocation; self.parts = parts
    }
}

/// A workout the review uses: its kind, and Indoor / Outdoor when Apple Health says (nil =
/// it cannot say — then it counts for a line of either context).
public struct MetWorkout: Equatable, Sendable {
    public var kind: WorkoutKind
    public var context: String?
    public var day: String
    public init(kind: WorkoutKind, context: String?, day: String) { self.kind = kind; self.context = context; self.day = day }
}

/// The workouts the review uses, each with its context (the table in chapter 07):
/// Swim — pool → Indoor, open water → Outdoor, unknown → either; Bike, Run, Climbing —
/// indoor workout → Indoor, otherwise Outdoor; Strength → Indoor; Mobility & breath work →
/// either; Hiking, Golf, Diving → Outdoor. A multisport workout counts as its parts (a
/// triathlon = a swim, a ride and a run; the change-overs are nothing). Any other type is
/// left out.
public func metWorkouts(_ all: [HealthWorkout]) -> [MetWorkout] {
    var out: [MetWorkout] = []
    for w in all {
        if w.activityType == HealthActivity.swimBikeRun {
            out += metWorkouts(w.parts.filter { $0.activityType != HealthActivity.swimBikeRun })
            continue
        }
        guard let kind = WorkoutKind.of(activityType: w.activityType) else { continue }
        let context: String?
        switch kind {
        case .swim:
            switch w.swimmingLocation {
            case .some(SwimmingLocation.pool): context = "Indoor"
            case .some(SwimmingLocation.openWater): context = "Outdoor"
            default: context = nil
            }
        case .bike, .run, .climbing: context = w.indoor == true ? "Indoor" : "Outdoor"
        case .strength: context = "Indoor"
        case .mobility: context = nil
        case .hiking, .golf, .diving: context = "Outdoor"
        }
        out.append(MetWorkout(kind: kind, context: context, day: w.day))
    }
    return out
}

// MARK: - The template's own "Counts as"

extension Library {
    /// The template key his "Counts as" choice is stored under — the template's own extra
    /// keys, like its icon, so it travels with iCloud and every backup.
    public static let countsAsKey = "countsAs"
    /// "Counts as: Nothing" — the template meets no workout, whatever its name says.
    public static let countsAsNothing = "none"

    /// What he picked for this template ("none" included); nil = never picked.
    public func countsAsChoice(templateId: String) -> String? {
        templates.first { $0.id == templateId }?.extra[Library.countsAsKey]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The workout a template meets: his link, else its name. Only an activity template
    /// (role "") can meet one — the common base and the transport templates never do.
    public static func workoutKind(of list: PackList) -> WorkoutKind? {
        guard list.role.isEmpty else { return nil }
        if let chosen = list.extra[Library.countsAsKey]?.stringValue, !chosen.isEmpty {
            return WorkoutKind(rawValue: chosen)            // "none" (or a word it does not know) = none
        }
        return WorkoutKind.named(list.name)
    }

    /// The same for a template of the library by id.
    public func workoutKind(templateId: String) -> WorkoutKind? {
        templates.first { $0.id == templateId }.flatMap(Library.workoutKind(of:))
    }

    /// Link a template to a kind (`WorkoutKind.rawValue`), to nothing ("none"), or back to
    /// its name (nil). Refused for a template that is not there or a value it does not know.
    @discardableResult
    public mutating func setCountsAs(templateId: String, to value: String?) -> Bool {
        guard let n = templates.firstIndex(where: { $0.id == templateId }) else { return false }
        if let value, !value.isEmpty {
            guard value == Library.countsAsNothing || WorkoutKind(rawValue: value) != nil else { return false }
            templates[n].extra[Library.countsAsKey] = .string(value)
        } else {
            templates[n].extra.removeValue(forKey: Library.countsAsKey)
        }
        templates[n].updatedAt = nowISO()
        return true
    }
}

// MARK: - Whose things the workouts speak for

extension Library {
    /// Who he is, as "Whose it is" names him: the owner he marked "This is me" (Your choices
    /// → Owners, `me()`); while nobody is marked, a guess — the name on the most of his
    /// things (ties: the first A–Z). "" when no thing names anyone — then every thing counts
    /// as his.
    public func mainOwner() -> String {
        if let me = me() { return me }
        var count: [String: Int] = [:], spelling: [String: String] = [:]
        for i in items {
            let key = normName(i.ownedBy)
            guard !key.isEmpty else { continue }
            count[key, default: 0] += 1
            if spelling[key] == nil { spelling[key] = jsTrim(i.ownedBy) }
        }
        let best = count.max { a, b in a.value != b.value ? a.value < b.value : a.key > b.key }
        return best.flatMap { spelling[$0.key] } ?? ""
    }
}

// MARK: - The review's block

extension Library {
    /// One row of the block: "Swim · indoor · 3 times", or "No bike" for a workout
    /// template on the trip that had no workout.
    public struct HealthRow: Equatable, Sendable {
        public var kind: WorkoutKind
        public var words: String
        public var done: Bool
        public init(kind: WorkoutKind, words: String, done: Bool) { self.kind = kind; self.words = words; self.done = done }
    }

    /// What Apple Health says about a trip: the rows to show, how many of its workouts the
    /// review uses (0 = "No workouts in Apple Health for these days"), and the marks "Use
    /// these" would set — line id → used (true) or didn't use (false). A line not in
    /// `marks` is left as it is.
    public struct HealthReview: Equatable, Sendable {
        public var rows: [HealthRow]
        public var workouts: Int
        public var marks: [String: Bool]
        public init(rows: [HealthRow] = [], workouts: Int = 0, marks: [String: Bool] = [:]) {
            self.rows = rows; self.workouts = workouts; self.marks = marks
        }
    }

    /// The days Apple Health is asked about: the trip's first to its last day (one day when
    /// it has no last day). nil for an undated trip — it gets no block.
    public func healthDays(tripId: String) -> (first: String, last: String)? {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return nil }
        let first = jsTrim(trip.startDate)
        guard isDay(first) else { return nil }
        let last = jsTrim(trip.endDate)
        return (first, isDay(last) && last >= first ? last : first)
    }

    private func isDay(_ s: String) -> Bool {
        s.count == 10 && s.split(separator: "-").count == 3 && s.allSatisfy { $0.isNumber || $0 == "-" }
    }

    /// The block and the marks for one trip, from the workouts Apple Health gave (any days —
    /// only the trip's are used).
    public func healthReview(tripId: String, workouts all: [HealthWorkout]) -> HealthReview {
        guard let trip = trips.first(where: { $0.id == tripId }), let days = healthDays(tripId: tripId) else {
            return HealthReview()
        }
        let met = metWorkouts(all).filter { $0.day >= days.first && $0.day <= days.last }
        guard !met.isEmpty else { return HealthReview() }

        // The templates that fed this trip, as a trip is built from them.
        let feeding = listsForEvent(trip, resolvedTemplates())

        // The rows: every kind done (in the kinds' order), then each workout template on
        // the trip that had none.
        var rows: [HealthRow] = []
        for kind in WorkoutKind.allCases {
            let done = met.filter { $0.kind == kind }
            guard !done.isEmpty else { continue }
            rows.append(HealthRow(kind: kind, words: Library.rowWords(kind, done), done: true))
        }
        var missing: [WorkoutKind] = []
        for list in feeding {
            guard let kind = Library.workoutKind(of: list), !met.contains(where: { $0.kind == kind }),
                  !missing.contains(kind) else { continue }
            missing.append(kind)
        }
        for kind in WorkoutKind.allCases where missing.contains(kind) {
            rows.append(HealthRow(kind: kind, words: "No \(kind.label.lowercased())", done: false))
        }

        // The marks.
        let me = normName(mainOwner())
        var marks: [String: Bool] = [:]
        for line in reviewLines(tripId: tripId).packed {
            if let used = healthVerdict(line, trip: trip, feeding: feeding, met: met, me: me) { marks[line.id] = used }
        }
        return HealthReview(rows: rows, workouts: met.count, marks: marks)
    }

    /// "Swim · indoor · 3 times", "Swim · 2 indoor, 1 outdoor · 3 times", "Mobility & breath
    /// work · once". A context Apple Health could not tell is not named.
    static func rowWords(_ kind: WorkoutKind, _ done: [MetWorkout]) -> String {
        let indoor = done.filter { $0.context == "Indoor" }.count
        let outdoor = done.filter { $0.context == "Outdoor" }.count
        var parts = [kind.label]
        if indoor == done.count { parts.append("indoor") }
        else if outdoor == done.count { parts.append("outdoor") }
        else if indoor + outdoor > 0 {
            parts.append([indoor > 0 ? "\(indoor) indoor" : "", outdoor > 0 ? "\(outdoor) outdoor" : ""]
                .filter { !$0.isEmpty }.joined(separator: ", "))
        }
        parts.append(done.count == 1 ? "once" : "\(done.count) times")
        return parts.joined(separator: " \u{00B7} ")
    }

    /// One line's answer: true = used, false = didn't use, nil = left as it is.
    ///
    /// Left as it is: a line added by hand (no template), someone else's thing, a thing
    /// any non-workout template on the trip also holds (the common base wins), and a line
    /// for Race only on every workout template holding it ("Race" is not in Apple Health).
    /// Otherwise each workout template holding the thing answers: used when a workout of its
    /// kind was done in a context the line is for (or the line is for any context, or the
    /// workout's context is not known); didn't use when none of its kind was done at all, or
    /// only in the other context. One template saying "used" is enough.
    private func healthVerdict(_ line: Item, trip: TripEvent, feeding: [PackList], met: [MetWorkout], me: String) -> Bool? {
        guard !line.custom, let source = line.sourceListId, !source.isEmpty else { return nil }
        let thingId = line.sourceItemId ?? line.itemId ?? ""
        guard !thingId.isEmpty else { return nil }
        // Someone else's thing: his workouts say nothing about hers.
        let owner = items.first { $0.id == thingId }?.ownedBy ?? line.ownedBy
        if !me.isEmpty, !normName(owner).isEmpty, normName(owner) != me { return nil }

        // Every template that put this thing on the trip — its own source first.
        var holders: [(list: PackList, contexts: [String])] = []
        for list in feeding {
            guard let row = list.items.first(where: { $0.id == thingId }) else { continue }
            let brought = list.id == source || (!row.retired && itemMatchesEvent(row, trip, list)
                && (row.weather.isEmpty || row.weather.contains { trip.weatherOn.contains($0) }))
            if brought { holders.append((list, row.contexts)) }
        }
        if !holders.contains(where: { $0.list.id == source }) {
            // The row has gone from its template since the trip was made: the template
            // still counts, for any context.
            guard let list = resolvedTemplate(id: source) else { return nil }
            holders.insert((list, []), at: 0)
        }
        // The common base (or any template that is not a workout) wins.
        if holders.contains(where: { Library.workoutKind(of: $0.list) == nil }) { return nil }

        var anyUnknown = false
        for holder in holders {
            guard let kind = Library.workoutKind(of: holder.list) else { return nil }
            let own = holder.contexts.filter { $0 == "Indoor" || $0 == "Outdoor" }
            let race = holder.contexts.contains("Race")
            if race && own.isEmpty { anyUnknown = true; continue }        // Race only
            let done = met.filter { $0.kind == kind }
            if own.isEmpty { if !done.isEmpty { return true } else { continue } }
            if done.contains(where: { $0.context == nil || own.contains($0.context!) }) { return true }
            if race && !done.isEmpty { anyUnknown = true }                  // only the other context: it may have been the race
        }
        return anyUnknown ? nil : false
    }

    /// The review's "didn't use" marks after "Use these": each mark applied, except on a line
    /// he answered by hand — his answer stays.
    public static func unusedAfterHealth(_ marks: [String: Bool], unused: Set<String>, answeredByHand: Set<String>) -> Set<String> {
        var out = unused
        for (line, used) in marks where !answeredByHand.contains(line) {
            if used { out.remove(line) } else { out.insert(line) }
        }
        return out
    }
}
