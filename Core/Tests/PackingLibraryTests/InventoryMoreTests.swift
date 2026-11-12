import XCTest
import PackingCore
@testable import PackingLibrary

/// 0.121: serial scan tidy-up, Gone, other currencies, a manual kept as a PDF.
final class InventoryMoreTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    private let rates = CurrencyRates(sekPer: ["EUR": 11.0, "USD": 10.0], day: "2026-11-12")

    func testCleanSerialDropsTheLabel() {
        XCTAssertEqual(Library.cleanSerial("S/N: AB 123"), "AB 123")
        XCTAssertEqual(Library.cleanSerial("Serial No. 4512 0877"), "4512 0877")
        XCTAssertEqual(Library.cleanSerial("SNOW1"), "SNOW1")
        XCTAssertEqual(Library.cleanSerial("SN-778"), "778")
    }

    func testThePageSaveKeepsGoneAndTheManualLink() {
        let opened = newItem(name: "Drill")
        var page = opened
        Library.setGone(&page, GoneMark(on: "2026-11-12", how: .givenAway))
        Library.setManualLink(&page, "bosch.com/manual")
        var kept = opened
        kept.takePage(opened: opened, page: page)
        XCTAssertTrue(Library.isGone(kept)); XCTAssertTrue(kept.retired)
        XCTAssertEqual(Library.manualLink(kept), "bosch.com/manual")
    }

    func testGoneIsStoredClearedListedAndLeftOutOfTotals() {
        var a = newItem(name: "Bike"); a.price = 1_000; a.qtyOwned = 1
        Library.setGone(&a, GoneMark(on: "2026-03-03", how: .sold, soldFor: 1_200))
        XCTAssertTrue(a.retired)
        XCTAssertEqual(Library.gone(a), GoneMark(on: "2026-03-03", how: .sold, soldFor: 1_200))
        XCTAssertTrue(Library.goneLine(a).hasPrefix("Sold"))

        var b = newItem(name: "Lamp")
        Library.setGone(&b, GoneMark(on: "2026-05-01", how: .lost, soldFor: 99))
        XCTAssertNil(Library.gone(b)?.soldFor, "a price is kept only for a sale")
        XCTAssertTrue(Library.goneLine(b).hasPrefix("Lost"))

        var lib = Library()
        lib.items = [a, b]
        XCTAssertEqual(lib.goneThings().map(\.name), ["Lamp", "Bike"], "latest first")
        let g = Library.goneTotals(lib.goneThings(), rates: rates)
        XCTAssertEqual(g.things, 2)
        XCTAssertEqual(g.sold, 1)
        XCTAssertEqual(g.soldFor, 1_200, accuracy: 0.001)
        XCTAssertEqual(Library.totals(lib.items, today: "2026-11-12", rates: rates).things, 0, "gone things are not counted")

        Library.setGone(&a, nil)
        XCTAssertFalse(a.retired)
        XCTAssertNil(Library.gone(a))
    }

    func testCurrenciesCountAtTheRatesAndUnknownOnesAreLeftOut() {
        XCTAssertEqual(CurrencyRates.code("€"), "EUR")
        XCTAssertEqual(CurrencyRates.code(""), "SEK")
        XCTAssertEqual(CurrencyRates.code("kr"), "SEK")
        XCTAssertEqual(CurrencyRates.code("$"), "USD")

        var sek = newItem(name: "TV"); sek.price = 100; sek.qtyOwned = 1
        var eur = newItem(name: "Lamp"); eur.price = 50; eur.currency = "EUR"; eur.qtyOwned = 2
        var xyz = newItem(name: "Odd"); xyz.price = 5; xyz.currency = "XYZ"
        let t = Library.totals([sek, eur, xyz], today: "2026-11-12", rates: rates)
        XCTAssertEqual(t.things, 3)
        XCTAssertEqual(t.paid, 100 + 50 * 11 * 2, accuracy: 0.001)
        XCTAssertEqual(t.converted, 1)
        XCTAssertEqual(t.otherCurrency, 1)

        let parsed = CurrencyRates.parse(Data(#"{"date":"2026-11-12","rates":{"EUR":0.09}}"#.utf8))
        XCTAssertEqual(parsed?.sekPer["EUR"] ?? 0, 11.11, accuracy: 0.01)
        XCTAssertEqual(parsed?.day, "2026-11-12")
        XCTAssertEqual(CurrencyRates.fromStored(rates.stored), rates)
    }

    func testManualPDFIsKeptWithItsNameAndRefusesOtherBytes() {
        var lib = Library()
        let kettle = newItem(name: "Kettle")
        lib.items.append(kettle)
        let id = kettle.id
        let bytes = Data("%PDF-1.4 test".utf8)
        let p = lib.addPaperPDF(id: id, pdf: bytes, name: "Kettle manual.pdf")!
        XCTAssertEqual(p.kind, .manual)
        XCTAssertEqual(p.file, "Kettle manual")
        XCTAssertEqual(Library.papers(lib.items[0]).first?.file, "Kettle manual")
        let photo = lib.photos.first { $0.id == p.id }
        XCTAssertTrue(Library.isPDF(photo))
        XCTAssertEqual(Library.pdfBytes(photo), bytes)
        XCTAssertNil(lib.addPaperPDF(id: id, pdf: Data("hello".utf8), name: "x.pdf"), "not a PDF")
        let big = Data("%PDF".utf8) + Data(count: PAPER_PDF_MAX_BYTES)
        XCTAssertNil(lib.addPaperPDF(id: id, pdf: big, name: "big.pdf"), "over the limit")
        XCTAssertEqual(Library.papers(lib.items[0]).count, 1)
    }
}
