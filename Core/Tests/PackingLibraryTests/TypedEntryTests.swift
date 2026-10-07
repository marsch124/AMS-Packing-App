import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// What a thing's page reads from the Mac's keys (0.68, his keyboard page): a weight
/// with or without its unit, and Valid until as a date or a jump from today.
final class TypedEntryTests: XCTestCase {

    func testAWeightIsGramsWithOrWithoutItsUnit() {
        XCTAssertEqual(readGrams("1200"), 1200)
        XCTAssertEqual(readGrams("1,2 kg"), 1200, "his example: a Swedish comma and kilos")
        XCTAssertEqual(readGrams("1.2kg"), 1200, "a point, the unit stuck on")
        XCTAssertEqual(readGrams("1,2 KG"), 1200, "capitals")
        XCTAssertEqual(readGrams("0,35 kilo"), 350)
        XCTAssertEqual(readGrams("250 g"), 250)
        XCTAssertEqual(readGrams("250g"), 250)
        XCTAssertEqual(readGrams("12,5"), 12.5, "no unit = grams, as the field always read")
        XCTAssertEqual(readGrams("1 200"), 1200, "a space between the thousands")
        XCTAssertEqual(readGrams(""), 0, "nothing = not known")
        XCTAssertEqual(readGrams("2.345 kg"), 2345)
    }

    func testWhatIsNoWeightIsRefused() {
        for typed in ["abc", "kg", " g", "-1", "1,2 lb", "1e3", "1,2,3 kg", "1kg2"] {
            XCTAssertNil(readGrams(typed), "'\(typed)' was read as a weight")
        }
    }

    private let today = "2026-10-07"

    func testADateIsTypedTheWaysHeWritesIt() {
        XCTAssertEqual(readDate("2027-06-30", today: today), "2027-06-30")
        XCTAssertEqual(readDate("2027-6-3", today: today), "2027-06-03")
        XCTAssertEqual(readDate("30/6 27", today: today), "2027-06-30", "his example: day/month and a short year")
        XCTAssertEqual(readDate("30/6/2027", today: today), "2027-06-30")
        XCTAssertEqual(readDate("30.6.27", today: today), "2027-06-30")
        XCTAssertEqual(readDate(" 1/2 28 ", today: today), "2028-02-01")
    }

    func testADateWithoutAYearIsTheNextOne() {
        XCTAssertEqual(readDate("30/6", today: today), "2027-06-30", "June has gone by this year")
        XCTAssertEqual(readDate("24/12", today: today), "2026-12-24", "still to come this year")
        XCTAssertEqual(readDate("7/10", today: today), "2026-10-07", "today itself")
        XCTAssertEqual(readDate("29/2", today: today), "2028-02-29", "the next year that has one")
    }

    func testAJumpFromToday() {
        XCTAssertEqual(readDate("+6m", today: today), "2027-04-07")
        XCTAssertEqual(readDate("+1y", today: today), "2027-10-07")
        XCTAssertEqual(readDate("+10y", today: today), "2036-10-07")
        XCTAssertEqual(readDate("+2w", today: today), "2026-10-21")
        XCTAssertEqual(readDate("+30d", today: today), "2026-11-06")
        XCTAssertEqual(readDate("+ 6 months", today: today), "2027-04-07", "the unit in words")
        XCTAssertEqual(readDate("+1M", today: "2027-01-31"), "2027-02-28", "a month on: the month's last day, as +1 month does")
        XCTAssertEqual(readDate("+6m", today: today), addMonths(today, 6), "the same day as the +6 months pill")
    }

    func testNothingTypedIsNoDateAndNonsenseIsRefused() {
        XCTAssertEqual(readDate("", today: today), "")
        XCTAssertEqual(readDate("   ", today: today), "")
        for typed in ["soon", "31/6 27", "30/13 27", "2027-02-30", "+6", "+m", "+6q", "30/6 270", "6", "1/2/3/4", "-6m"] {
            XCTAssertNil(readDate(typed, today: today), "'\(typed)' was read as a date")
        }
    }
}
