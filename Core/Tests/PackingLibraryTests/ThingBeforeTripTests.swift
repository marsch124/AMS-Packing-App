import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Before a trip (0.104 — his mix of sketches A and C, 28 Oct 2026): folded, the frame on a thing's
/// page is one line that says what is set, in the frame's order. Invented names only.
final class ThingBeforeTripTests: XCTestCase {
    private func said(battery: Bool = false, with: [String] = [], reminders: Int = 0, liquid: Bool = false,
                      cabin: Bool = false, until: String = "") -> String {
        BeforeATrip.summary(battery: battery, alsoPack: with, reminders: reminders, liquid: liquid,
                            notInCabin: cabin, validUntil: until, today: "2026-10-28")
    }

    func testNothingSetSaysSo() {
        XCTAssertEqual(said(), "Nothing set")
        XCTAssertEqual(said(with: ["  "], until: "soon"), "Nothing set", "a blank name or a date that is none is nothing")
    }

    func testEverythingSetReadsInTheFramesOrder() {
        XCTAssertEqual(said(battery: true, with: ["Charger"], reminders: 1, liquid: true, cabin: true, until: "2027-06-30"),
                       "Battery \u{00B7} Also pack Charger \u{00B7} 1 reminder \u{00B7} Liquid \u{00B7} Not in the cabin \u{00B7} until 30 Jun 2027")
    }

    func testOneThingIsNamedAndMoreAreCounted() {
        XCTAssertEqual(said(with: ["USB-C cable", "Spare battery"], reminders: 2), "Also pack 2 things \u{00B7} 2 reminders")
        XCTAssertEqual(said(with: ["Charger", "", "Pouch"]), "Also pack 2 things", "a blank name is not counted")
    }

    func testADatePastSaysItRanOut() {
        XCTAssertEqual(said(until: "2026-10-03"), "ran out 3 Oct 2026")
        XCTAssertEqual(said(until: "2026-10-28"), "until 28 Oct 2026", "today is not past")
    }

    func testTheHintFollowsTheKindOfThing() {
        XCTAssertEqual(BeforeATrip.validUntilHint(category: DOCUMENTS_CATEGORY), "warns 6 months ahead")
        XCTAssertEqual(BeforeATrip.validUntilHint(category: "Toiletries"), "warns before it runs out")
    }
}
