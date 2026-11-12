import XCTest
import PackingCore
@testable import PackingLibrary

/// 0.124: lent to, spare parts, claim letter, Blocket ad, quarterly check, shared receipts, labels.
final class InventoryLifeTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    func testLentRemindsEveryThreeWeeksAndBackHomeClears() {
        var lib = Library()
        let d = lib.addThing(name: "Drill")!
        _ = lib.updateThing(id: d.id) { Library.setLent(&$0, LentMark(to: "Anna", on: "2026-11-01")) }
        XCTAssertEqual(lib.lentThings().count, 1)
        XCTAssertEqual(lib.lentToNames(), ["Anna"])
        let r = lib.inventoryReminders(today: "2026-11-30").filter { $0.kind == .lent }
        XCTAssertEqual(r.map(\.day), ["2026-12-13"], "21 days, then every 21 days")
        _ = lib.updateThing(id: d.id) { Library.setLent(&$0, nil) }
        XCTAssertTrue(lib.lentThings().isEmpty)
    }

    func testDuePartGoesToBuyOnceAndTickingMovesItOn() {
        var lib = Library()
        let f = lib.addThing(name: "Fridge")!
        let p = lib.addPart(thingId: f.id, name: "Water filter", months: 6, last: "2026-05-01")!
        XCTAssertTrue(lib.syncPartsToBuy(today: "2026-11-12"))
        XCTAssertFalse(lib.syncPartsToBuy(today: "2026-11-12"), "never twice")
        let line = lib.buyList().first { $0.text == "Water filter for Fridge" }!
        if let k = lib.actions.firstIndex(where: { $0.id == line.id }) { lib.actions[k].done = true; lib.actions[k].doneAt = "2026-11-20T10:00:00Z" }
        XCTAssertTrue(lib.syncPartsToBuy(today: "2026-11-21"))
        XCTAssertEqual(Library.parts(lib.items.first { $0.id == f.id }).first { $0.id == p.id }?.last, "2026-11-20")
    }

    func testClaimLetterAndSellAd() {
        var it = newItem(name: "Drill"); it.manufacturer = "Makita"; it.model = "DDF484"; it.acquired = "2024-06-10"
        it.price = 2_495; it.serial = "0841"
        XCTAssertTrue(Library.canClaim(it, today: "2026-11-12"))
        XCTAssertFalse(Library.canClaim(it, today: "2027-06-11"))
        let letter = Library.claimLetter(it, problem: "Den startar inte", today: "2026-11-12")
        XCTAssertTrue(letter.contains("Makita DDF484")); XCTAssertTrue(letter.contains("10 juni 2024"))
        XCTAssertTrue(letter.contains("Den startar inte")); XCTAssertTrue(letter.contains("konsumentköplagen"))
        let ad = Library.sellAd(it, today: "2026-11-12", rates: CurrencyRates(sekPer: [:], day: ""))
        XCTAssertEqual(ad.price % 50, 0); XCTAssertGreaterThan(ad.price, 0)
        XCTAssertTrue(ad.text.contains("nypris 2"))
    }

    func testQuarterlyCheckAsksOldThingsOnly() {
        var lib = Library()
        let old = lib.addThing(name: "Lamp")!
        _ = lib.updateThing(id: old.id) { $0.extra[CHECKED_KEY] = .string("2026-08-01"); $0.storage = "Hall" }
        _ = lib.addThing(name: "New chair")   // stamped as looked at today
        XCTAssertEqual(Library.quarterStart("2026-11-12"), "2026-10-01")
        let due = lib.toCheck(today: "2026-11-12")
        XCTAssertEqual(due.flatMap { $0.things.map(\.name) }, ["Lamp"])
        lib.stillHave([old.id], today: "2026-11-12")
        XCTAssertTrue(lib.toCheck(today: "2026-11-12").isEmpty)
        XCTAssertNotNil(lib.inventoryReminders(today: "2026-11-12").first { $0.kind == .check && $0.day == "2027-01-01" })
    }

    func testOneReceiptOnTwoThingsStaysWhileOneKeepsIt() {
        var lib = Library()
        let a = lib.addThing(name: "Sofa")!, b = lib.addThing(name: "Table")!
        let paper = lib.addPaper(id: a.id, jpeg: Data([1, 2, 3]))!
        XCTAssertEqual(lib.receiptsElsewhere(for: b.id).count, 1)
        XCTAssertTrue(lib.sharePaper(paper, to: b.id))
        XCTAssertTrue(lib.receiptsElsewhere(for: b.id).isEmpty)
        XCTAssertEqual(lib.paperAlsoOn(paper.id, besides: a.id), ["Table"])
        lib.removePaper(id: a.id, paperId: paper.id)
        XCTAssertTrue(lib.photos.contains { $0.id == paper.id }, "still on the table")
    }

    func testThingLabelCodeIsKeptUniqueAndReadBack() {
        var lib = Library()
        let a = lib.addThing(name: "Box 1")!
        let code = lib.giveThingLabelCode(id: a.id)!
        XCTAssertEqual(code.count, 4)
        XCTAssertEqual(lib.giveThingLabelCode(id: a.id), code, "kept")
        let url = URL(string: ThingLink.text(code: code))!
        XCTAssertEqual(ThingLink.code(in: url), code)
        XCTAssertEqual(lib.thingWithLabel(code)?.id, a.id)
        XCTAssertNil(ThingLink.code(in: URL(string: "AMSPACKING://P/G4R")!))
        XCTAssertNotNil(PlaceLabel.thingImage(code: code, name: "Box 1"))
    }
}
