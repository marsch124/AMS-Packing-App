import XCTest
import PackingCore
@testable import PackingLibrary

final class GrabListsTests: XCTestCase {

    func testTheFactorySixAreTheWebAppsAndInItsOrder() {
        XCTAssertEqual(GRAB_FACTORY.map(\.id), ["swim", "bike", "run", "swim-out", "bike-out", "run-out"])
        XCTAssertEqual(GRAB_FACTORY[5].items.first, "Shoes")
        XCTAssertEqual(Library().grabLists(), GRAB_FACTORY, "an account with no rows shows the factory lists")
    }

    func testAnEditedListLiesOverTheFactoryOne() {
        var lib = Library()
        lib.shared = grabToRows([GrabList(json: ["id": "run-out", "items": ["Shoes", "Cap"], "label": "Trail"])])
        let lists = lib.grabLists()
        XCTAssertEqual(lists.count, 6, "still six buttons")
        let runOut = lists.first { $0.id == "run-out" }!
        XCTAssertEqual(runOut.items, ["Shoes", "Cap"])
        XCTAssertEqual(runOut.label, "Trail")
        XCTAssertEqual(runOut.title, "Outdoor run", "what he did not change stays factory")
        XCTAssertEqual(runOut.icon, "run-sun")
        XCTAssertEqual(lists.first { $0.id == "run" }, GRAB_FACTORY[2])
    }

    func testTicksAndSkipsCountTheWayTheWebAppCounts() {
        let items = ["Shoes", "Cap", "Sunglasses"]
        var s = GrabState()
        XCTAssertFalse(s.isComplete(items))
        s = s.tapped("Shoes")
        XCTAssertEqual(s.done, ["Shoes"])
        s = s.skipToggled("Cap")
        XCTAssertEqual(s.active(items), ["Shoes", "Sunglasses"])
        XCTAssertEqual(s.missing(items), ["Sunglasses"])
        s = s.tapped("Sunglasses")
        XCTAssertTrue(s.isComplete(items), "everything not skipped is in hand")
        s = s.tapped("Cap")
        XCTAssertEqual(s.skipped, [], "a tap on a skipped thing takes it along again")
        XCTAssertFalse(s.isComplete(items))
        s = s.skipToggled("Shoes")
        XCTAssertFalse(s.done.contains("Shoes"), "skipping unticks")
        XCTAssertFalse(GrabState(skipped: items, at: Date()).isComplete(items), "nothing to take is not 'all there'")
    }

    func testTicksClearThemselvesAfterSixHoursAndFollowTheItems() {
        let items = ["Shoes", "Cap"]
        let now = Date()
        let s = GrabState(done: ["Shoes", "Gone"], skipped: ["Cap"], at: now.addingTimeInterval(-3600))
        XCTAssertEqual(s.current(for: items, now: now), GrabState(done: ["Shoes"], skipped: ["Cap"], at: s.at), "an item edited away is dropped")
        XCTAssertEqual(s.current(for: items, now: now.addingTimeInterval(7 * 3600)), GrabState(), "a previous workout's ticks are gone")
    }
}

final class GrabEditingTests: XCTestCase {
    func testAnEditedListIsOneSharedRecordAndTheOthersStayFactory() {
        var lib = Library()
        XCTAssertTrue(lib.saveGrabList(id: "swim", items: ["Swim shorts", " Goggles ", "", "goggles", "Nose clip"]))
        let lists = lib.grabLists()
        XCTAssertEqual(lists[0].items, ["Swim shorts", "Goggles", "Nose clip"], "trimmed, blanks and repeats dropped")
        XCTAssertEqual(lists[0].title, "Indoor swim")
        XCTAssertEqual(Array(lists.dropFirst()), Array(GRAB_FACTORY.dropFirst()), "the other five stay factory")
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.map(\.key), ["grab:swim"], "one record, synced like any other")

        XCTAssertTrue(lib.saveGrabList(id: "swim", items: ["Towel"]))
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.count, 1, "saving again replaces, never doubles")
        XCTAssertEqual(lib.grabLists()[0].items, ["Towel"])
        XCTAssertFalse(lib.saveGrabList(id: "swim", items: ["  "]), "a list with nothing on it is refused")
        XCTAssertFalse(lib.saveGrabList(id: "no-such", items: ["Towel"]))

        // His name for a list survives an edit of its things.
        lib.shared = grabToRows([GrabList(json: ["id": "run-out", "items": ["Shoes"], "label": "Trail"])])
        XCTAssertTrue(lib.saveGrabList(id: "run-out", items: ["Shoes", "Cap"]))
        XCTAssertEqual(lib.grabLists()[5].label, "Trail")
    }
}
