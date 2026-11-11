import XCTest
import PackingCore
@testable import PackingLibrary

/// The Inventory tab (0.117): rooms with counts, no room last; warranties ending within 60 days.
final class InventoryPageTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    func testRoomsAndWarrantiesEndingSoon() {
        var lib = Library()
        lib.walkAdd(name: "Kettle", room: "Kitchen")
        lib.walkAdd(name: "Pan", room: "kitchen")
        lib.walkAdd(name: "Sofa", room: "Living room")
        var tv = newItem(name: "TV"); tv.warranty = "2026-12-01"
        var drill = newItem(name: "Drill"); drill.warranty = "2027-06-01"
        var old = newItem(name: "Radio"); old.warranty = "2026-01-01"
        lib.items += [tv, drill, old]
        let rooms = lib.inventoryRooms()
        XCTAssertEqual(rooms.last?.room, "")
        XCTAssertEqual(rooms.last?.count, 3)
        XCTAssertEqual(rooms.first { $0.room == "Kitchen" }?.count, 2)
        XCTAssertEqual(rooms.first { $0.room == "Living room" }?.count, 1)
        XCTAssertEqual(lib.warrantiesEndingSoon(today: "2026-11-11").map(\.name), ["TV"])
    }
}
