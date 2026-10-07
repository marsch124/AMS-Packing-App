import Foundation
import PackingCore
import PackingLibrary
#if os(iOS) && canImport(HealthKit)
import HealthKit
#endif

// Apple Health, for the trip review (0.70 — chapter 07, part 7). READ ONLY: the app asks
// for the workouts of the trip's days and never writes anything to Apple Health. Nothing
// read leaves the device; only the review's answers (used / didn't use) are saved and
// synced, as before. The rules — which workout meets which template, the contexts, what
// "Use these" marks — are the model's (PackingLibrary/AppleHealthReview.swift); this file
// only fetches the workouts as plain records.

/// What Apple Health answered.
enum HealthAnswer: Equatable {
    /// Not allowed (or nothing readable at all — Apple never tells an app that reading was
    /// refused; see `HealthKitWorkouts`).
    case refused
    /// The workouts that started on the asked days (any kind — the model picks).
    case workouts([HealthWorkout])
}

/// Where the review's workouts come from: Apple Health on the iPhone, nowhere on the Mac,
/// invented ones under the UI tests (`-uiTestingHealth`).
protocol WorkoutSource {
    /// false = there is no Apple Health here (the Mac): the review shows no block at all.
    var available: Bool { get }
    /// Asks for permission the first time (Apple's own sheet), then reads the workouts that
    /// started between the first day's 00:00 and the last day's 23:59 on this device.
    func workouts(firstDay: String, lastDay: String) async -> HealthAnswer
}

enum AppleHealth {
    /// The source of this launch. Under any `-uiTesting…` the real Apple Health is never
    /// asked (its permission sheet would stop every review test): `-uiTestingHealth` feeds
    /// invented workouts — with `-healthRefused` it answers "not allowed", with `-healthNone`
    /// it has nothing on the trip's days — and every other test mode has no Apple Health.
    static let source: WorkoutSource = {
        let args = ProcessInfo.processInfo.arguments
        if AMSPackingApp.testing {
            #if os(iOS)
            if args.contains("-uiTestingHealth") {
                return InventedHealth(refused: args.contains("-healthRefused"), none: args.contains("-healthNone"))
            }
            #endif
            return NoHealth()
        }
        #if os(iOS) && canImport(HealthKit)
        return HealthKitWorkouts()
        #else
        return NoHealth()
        #endif
    }()
}

/// The Mac, and every test that is not about Apple Health.
struct NoHealth: WorkoutSource {
    var available: Bool { false }
    func workouts(firstDay: String, lastDay: String) async -> HealthAnswer { .workouts([]) }
}

/// The UI tests' Apple Health (`-uiTestingHealth`): invented workouts around the sample
/// trip's days (`SampleLibrary.health()`, six to two days ago) — three pool swims and two
/// outdoor runs on the trip, a walk on it (ignored), and a swim the week before (not on its
/// days). Never used outside the tests.
struct InventedHealth: WorkoutSource {
    var refused = false
    var none = false
    var available: Bool { true }

