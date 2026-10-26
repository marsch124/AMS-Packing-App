import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Sync now (his field test, 3 Oct 2026): a device checks in; the other one reads it.
final class SyncCheckInTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-03T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    func testACheckInTravelsWithTheLibraryAndKeepsTheDevicesApart() {
        var lib = Library()
        XCTAssertNil(lib.lastCheckIn(device: "iPhone"), "a check-in before any was made")
        lib.checkIn(device: "iPhone", at: "2026-10-03T11:50:00.000Z")
        lib.checkIn(device: "Mac", at: "2026-10-03T11:55:00.000Z")
        // The other device sees it: through the stored records, as iCloud carries them.
        let other = Library(records: lib.records())
        XCTAssertEqual(other.lastCheckIn(device: "iPhone"), "2026-10-03T11:50:00.000Z", "the iPhone's check-in did not travel")
        XCTAssertEqual(other.lastCheckIn(device: "Mac"), "2026-10-03T11:55:00.000Z", "one device's check-in overwrote the other's")
        // A later check-in replaces the earlier one.
        lib.checkIn(device: "iPhone", at: "2026-10-03T12:10:00.000Z")
        XCTAssertEqual(lib.lastCheckIn(device: "iPhone"), "2026-10-03T12:10:00.000Z")
    }

    /// 0.101 — his Sync details on the Mac (26 Oct 2026): "This Mac checked in 10 Oct 19:11" while it
    /// had sent and received that same morning. A check-in was written only by Sync now; now a device
    /// checks in by itself once its last one is a quarter of an hour old — and never more often.
    func testADeviceThatSyncsChecksInByItselfEveryQuarterOfAnHour() {
        func at(_ iso: String) -> Date { isoMoment(iso)! }
        var lib = Library()
        // Pressed on 10 Oct, then the Mac synced all day on the 26th: its line must not stay at 10 Oct.
        lib.checkIn(device: "Mac", at: "2026-10-10T17:11:00.000Z")
        lib.checkIn(device: "iPhone", at: "2026-10-26T09:40:00.000Z")
        XCTAssertTrue(lib.checkInIfDue(device: "Mac", now: at("2026-10-26T09:52:00.000Z")),
                      "a Mac that last checked in on 10 Oct did not check in by itself")
        XCTAssertEqual(lib.lastCheckIn(device: "Mac"), "2026-10-26T09:52:00.000Z", "the Mac's check-in did not move")
        XCTAssertEqual(lib.lastCheckIn(device: "iPhone"), "2026-10-26T09:40:00.000Z", "the Mac's check-in touched the iPhone's")
        // Not again within the quarter of an hour; at fifteen minutes, yes.
        XCTAssertFalse(lib.checkInIfDue(device: "Mac", now: at("2026-10-26T10:06:59.000Z")), "checked in again within 15 minutes")
        XCTAssertEqual(lib.lastCheckIn(device: "Mac"), "2026-10-26T09:52:00.000Z")
        XCTAssertTrue(lib.checkInDue(device: "Mac", now: at("2026-10-26T10:07:00.000Z")), "not due at fifteen minutes")
        // Never checked in: due at once. A check-in from a clock that ran ahead: due, so it cannot stand for hours.
        XCTAssertTrue(Library().checkInDue(device: "iPhone", now: at("2026-10-26T10:00:00.000Z")), "a device that never checked in is not due")
        XCTAssertTrue(lib.checkInDue(device: "iPhone", now: at("2026-10-26T09:00:00.000Z")), "a check-in from the future stands")
        XCTAssertFalse(lib.checkInDue(device: "iPhone", now: at("2026-10-26T09:39:30.000Z")), "half a minute of clock difference made it due")
        // It travels as Sync now's does: the other device reads it from the records.
        XCTAssertEqual(Library(records: lib.records()).lastCheckIn(device: "Mac"), "2026-10-26T09:52:00.000Z", "the check-in did not travel")
    }
}
