import XCTest
@testable import PackingLibrary

/// The copies kept before a restore: named by world time, read out in HIS time, the
/// newest three kept (the spec pass, 2026-10-05).
final class RescueNamesTests: XCTestCase {

    private let summer = TimeZone(secondsFromGMT: 7_200)!     // two hours ahead of world time
    private let winter = TimeZone(secondsFromGMT: 3_600)!

    func testACopyIsReadOutInHisOwnTime() {
        let name = RescueNames.fileName(at: "2026-09-22T23:04:11.123Z")
        XCTAssertEqual(name, "before-restore-2026-09-22T23-04-11.123Z.json")
        // Written at 01:04 on 23 September in summer: the name holds 23:04 on the 22nd.
        XCTAssertEqual(RescueNames.when(fileName: name, timeZone: summer), "23 September, 01:04")
        XCTAssertEqual(RescueNames.when(fileName: name, timeZone: winter), "23 September, 00:04")
        XCTAssertEqual(RescueNames.when(fileName: name, timeZone: TimeZone(secondsFromGMT: 0)!), "22 September, 23:04")
        XCTAssertEqual(RescueNames.when(fileName: RescueNames.fileName(at: "2026-01-05T08:00:00.000Z"), timeZone: winter),
                       "5 January, 09:00", "the day is not zero-padded")
        // A copy written without milliseconds reads too; a name that is not one is shown as it is.
        XCTAssertEqual(RescueNames.when(fileName: "before-restore-2026-09-22T23-04-11Z.json", timeZone: summer), "23 September, 01:04")
        XCTAssertEqual(RescueNames.when(fileName: "something else.json", timeZone: summer), "something else")
    }

    func testTheNewestThreeAreKept() {
        let names = ["2026-09-22T23:04:11.123Z", "2026-10-01T07:00:00.000Z", "2026-09-30T21:15:00.000Z",
                     "2026-10-05T06:00:00.000Z", "2026-08-01T12:00:00.000Z"].map(RescueNames.fileName(at:))
        XCTAssertEqual(RescueNames.toRemove(names), [RescueNames.fileName(at: "2026-09-22T23:04:11.123Z"),
                                                     RescueNames.fileName(at: "2026-08-01T12:00:00.000Z")])
        XCTAssertEqual(RescueNames.toRemove(Array(names.prefix(3))), [], "three are all kept")
        XCTAssertEqual(RescueNames.keep, 3)
    }
}
