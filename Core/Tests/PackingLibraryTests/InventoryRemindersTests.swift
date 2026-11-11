import XCTest
import PackingCore
@testable import PackingLibrary

/// 0.120: warranty and care reminders, "No receipt yet", the insurance list.
final class InventoryRemindersTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testWarrantyReminderIs30DaysBeforeAndNeverForPastOrRetired() {
        var lib = Library()
        var tv = newItem(name: "TV"); tv.warranty = "2027-03-03"
        lib.items.append(tv)
        let r = lib.inventoryReminders(today: "2026-11-12").filter { $0.kind == .warranty }
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.day, "2027-02-01")
        XCTAssertTrue(lib.inventoryReminders(today: "2027-02-02").filter { $0.kind == .warranty }.isEmpty)
        lib.items[0].retired = true
        XCTAssertTrue(lib.inventoryReminders(today: "2026-11-12").isEmpty)
    }

    func testCareReminderOnTheDayCareIsDue() {
        var lib = Library()
        var it = newItem(name: "Filter")
        it.maintenance = Maintenance(notes: "", intervalDays: 30, lastDone: "2026-11-01")
        lib.items.append(it)
        let r = lib.inventoryReminders(today: "2026-11-12").filter { $0.kind == .care }
        XCTAssertEqual(r.map(\.day), ["2026-12-01"])
    }

    func testNoReceiptRows() {
        var lib = Library()
        lib.items += [newItem(name: "Kettle"), newItem(name: "Pan")]
        let pan = lib.items[1].id
        lib.addPaper(id: pan, jpeg: Data([1]))
        XCTAssertEqual(lib.noReceiptRows().map(\.item.name), ["Kettle"])
    }

    func testInsuranceListRoomsFactsTotalsAndMoney() {
        var lib = Library()
        var kettle = newItem(name: "Kettle"); kettle.storage = "Kitchen"; kettle.manufacturer = "Bosch"; kettle.price = 500
        var sofa = newItem(name: "Sofa"); sofa.storage = "Living room"
        lib.items += [kettle, sofa]
        let l = lib.insuranceList(today: "2026-11-12")
        XCTAssertEqual(l.rooms.count, 2)
        XCTAssertEqual(l.totals.things, 2)
        let k = l.rooms.flatMap(\.lines).first { $0.name == "Kettle" }!
        let labels = k.facts.map(\.label)
        XCTAssertTrue(labels.contains("Brand") && labels.contains("Price"))
        XCTAssertEqual(Library.moneyWords(12500), "12\u{00A0}500 kr")
    }
}
