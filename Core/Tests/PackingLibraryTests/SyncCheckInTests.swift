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
}
