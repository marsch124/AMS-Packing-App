import XCTest
import PackingCore
@testable import PackingLibrary

final class SettingsListsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() {
        PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES); _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    func testAListWithNoRowsIsTheFactoryOneAndHisOwnIsStored() {
        var lib = Library()
        XCTAssertEqual(lib.storagePlaces(), DEFAULT_STORAGE_LOCATIONS)
        XCTAssertEqual(lib.people().map(\.name), ["Martin", "Anna"])
        XCTAssertEqual(lib.conditions(), DEFAULT_ITEM_CONDITIONS)
        XCTAssertEqual(lib.timeline(), DEFAULT_PHASES)
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.count, 0, "nothing factory-made is ever stored")

        XCTAssertTrue(lib.setNames("places", [" Garage shelf ", "Loft", ""]))
        XCTAssertEqual(lib.storagePlaces(), ["Garage shelf", "Loft"])
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.map(\.key).sorted(), ["places:garage shelf", "places:loft"],
                       "one record per entry — that is what makes them merge between devices")
        XCTAssertTrue(lib.setNames("owners", ["Anna", "Jonas"]))
        XCTAssertEqual(lib.owners(), ["Anna", "Jonas"])
        XCTAssertFalse(lib.setNames("people", ["nope"]), "people are not a name-only list")
    }

    /// His screenshot (2026-09-26): "Whose it is" showed one name once for every
    /// thing he owns. Each owner once — his list first, then anyone a thing names
    /// who is not on the list — however many things share them.
    func testEachOwnerIsOfferedOnce() {
        var lib = Library()
        lib.setNames("owners", ["Kim", "Jonas"])
        for n in 0..<40 {
            var it = newItem(name: "Thing \(n)")
            it.ownedBy = n % 3 == 0 ? "Jonas" : (n % 3 == 1 ? " kim " : "Robin")
            lib.items.append(it)
        }
        XCTAssertEqual(lib.ownerChoices(), ["Jonas", "Kim", "Robin"],
                       "each owner once: the list's own A–Z, then one not on the list")
        XCTAssertEqual(Library().ownerChoices(), [], "nobody named anywhere, nothing offered")
    }

    func testPuttingTheFactoryListBackRemovesItsRows() {
        var lib = Library()
        lib.setNames("places", ["Garage shelf"])
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.count, 1)
        lib.setNames("places", DEFAULT_STORAGE_LOCATIONS)
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.count, 0, "back to factory = no rows, not a copy of the defaults")
        XCTAssertEqual(lib.storagePlaces(), DEFAULT_STORAGE_LOCATIONS)
    }

    func testHisOwnTimelineIsStoredAndTheLiveStepsFollow() {
        var lib = Library()
        var own = DEFAULT_PHASES
        own.append(newPhase("Load the van", own.map(\.id)))
        XCTAssertTrue(lib.setTimeline(own))
        XCTAssertEqual(lib.timeline().count, 8)
        XCTAssertEqual(PHASES.count, 8, "the live steps follow, because every item points into this list")
        XCTAssertEqual(lib.records().filter { $0.table == .phases }.count, 8)
        lib.setTimeline(DEFAULT_PHASES)
        XCTAssertEqual(lib.records().filter { $0.table == .phases }.count, 0, "the factory timeline is not data")
        XCTAssertEqual(lib.timeline(), DEFAULT_PHASES)
    }

    func testWhatIsInUseIsCounted() {
        var lib = LibraryTests.sample()
        lib.updateThing(id: lib.items[0].id) { $0.storage = "Garage shelf"; $0.ownedBy = "Anna" }
        XCTAssertEqual(lib.usesOf("places")["garage shelf"], 1)
        XCTAssertEqual(lib.usesOf("owners")["anna"], 1)
        XCTAssertGreaterThan(lib.usesOf("phases")["week"] ?? 0, 0, "trip lines and memberships count too")
        XCTAssertNil(lib.usesOf("places")["loft"])
    }
}
