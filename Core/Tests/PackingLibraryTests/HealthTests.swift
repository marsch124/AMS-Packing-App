import XCTest
import PackingCore
@testable import PackingLibrary

/// The library's own sanity check. Both real accidents took the same shape and
/// neither showed on screen: templates existing twice, and things sitting on a
/// list that is no longer there.
final class HealthTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    private func sound() -> Library {
        var lib = Library()
        var base = newList(name: "Everyday", role: "base")
        base.items = [newItem(name: "Keys"), newItem(name: "Wallet")]
        lib.saveTemplate(base)
        var sea = newList(name: "Sailing", group: "WET")
        sea.items = [newItem(name: "Life jacket")]
        lib.saveTemplate(sea)
        return lib
    }

    func testASoundLibraryHasNothingToSay() {
        XCTAssertTrue(sound().worries().isEmpty)
    }

    func testTwoLibrariesThatMetAreNoticed() {
        var lib = sound()
        // What happened on his Mac: a second copy of every template arrives with
        // different ids, so nothing overwrites and the names simply double.
        var twin = newList(name: "Sailing", group: "WET")
        twin.items = [newItem(name: "Life jacket")]
        lib.saveTemplate(twin)

        let worries = lib.worries()
        XCTAssertEqual(worries.count, 1)
        XCTAssertTrue(worries[0].says.contains("twice"), "it did not say what is wrong: '\(worries[0].says)'")
        XCTAssertEqual(worries[0].names, ["Sailing"])
    }

    func testTheNameIsJudgedTheWayTheAppJudgesNames() {
        var lib = sound()
        var shouty = newList(name: "  SAILING ", group: "WET")
        shouty.items = [newItem(name: "Flare")]
        lib.saveTemplate(shouty)
        XCTAssertEqual(lib.worries().first?.names, ["Sailing"], "spacing and capitals should not hide a twin")
    }

    func testAThingOnAListThatIsGoneIsNoticed() {
        var lib = sound()
        guard let sailing = lib.templates.first(where: { $0.name == "Sailing" }) else { return XCTFail("no list") }
        lib.templates.removeAll { $0.id == sailing.id }      // the list goes, its memberships stay
        let worries = lib.worries()
        XCTAssertEqual(worries.count, 1)
        XCTAssertTrue(worries[0].says.contains("no longer exists"), "'\(worries[0].says)'")
    }

    func testThingsOnNoListAreNotAWorry() {
        var lib = sound()
        _ = lib.addThing(name: "Spare key")            // deliberately on no list
        XCTAssertTrue(lib.worries().isEmpty, "keeping a thing loose is allowed")
    }
}
