import XCTest
import PackingCore
@testable import PackingLibrary

/// Grab lists by holding the app icon (0.86, his yes of 15 Oct 2026): which four sit under
/// the icon, and in what order — the four opened most recently on this device, in his Home
/// order; the first ones on Home fill in while fewer than four were opened.
final class GrabQuickActionsTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    private func titles(_ lists: [GrabDefinition]) -> [String] { lists.map(GrabOpenings.title) }

    /// Nothing opened yet on this device: the first four on Home, in Home's order.
    func testANewDeviceOffersTheFirstFourOnHome() {
        let lib = Library()
        XCTAssertEqual(GRAB_QUICK_ACTIONS, 4, "iOS shows four under an app's icon")
        XCTAssertEqual(titles(lib.quickActionGrabLists(opened: [])),
                       ["Indoor swim", "Indoor bike", "Indoor run", "Outdoor swim"],
                       "a new device does not offer the first four on Home")
    }

    /// The four opened most recently — not the fifth — and shown in Home's order, never in
    /// the order they were opened: an entry keeps its place under the icon.
    func testTheFourOpenedMostRecentlyStandInHomeOrder() {
        let lib = Library()
        let opened = ["run-out", "bike-out", "swim", "run", "bike"]          // most recent first
        XCTAssertEqual(lib.quickActionGrabLists(opened: opened).map(\.id), ["swim", "run", "bike-out", "run-out"],
                       "not the four opened most recently, or not in Home's order")
        // Opening one of the four again changes nothing he sees.
        XCTAssertEqual(lib.quickActionGrabLists(opened: GrabOpenings.opened("swim", after: opened)).map(\.id),
                       ["swim", "run", "bike-out", "run-out"], "an entry moved when its list was opened again")
    }

    /// One opened: it, and the first three on Home that are not it.
    func testFewerThanFourOpenedAreFilledFromTheFirstOnHome() {
        let lib = Library()
        XCTAssertEqual(titles(lib.quickActionGrabLists(opened: ["bike-out"])),
                       ["Indoor swim", "Indoor bike", "Indoor run", "Outdoor bike"],
                       "the one he opened is missing, or Home's first ones did not fill in")
        XCTAssertEqual(lib.quickActionGrabLists(opened: ["bike"]).map(\.id), ["swim", "bike", "run", "swim-out"],
                       "a list opened that is among the first four took two places")
    }

    /// His arrangement of Home is the order; a list waiting in Grab Lists that he opened
    /// comes after Home's.
    func testHisHomeOrderDecidesAndAWaitingListComesAfterHome() {
        var lib = Library()
        let kayak = lib.addGrabList(label: "Kayak", items: ["Paddle"])!
        // Home: Outdoor bike first, then the indoor three; the rest wait.
        XCTAssertTrue(lib.setHomeGrabLists(["bike-out", "swim", "bike", "run"]))
        XCTAssertEqual(lib.grabListsInHomeOrder().map(\.id), ["bike-out", "swim", "bike", "run", "swim-out", "run-out", kayak.id],
                       "Home's order, then the waiting ones")
        XCTAssertEqual(titles(lib.quickActionGrabLists(opened: [])), ["Outdoor bike", "Indoor swim", "Indoor bike", "Indoor run"])
        XCTAssertEqual(lib.quickActionGrabLists(opened: [kayak.id, "run", "swim-out", "bike-out"]).map(\.id),
                       ["bike-out", "run", "swim-out", kayak.id], "a waiting list did not come after Home's")
    }

    /// A list deleted since it was opened is passed over and the next most recent steps up;
    /// an id met twice counts once; a renamed list keeps its place under its new name.
    func testAListGoneIsPassedOverAndARenamedOneFollows() {
        var lib = Library()
        let kayak = lib.addGrabList(label: "Kayak", items: ["Paddle"])!
        let padel = lib.addGrabList(label: "Padel", items: ["Racket"])!
        let opened = [kayak.id, padel.id, padel.id, "run-out", "own-gone", "swim-out", "bike"]
        XCTAssertEqual(lib.quickActionGrabLists(opened: opened).map(\.id), ["swim-out", "run-out", kayak.id, padel.id])
        XCTAssertTrue(lib.deleteOwnGrabList(id: kayak.id))
        XCTAssertEqual(lib.quickActionGrabLists(opened: opened).map(\.id), ["bike", "swim-out", "run-out", padel.id],
                       "the deleted list's place did not go to the next one opened")
        var renamed = padel
        renamed.label = "Tennis"; renamed.title = "Tennis club"
        XCTAssertTrue(lib.saveOwnGrabList(renamed))
        XCTAssertEqual(titles(lib.quickActionGrabLists(opened: opened)), ["Indoor bike", "Outdoor swim", "Outdoor run", "Tennis club"],
                       "the renamed list does not carry its new name")
    }

    /// A list with no title carries the word on its tile; fewer than four lists, fewer entries.
    func testTitlesAndAShortLibrary() {
        let bare = GrabDefinition(id: "own-1", label: "Gym", title: "", tone: "blue", icon: "", items: ["Shoes"])
        XCTAssertEqual(GrabOpenings.title(bare), "Gym")
        XCTAssertTrue(Library().quickActionGrabLists(opened: ["swim"], count: 0).isEmpty)
        XCTAssertEqual(Library().quickActionGrabLists(opened: ["run-out"], count: 2).map(\.id), ["swim", "run-out"])
    }

    /// This device's record: the list opened goes first, each list once, sixteen at most.
    func testTheRecordOfOpenings() {
        XCTAssertEqual(GrabOpenings.opened("bike", after: ["swim", "bike", "run"]), ["bike", "swim", "run"])
        XCTAssertEqual(GrabOpenings.opened("", after: ["swim"]), ["swim"], "an empty id was recorded")
        let many = (0..<20).map { "own-\($0)" }
        let after = GrabOpenings.opened("swim", after: many)
        XCTAssertEqual(after.count, GRAB_OPENED_KEEP, "the record grows without end")
        XCTAssertEqual(after.first, "swim")
        XCTAssertEqual(after.last, "own-14")
    }
}
