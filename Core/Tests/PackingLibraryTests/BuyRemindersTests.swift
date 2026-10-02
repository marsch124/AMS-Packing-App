import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// To buy → Apple Reminders (his idea 9, 2 Oct 2026): an open buy line is sent once;
/// a reminder ticked in the shop ticks its line here, never the other way round.
final class BuyRemindersTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    func testALineIsSentOnceAndTickedFromTheShop() {
        var lib = Library()
        let cream = lib.addToBuyList(text: "Sun cream")!
        let socks = lib.addToBuyList(text: "Socks")!
        let plasters = lib.addToBuyList(text: "Plasters")!
        _ = lib.setActionDone(true, id: plasters.id)
        let todo = lib.addAction(text: "Book the taxi")!
        XCTAssertEqual(Set(lib.buyLinesToSend().map(\.text)), ["Sun cream", "Socks"], "not only the open buy lines go")
        XCTAssertTrue(lib.markSent(actionId: cream.id, reminderId: "r-1"))
        XCTAssertTrue(lib.markSent(actionId: socks.id, reminderId: "r-2"))
        XCTAssertTrue(lib.buyLinesToSend().isEmpty, "a line already in Reminders would go again")
        XCTAssertEqual(Library(records: lib.records()).sentBuyLines().map(\.reminderId).sorted(), ["r-1", "r-2"],
                       "the stored records lost which reminder each became")
        XCTAssertEqual(lib.takeBought(reminderIds: ["r-1", "r-unknown"]), 1)
        XCTAssertEqual(lib.buyList().first { $0.id == cream.id }?.done, true, "ticked in the shop, not ticked here")
        XCTAssertEqual(lib.buyList().first { $0.id == socks.id }?.done, false, "a line not ticked in the shop was ticked")
        XCTAssertEqual(lib.takeBought(reminderIds: ["r-1"]), 0, "a line was ticked twice")
        XCTAssertFalse(lib.markSent(actionId: todo.id, reminderId: "r-9"), "a to-do is not a buy line")
    }
}
