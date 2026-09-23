import XCTest
import PackingCore
@testable import PackingLibrary

/// "Only sometimes": the things on a grab list he takes one time in ten. They
/// start skipped every time, and one tap brings one into today's session.
final class GrabSometimesTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    private var swimId: String { "swim-out" }
    private func library() -> Library {
        var lib = Library()
        _ = lib.saveGrabList(id: swimId, items: ["Swim trunks", "Goggles", "Wetsuit", "Safety buoy", "Towel"])
        return lib
    }

    func testNothingIsOnlySometimesToBeginWith() {
        XCTAssertTrue(library().sometimes(listId: swimId).isEmpty)
    }

    func testAThingCanBeMarkedAndUnmarked() {
        var lib = library()
        XCTAssertTrue(lib.setSometimes(listId: swimId, name: "Wetsuit", on: true))
        XCTAssertEqual(lib.sometimes(listId: swimId), ["Wetsuit"])
        XCTAssertTrue(lib.setSometimes(listId: swimId, name: "Safety buoy", on: true))
        XCTAssertEqual(lib.sometimes(listId: swimId).count, 2)
        XCTAssertTrue(lib.setSometimes(listId: swimId, name: "Wetsuit", on: false))
        XCTAssertEqual(lib.sometimes(listId: swimId), ["Safety buoy"])
    }

    func testOnlyThingsActuallyOnTheListCount() {
        var lib = library()
        _ = lib.setSometimes(listId: swimId, names: ["Wetsuit", "Snow shovel"])
        XCTAssertEqual(lib.sometimes(listId: swimId), ["Wetsuit"], "a thing not on the list cannot be 'sometimes'")
    }

    func testTheyStartSkippedAndOutOfTheCount() {
        var lib = library()
        _ = lib.setSometimes(listId: swimId, names: ["Wetsuit", "Safety buoy"])
        let items = lib.grabLists().first { $0.id == swimId }!.items

        let opening = lib.openingState(listId: swimId, held: nil)
        XCTAssertEqual(Set(opening.skipped), ["Wetsuit", "Safety buoy"])
        XCTAssertEqual(opening.active(items).count, items.count - 2, "the skipped ones are out of today's list")
        XCTAssertFalse(opening.isComplete(items), "nothing is in hand yet")

        // Everything else in hand = done, even though two are skipped.
        var state = opening
        state.done = opening.active(items)
        XCTAssertTrue(state.isComplete(items), "a list is complete when what he is taking is in hand")
    }

    func testASessionUnderWayIsNotReset() {
        var lib = library()
        _ = lib.setSometimes(listId: swimId, names: ["Wetsuit"])
        var mine = lib.openingState(listId: swimId, held: nil)
        mine.skipped.removeAll { $0 == "Wetsuit" }          // he brought it in today
        mine.done = ["Goggles"]

        let again = lib.openingState(listId: swimId, held: mine)
        XCTAssertEqual(again.done, ["Goggles"], "his ticks were thrown away")
        XCTAssertFalse(again.skipped.contains("Wetsuit"), "the thing he brought in jumped back out")
    }

    func testAStaleSessionStartsOverWithTheDefaultsBack() {
        var lib = library()
        _ = lib.setSometimes(listId: swimId, names: ["Wetsuit"])
        var old = lib.openingState(listId: swimId, held: nil)
        old.skipped = []                                     // yesterday he took everything
        old.done = ["Goggles"]
        old.at = Date().addingTimeInterval(-24 * 3600)       // …a day ago

        let fresh = lib.openingState(listId: swimId, held: old)
        XCTAssertTrue(fresh.done.isEmpty, "yesterday's ticks came back")
        XCTAssertEqual(fresh.skipped, ["Wetsuit"], "the default did not come back for the new session")
    }

    /// The app writes the library as records and reads it back on every change —
    /// anything that does not survive that round trip is lost the moment he looks
    /// away.
    func testTheDefaultsSurviveTheStoreRoundTrip() {
        var lib = library()
        _ = lib.setSometimes(listId: swimId, names: ["Wetsuit"])
        let again = Library(records: lib.records())
        XCTAssertEqual(again.sometimes(listId: swimId), ["Wetsuit"],
                       "the mark was lost between writing the library and reading it back")
    }

    func testTheDefaultsTravelInABackup() {
        var lib = library()
        _ = lib.setSometimes(listId: swimId, names: ["Wetsuit", "Safety buoy"])
        guard let json = try? JSONValue.parse(lib.backupData()) else { return XCTFail("the backup did not parse") }
        let (back, report) = Importer.library(from: BackupFile(json: json))
        XCTAssertTrue(report.isFaithful)
        XCTAssertEqual(Set(back.sometimes(listId: swimId)), ["Wetsuit", "Safety buoy"],
                       "what he takes only sometimes was lost in a backup")
    }
}
