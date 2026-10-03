import XCTest
@testable import PackingCore
@testable import PackingLibrary

final class WorkbookTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// The ZIP's checksum is the standard one ("123456789" → CBF43926), or Excel
    /// calls the file damaged.
    func testTheChecksumIsTheStandardOne() {
        XCTAssertEqual(Xlsx.crc32(Array("123456789".utf8)), 0xCBF4_3926)
        XCTAssertEqual(Xlsx.crc32([]), 0)
    }

    func testColumnsAndSheetNamesFollowExcelsRules() {
        XCTAssertEqual([0, 1, 25, 26, 27, 701, 702].map(Xlsx.colLetter), ["A", "B", "Z", "AA", "AB", "ZZ", "AAA"])
        XCTAssertEqual(Xlsx.sheetName("Run: swim / bike [race]?"), "Run  swim   bike  race")
        XCTAssertEqual(Xlsx.sheetName(String(repeating: "x", count: 40)).count, 31)
        XCTAssertEqual(Xlsx.sheetName("  "), "Trip")
        XCTAssertEqual(Library.workbookFileName("Weekend in the hills"), "Weekend in the hills packing list.xlsx")
        XCTAssertEqual(Library.workbookFileName("Run/swim: Finspång"), "Run swim  Finspång packing list.xlsx")
        XCTAssertEqual(Library.workbookFileName(""), "Trip packing list.xlsx")
    }

    /// The trip as he packs it: by When, then by bag; How many as he packs it
    /// (per night × nights, capped at 4 with laundry); ticked says yes, set aside
    /// says so; his words escaped, not broken. And the file is a sound .xlsx.
    func testATripBecomesASoundWorkbook() throws {
        var lib = Library()
        var trip = newEvent(name: "Run & swim", startDate: "2026-10-01", endDate: "2026-10-08")
        trip.nights = 7
        trip.laundry = true
        var socks = newItem(name: "Socks"); socks.perNight = true; socks.container = "Duffel bag"; socks.phase = "week"
        socks.category = "Clothing"
        socks.storage = "Bedroom drawer"
        socks.checked = true
        var gels = newItem(name: "Gels <mango>"); gels.qty = "3"; gels.container = "Day pack"; gels.phase = "week"
        gels.note = "Two for the run & one spare"
        gels.category = "Food & drink"
        var cap = newItem(name: "Swim cap"); cap.skipped = true; cap.container = "Day pack"; cap.phase = "week"
        cap.category = ""
        trip.entries = [socks, gels, cap]
        lib.trips = [trip]

        let made = try XCTUnwrap(lib.tripWorkbook(tripId: trip.id))
        XCTAssertEqual(made.fileName, "Run & swim packing list.xlsx")
        XCTAssertNil(lib.tripWorkbook(tripId: "nope"))

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wb-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("t.xlsx")
        try made.data.write(to: file)

        // unzip checks every entry against its checksum; a broken ZIP fails here.
        XCTAssertEqual(try run("/usr/bin/unzip", ["-tq", file.path]).status, 0, "the ZIP is not sound")
        let list = try run("/usr/bin/unzip", ["-Z1", file.path]).out
        for part in ["[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels",
                     "xl/styles.xml", "xl/worksheets/sheet1.xml"] {
            XCTAssertTrue(list.contains(part), "missing \(part)")
        }
        let sheet = try run("/usr/bin/unzip", ["-p", file.path, "xl/worksheets/sheet1.xml"]).out
        XCTAssertTrue(sheet.contains(">When<") && sheet.contains(">How many<"), "no header row")
        // D.23: where it comes from at home, and the bag it goes into.
        XCTAssertTrue(sheet.contains(">From where<") && sheet.contains(">Into<"), "no From where / Into columns")
        XCTAssertFalse(sheet.contains(">Bag<"), "the bag column still says Bag, not Into")
        // Their words (field test, 3 Oct 2026): "Please add a category to the Excel export as a new
        // column." — the kind of thing, right after the Thing column.
        let header = rowsOf(sheet)[0]
        XCTAssertEqual(["A", "B", "C", "D", "E", "F", "G", "H"].map { cellText(header, "\($0)1") },
                       ["When", "From where", "Into", "Thing", "Category", "How many", "Packed", "Note"],
                       "the columns are not as they should be: \(header)")
        XCTAssertTrue(sheet.contains("state=\"frozen\""), "the header row does not stay in place")
        XCTAssertTrue(sheet.contains("Gels &lt;mango&gt;"), "his words are not escaped")
        XCTAssertTrue(sheet.contains("Two for the run &amp; one spare"))
        XCTAssertTrue(sheet.contains(">set aside<"), "a set-aside line does not say so")
        let book = try run("/usr/bin/unzip", ["-p", file.path, "xl/workbook.xml"]).out
        XCTAssertTrue(book.contains("name=\"Run &amp; swim\""), "the sheet is not named after the trip")

        // The rows, read back in the trip screen's order: by bag, in the app's bag
        // order (Duffel bag before Day pack) — Socks capped at 4 by the laundry.
        let rows = rowsOf(sheet)
        XCTAssertEqual(rows.count, 4, "a header and three lines")
        XCTAssertTrue(rows[1].contains("Socks") && rows[1].contains("<v>4</v>") && rows[1].contains(">yes<"),
                      "per night is not capped by the laundry, or the tick is lost: \(rows[1])")
        XCTAssertTrue(rows[1].contains(">Bedroom drawer<") && rows[1].contains(">Duffel bag<"),
                      "a line does not say where it comes from and what it goes into: \(rows[1])")
        XCTAssertTrue(rows[2].contains("Gels") && rows[2].contains("<v>3</v>"), "the order is not the trip's: \(rows)")
        XCTAssertTrue(rows[3].contains("Swim cap") && rows[3].contains(">set aside<"))
        // Each line says what kind of thing it is, in the Category column; a thing never given one
        // says the app's own default, as the trip screen sorts it.
        XCTAssertEqual(cellText(rows[1], "E2"), "Clothing", "the socks do not say their category: \(rows[1])")
        XCTAssertEqual(cellText(rows[2], "E3"), "Food &amp; drink", "the gels do not say their category: \(rows[2])")
        XCTAssertEqual(cellText(rows[3], "E4"), CATEGORY_DEFAULT.replacingOccurrences(of: "&", with: "&amp;"),
                       "a thing with no category set says nothing: \(rows[3])")

        // Without laundry, Socks count every night.
        lib.trips[0].laundry = false
        let plain = try XCTUnwrap(lib.tripWorkbook(tripId: trip.id))
        try plain.data.write(to: file)
        let again = rowsOf(try run("/usr/bin/unzip", ["-p", file.path, "xl/worksheets/sheet1.xml"]).out)
        XCTAssertTrue(again[1].contains("<v>7</v>"), "per night does not count the nights: \(again[1])")
    }

    /// The words in one cell of a row, by its reference ("E2"); nil when the cell is empty.
    private func cellText(_ row: String, _ ref: String) -> String? {
        guard let start = row.range(of: "<c r=\"\(ref)\""),
              let open = row.range(of: "<t xml:space=\"preserve\">", range: start.upperBound..<row.endIndex),
              let close = row.range(of: "</t>", range: open.upperBound..<row.endIndex) else { return nil }
        // The cell's own words only — not the next cell's, when this one has none.
        if let next = row.range(of: "<c r=", range: start.upperBound..<row.endIndex), next.lowerBound < open.lowerBound { return nil }
        return String(row[open.upperBound..<close.lowerBound])
    }

    private func rowsOf(_ xml: String) -> [String] {
        xml.components(separatedBy: "<row ").dropFirst().map { String($0.prefix { $0 != "\u{0}" }) }
    }

    private func run(_ tool: String, _ args: [String]) throws -> (status: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