    /// Counted as the sample trip's days are (`SampleLibrary.health()`).
    static func day(_ n: Int) -> String {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    func workouts(firstDay: String, lastDay: String) async -> HealthAnswer {
        if refused { return .refused }
        if none { return .workouts([]) }
        let d = InventedHealth.day
        return .workouts([
            HealthWorkout(activityType: HealthActivity.swimming, day: d(-12), swimmingLocation: SwimmingLocation.openWater),
            HealthWorkout(activityType: HealthActivity.swimming, day: d(-6), swimmingLocation: SwimmingLocation.pool),
            HealthWorkout(activityType: HealthActivity.running, day: d(-5), indoor: false),
            HealthWorkout(activityType: HealthActivity.swimming, day: d(-4), swimmingLocation: SwimmingLocation.pool),
            HealthWorkout(activityType: HealthActivity.walking, day: d(-4)),
            HealthWorkout(activityType: HealthActivity.running, day: d(-3), indoor: false),
            HealthWorkout(activityType: HealthActivity.swimming, day: d(-2), swimmingLocation: SwimmingLocation.pool),
        ].filter { $0.day >= firstDay && $0.day <= lastDay })
    }
}

#if os(iOS) && canImport(HealthKit)
/// The real Apple Health. Read only: permission is asked for workouts and nothing else.
final class HealthKitWorkouts: WorkoutSource {
    private let store = HKHealthStore()

    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    func workouts(firstDay: String, lastDay: String) async -> HealthAnswer {
        let type = HKObjectType.workoutType()
        do {
            // The first time: Apple's sheet, with our words (NSHealthShareUsageDescription).
            // Afterwards it returns at once. It throws without the HealthKit entitlement —
            // the version that must never reach him (the release step checks for it).
            try await store.requestAuthorization(toShare: [], read: [type])
        } catch {
            return .refused
        }
        guard let from = Today.date(firstDay), let lastMidnight = Today.date(lastDay),
              let to = Calendar.current.date(byAdding: .day, value: 1, to: lastMidnight) else { return .workouts([]) }
        let window = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        guard let found = await read(window, limit: nil) else { return .refused }
        if found.isEmpty {
            // Apple never tells an app that reading was refused: it simply sees nothing. So
            // when the trip's days hold no workout, one workout from ANY day is asked for —
            // none at all, ever, is taken as "not allowed" (he logs workouts every week).
            guard let any = await read(nil, limit: 1), !any.isEmpty else { return .refused }
        }
        return .workouts(found.map(HealthKitWorkouts.record))
    }

    /// nil = Apple Health would not answer at all.
    private func read(_ predicate: NSPredicate?, limit: Int?) async -> [HKWorkout]? {
        let query = HKSampleQueryDescriptor(predicates: [.workout(predicate)],
                                            sortDescriptors: [SortDescriptor(\.startDate)], limit: limit)
        return try? await query.result(for: store)
    }

    /// A workout as the model reads it: its type, its day here, indoor or not and the
    /// swimming location — from its metadata, else from its own configuration — and, for a
    /// multisport workout (a triathlon), each of its parts the same way.
    static func record(_ w: HKWorkout) -> HealthWorkout {
        let activities = w.workoutActivities
        let single = activities.count == 1 ? activities.first?.workoutConfiguration : nil
        var out = HealthWorkout(activityType: w.workoutActivityType.rawValue, day: Today.iso(w.startDate),
                                indoor: indoor(w.metadata) ?? single.flatMap { indoor($0) },
                                swimmingLocation: swimming(w.metadata) ?? single.flatMap { swimming($0) })
        if w.workoutActivityType == .swimBikeRun {
            out.parts = activities.map { a in
                HealthWorkout(activityType: a.workoutConfiguration.activityType.rawValue, day: Today.iso(a.startDate),
                              indoor: indoor(a.metadata) ?? indoor(a.workoutConfiguration),
                              swimmingLocation: swimming(a.metadata) ?? swimming(a.workoutConfiguration))
            }
        }
        return out
    }

    private static func indoor(_ metadata: [String: Any]?) -> Bool? {
        (metadata?[HKMetadataKeyIndoorWorkout] as? NSNumber)?.boolValue
    }
    private static func indoor(_ c: HKWorkoutConfiguration) -> Bool? {
        switch c.locationType {
        case .indoor: return true
        case .outdoor: return false
        default: return nil
        }
    }
    private static func swimming(_ metadata: [String: Any]?) -> Int? {
        (metadata?[HKMetadataKeySwimmingLocationType] as? NSNumber).map { $0.intValue }
    }
    private static func swimming(_ c: HKWorkoutConfiguration) -> Int? {
        c.swimmingLocationType == .unknown ? nil : c.swimmingLocationType.rawValue
    }
}
#endif
