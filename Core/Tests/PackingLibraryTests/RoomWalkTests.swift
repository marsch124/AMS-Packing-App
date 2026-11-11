import XCTest
import PackingCore
@testable import PackingLibrary

/// The room walk (0.116): one thing per photo, kept in the room, × count; names guessed on the device.
final class RoomWalkTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    func testWalkAddKeepsRoomCountAndRefusesTwins() {
        var lib = Library()
        let glasses = lib.walkAdd(name: "Wine glasses", room: "kitchen", count: 6)
        XCTAssertEqual(glasses?.qtyOwned, 6)
        XCTAssertEqual(glasses?.storage, "Kitchen")              // the starter room's spelling
        XCTAssertTrue(lib.storagePlaces().contains("Kitchen"))   // joins his rooms
        let sofa = lib.walkAdd(name: "Sofa", room: "Living room", count: 0, staysHome: true)
        XCTAssertEqual(sofa?.qtyOwned, 1)
        XCTAssertTrue(Library.staysHome(sofa!))
        XCTAssertNil(lib.walkAdd(name: " wine GLASSES ", room: "Kitchen"))
        XCTAssertNil(lib.walkAdd(name: "  ", room: "Kitchen"))
    }

    func testNameGuesses() {
        let labels: [(String, Double)] = [("structure", 0.9), ("coffee_mug", 0.6), ("teapot", 0.5),
                                          ("cup", 0.4), ("kettle", 0.3), ("spoon", 0.05)]
        XCTAssertEqual(Library.nameGuesses(labels), ["Coffee mug", "Teapot", "Cup"])
        XCTAssertEqual(Library.nameGuesses(labels, have: ["teapot"]), ["Coffee mug", "Cup", "Kettle"])
        XCTAssertEqual(Library.nameGuesses([("spoon", 0.05)]), [])
    }
}
