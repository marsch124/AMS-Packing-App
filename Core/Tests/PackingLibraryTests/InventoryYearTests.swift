import XCTest
import PackingCore
@testable import PackingLibrary

/// 0.122: Gone year by year, a serial read off a photo, the five sample things.
final class InventoryYearTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    private let rates = CurrencyRates(sekPer: ["EUR": 11.0], day: "2026-11-12")

    func testGoneByYearCountsSalesAndWhatWasLostNewestFirst() {
        var sold = newItem(name: "Bike")
        Library.setGone(&sold, GoneMark(on: "2026-03-03", how: .sold, soldFor: 100, currency: "EUR"))
        var lost = newItem(name: "Camera"); lost.price = 1_000; lost.acquired = "2025-03-03"; lost.qtyOwned = 2
        Library.setGone(&lost, GoneMark(on: "2026-03-03", how: .stolen))
        var old = newItem(name: "Lamp")
        Library.setGone(&old, GoneMark(on: "2024-01-01", how: .broken))
        let keep = newItem(name: "Kept")
        let years = Library.goneByYear([old, keep, sold, lost], rates: rates)
        XCTAssertEqual(years.map(\.year), ["2026", "2024"])
        XCTAssertEqual(years[0].things, 2)
        XCTAssertEqual(years[0].soldFor, 1_100)
        XCTAssertEqual(years[0].lostOrStolen, 1)
        XCTAssertEqual(years[0].lostWorth, 1_700, "worth on the day it went: 850 a piece × 2")
        XCTAssertEqual(years[1].words, "2024 \u{00B7} 1 gone")
    }

    func testSerialGuessTakesOnlyALabelledOne() {
        XCTAssertEqual(Library.serialGuess(["Bosch", "Model X200", "S/N: TEST-4512 0877"]), "TEST-4512 0877")
        XCTAssertEqual(Library.serialGuess(["Serial No.", "AB12345"]), "AB12345")
        XCTAssertEqual(Library.serialGuess(["Made in EU  SN 0841-77352"]), "0841-77352")
        XCTAssertNil(Library.serialGuess(["Model X200", "4 999 kr", "SNOWBOARD 2024"]))
    }

    func testSampleThingsComeOnceStayHomeAndGoAgain() {
        var lib = Library()
        XCTAssertEqual(lib.addSampleThings(pictures: ["sofa": Data([1, 2, 3])]), 5)
        XCTAssertEqual(lib.addSampleThings(), 0, "never twice")
        let samples = lib.sampleThings()
        XCTAssertEqual(samples.count, 5)
        XCTAssertTrue(samples.allSatisfy(Library.staysHome))
        let sofa = samples.first { $0.name == "Sofa" }!
        XCTAssertEqual(sofa.storage, "Living room"); XCTAssertEqual(Library.spot(sofa), "By the window")
        XCTAssertEqual(sofa.price, 8_995); XCTAssertEqual(lib.thingPhotos(id: sofa.id).count, 1)
        XCTAssertEqual(samples.first { $0.name == "Espresso machine" }?.currency, "EUR")
        XCTAssertEqual(lib.removeSampleThings(), 5)
        XCTAssertTrue(lib.sampleThings().isEmpty); XCTAssertTrue(lib.photos.isEmpty)
    }

    func testTheInsuranceListCarriesGoneThisYearAndNamesSamples() {
        var lib = Library()
        lib.addSampleThings()
        let drill = lib.sampleThings().first { $0.name == "Cordless drill" }!
        _ = lib.updateThing(id: drill.id) { Library.setGone(&$0, GoneMark(on: "2026-06-01", how: .stolen)) }
        let sofa = lib.sampleThings().first { $0.name == "Sofa" }!
        _ = lib.updateThing(id: sofa.id) { Library.setGone(&$0, GoneMark(on: "2025-06-01", how: .lost)) }
        let list = lib.insuranceList(today: "2026-11-12")
        XCTAssertEqual(list.gone.map(\.name), ["Cordless drill (sample)"], "only this year's")
        XCTAssertEqual(list.gone[0].facts.first?.label, "Went")
        XCTAssertTrue(list.gone[0].facts.contains { $0.label == "Worth when it went" })
        XCTAssertEqual(list.goneYear?.lostOrStolen, 1)
        XCTAssertTrue(list.rooms.flatMap(\.lines).allSatisfy { $0.name.hasSuffix("(sample)") })
    }
}
