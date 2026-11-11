import XCTest
import PackingCore
@testable import PackingLibrary

/// Inventory step 1 (0.115): rooms, spots, shops, stays at home, value today, warranty, totals.
final class InventoryTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testRoomsSpotsAndShops() {
        var lib = Library()
        XCTAssertTrue(lib.roomChoices().contains("Kitchen"))
        lib.keepRoom("Kitchen")
        XCTAssertTrue(lib.storagePlaces().contains("Kitchen"))
        let before = lib.storagePlaces().count
        lib.keepRoom(" kitchen ")
        XCTAssertEqual(lib.storagePlaces().count, before)
        XCTAssertEqual(lib.roomChoices().filter { normName($0) == "kitchen" }.count, 1)

        var kettle = newItem(name: "Kettle"); kettle.storage = "Kitchen"
        Library.setSpot(&kettle, "Top shelf"); Library.setShop(&kettle, "Elgiganten")
        var pan = newItem(name: "Pan"); pan.storage = "Kitchen"; Library.setSpot(&pan, "Drawer 2")
        lib.items += [kettle, pan]
        XCTAssertEqual(lib.spotSuggestions(room: "kitchen", typed: ""), ["Drawer 2", "Top shelf"])
        XCTAssertEqual(lib.spotSuggestions(room: "Kitchen", typed: "top"), ["Top shelf"])
        XCTAssertEqual(lib.shopSuggestions(typed: "elg"), ["Elgiganten"])
        XCTAssertTrue(lib.shopSuggestions(typed: "elgiganten").isEmpty)
        XCTAssertTrue(Library.detailsMatch(kettle, "elgig"))
    }

    func testStaysHomeIsNeverSuggestedOnTemplates() {
        var lib = Library()
        lib.saveTemplate(newList(name: "Hiking", group: "GA"))
        let id = lib.templates.first { $0.name == "Hiking" }!.id
        var sofa = newItem(name: "Sofa"); Library.setStaysHome(&sofa, true)
        lib.items += [sofa, newItem(name: "Socks")]
        XCTAssertEqual(lib.templateAddSuggestions(templateId: id, typed: "so").map(\.name), ["Socks"])
        XCTAssertEqual(lib.buyAddSuggestions(typed: "so").map(\.name), ["Socks", "Sofa"])
    }

    func testValueWarrantyComplaintAndTotals() {
        var tv = newItem(name: "TV"); tv.price = 10_000; tv.acquired = "2024-03-03"; tv.qtyOwned = 1
        XCTAssertEqual(Library.valueToday(tv, today: "2024-03-03"), 10_000)
        XCTAssertEqual(Library.valueToday(tv, today: "2026-03-03")!, 7_225, accuracy: 10)
        XCTAssertEqual(Library.valueToday(tv, today: "2060-01-01"), 1_000)       // never below 10 %
        Library.setValue(&tv, 5_000)
        XCTAssertEqual(Library.valueToday(tv, today: "2026-03-03"), 5_000)

        XCTAssertEqual(Library.complaintRightUntil(tv), "2027-03-03")
        tv.warranty = Library.warrantyEnd(bought: tv.acquired, years: 2)
        XCTAssertEqual(tv.warranty, "2026-03-03")
        XCTAssertEqual(Library.warrantyYears(tv), 2)
        XCTAssertEqual(Library.complaintRightUntil(tv), "")
        XCTAssertEqual(Library.addYears("2024-02-29", 1), "2025-02-28")
        XCTAssertEqual(Library.timeLeft(until: "2027-07-03", today: "2026-03-03"), "1 year 4 months left")
        XCTAssertEqual(Library.timeLeft(until: "2026-03-01", today: "2026-03-03"), "Ended")

        var glass = newItem(name: "Wine glass"); glass.price = 100; glass.qtyOwned = 6; glass.acquired = "2026-01-01"
        var euro = newItem(name: "Lamp"); euro.price = 50; euro.currency = "EUR"
        let t = Library.totals([tv, glass, euro, newItem(name: "Socks")], today: "2026-01-01")
        XCTAssertEqual(t.things, 4)
        XCTAssertEqual(t.paid, 10_600)
        XCTAssertEqual(t.today, 5_600)
        XCTAssertEqual(t.otherCurrency, 1)
    }
}
