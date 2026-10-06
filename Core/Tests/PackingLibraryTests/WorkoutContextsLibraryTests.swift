import XCTest
import PackingCore
@testable import PackingLibrary

/// Context PER WORKOUT (0.67) through the library: a trip made with it, changed in
/// Trip settings, kept by the sync records and a backup, and copied by Start again.
/// Invented data only — this repository is public.
final class WorkoutContextsLibraryTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    private func library() -> (Library, run: String, swim: String) {
        var lib = Library()
        let run = newList(name: "Run", group: "WET", items: [
            newItem(name: "Trail shoes", contexts: ["Outdoor"]),
            newItem(name: "Treadmill towel", contexts: ["Indoor"]),
            newItem(name: "Socks"),
        ])
        let swim = newList(name: "Swim", group: "WET", items: [
            newItem(name: "Pool goggles", contexts: ["Indoor"]),
            newItem(name: "Wetsuit", contexts: ["Outdoor"]),
        ])
        lib.saveTemplate(run)
        lib.saveTemplate(swim)
        return (lib, run.id, swim.id)
    }

    func testATripMadeWithEachWorkoutsContextIsBuiltChangedAndKept() throws {
        var (lib, run, swim) = library()
        var draft = newEvent(name: "Lake week", mode: "quick", activities: [run, swim])
        draft.activityContexts = [run: ["Outdoor"], swim: ["Indoor"]]
        let made = lib.createTrip(draft)
        XCTAssertEqual(Set(made.entries.map(\.name)), ["Trail shoes", "Socks", "Pool goggles"])

        // Trip settings: Swim outdoors now — the wetsuit comes, the pool goggles go, Run stays.
        let rebuilt = try XCTUnwrap(lib.changeTrip(id: made.id) { $0.activityContexts[swim] = ["Outdoor"] })
        XCTAssertEqual(rebuilt.added, 1); XCTAssertEqual(rebuilt.removed, 1)
        XCTAssertEqual(Set(lib.trips[0].entries.map(\.name)), ["Trail shoes", "Socks", "Wetsuit"])

        // The sync records (the trip head is its JSON) bring it back as it was.
        let synced = Library(records: lib.records())
        XCTAssertEqual(synced.trips[0].activityContexts, [run: ["Outdoor"], swim: ["Outdoor"]])
        XCTAssertTrue(recordChanges(from: lib.records(), to: synced.records()).isEmpty)

        // A backup too.
        let (back, report) = Importer.library(from: lib.backupFile(exportedAt: "2026-10-06T08:00:00.000Z"))
        XCTAssertTrue(report.isFaithful, report.mismatches.joined(separator: "; "))
        XCTAssertEqual(back.trips[0].activityContexts, [run: ["Outdoor"], swim: ["Outdoor"]])
        XCTAssertEqual(back.trips, lib.trips)

        // Start a new trip from this one: the same answers, so the same list when rebuilt.
        let again = try XCTUnwrap(lib.startAgain(from: made.id, name: "Lake week (again)"))
        XCTAssertEqual(again.activityContexts, [run: ["Outdoor"], swim: ["Outdoor"]])
    }
}
