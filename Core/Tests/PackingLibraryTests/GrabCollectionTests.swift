import XCTest
import PackingCore
@testable import PackingLibrary

/// More lists than Home can hold: eight places (4 × 2), his order, and Grab Lists where
/// the rest wait with everything they hold. Making room never deletes anything.
final class GrabCollectionTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    func testAFreshLibraryShowsTheOriginalSix() {
        let lib = Library()
        XCTAssertEqual(GRAB_HOME_SLOTS, 8, "Home holds 4 × 2 (his ask, 2 Oct 2026)")
        XCTAssertEqual(lib.homeGrabLists().count, 6)
        XCTAssertEqual(lib.homeGrabLists().map(\.id), GRAB_FACTORY.map(\.id))
        XCTAssertTrue(lib.waitingGrabLists().isEmpty)
        XCTAssertTrue(lib.ownGrabLists().isEmpty)
    }

    /// New lists take Home's free places; once all eight are taken, the next one
    /// waits in Grab Lists instead of pushing anything off.
    func testNewListsFillHomeThenWaitInGrabLists() {
        var lib = Library()
        let padel = lib.addGrabList(label: "Padel", items: ["Racket", "Balls", "Grip"])!
        let golf = lib.addGrabList(label: "Golf", items: ["Clubs"])!
        XCTAssertEqual(lib.homeGrabLists().map(\.id), GRAB_FACTORY.map(\.id) + [padel.id, golf.id], "free places were not filled")
        XCTAssertTrue(lib.waitingGrabLists().isEmpty)

        let kayak = lib.addGrabList(label: "Kayak", items: ["Paddle"])!
        XCTAssertEqual(lib.homeGrabLists().count, 8, "Home holds eight")
        XCTAssertFalse(lib.homeGrabLists().contains { $0.id == kayak.id }, "it pushed something off a full Home")
        XCTAssertEqual(lib.waitingGrabLists().map(\.id), [kayak.id])
        XCTAssertEqual(lib.allGrabLists().count, 9)
    }

    /// His six as he arranged them (before Home grew) stay first, in his order; the
    /// next two waiting join them.
    func testHisArrangedSixAreJoinedByTheNextTwo() {
        var lib = Library()
        let padel = lib.addGrabList(label: "Padel")!
        let golf = lib.addGrabList(label: "Golf")!
        var six = GRAB_FACTORY.map(\.id)
        six.swapAt(0, 5)
        XCTAssertTrue(lib.setHomeGrabLists(six))
        XCTAssertEqual(lib.homeGrabLists().map(\.id), six + [padel.id, golf.id])
    }

    func testHeChoosesTheEightAndTheirOrder() {
        var lib = Library()
        let own = ["Padel", "Golf", "Kayak"].map { lib.addGrabList(label: $0, items: ["\($0) thing"])! }
        var eight = [own[2].id] + GRAB_FACTORY.map(\.id) + [own[0].id]   // Kayak first; Golf left out
        XCTAssertTrue(lib.setHomeGrabLists(eight))
        XCTAssertEqual(lib.homeGrabLists().map(\.id), eight)

        // …and the one left out is waiting, whole.
        let waiting = lib.waitingGrabLists()
        XCTAssertEqual(waiting.map(\.id), [own[1].id])
        XCTAssertEqual(waiting[0].items, ["Golf thing"], "the list that stepped back lost its things")
        eight.removeLast()
        XCTAssertTrue(lib.setHomeGrabLists(eight))
        XCTAssertEqual(lib.homeGrabLists().last?.id, own[0].id, "a free place was not filled from the waiting lists in order")
    }

    func testNineOnHomeIsRefused() {
        var lib = Library()
        let own = ["Padel", "Golf", "Kayak"].map { lib.addGrabList(label: $0)! }
        XCTAssertFalse(lib.setHomeGrabLists(GRAB_FACTORY.map(\.id) + own.map(\.id)),
                       "nine were allowed onto a screen that holds eight")
        XCTAssertEqual(lib.homeGrabLists().count, 8)
    }

    func testAListOfHisOwnIsEditedAndKeepsItsThings() {
        var lib = Library()
        var padel = lib.addGrabList(label: "Padel", items: ["Racket", "Balls"])!
        padel.items = ["Racket", "Balls", "Grip", "  ", "Grip"]     // blanks and twins go
        padel.label = "Padel  "
        XCTAssertTrue(lib.saveOwnGrabList(padel))
        XCTAssertEqual(lib.ownGrabLists()[0].items, ["Racket", "Balls", "Grip"])
        XCTAssertEqual(lib.ownGrabLists()[0].label, "Padel")
    }

    func testDeletingHisOwnListTakesItOffHomeToo() {
        var lib = Library()
        let padel = lib.addGrabList(label: "Padel", items: ["Racket"])!
        _ = lib.setHomeGrabLists([padel.id] + GRAB_FACTORY.map(\.id).prefix(5))
        XCTAssertTrue(lib.homeGrabLists().contains { $0.id == padel.id })

        XCTAssertTrue(lib.deleteOwnGrabList(id: padel.id))
        XCTAssertTrue(lib.ownGrabLists().isEmpty)
        XCTAssertFalse(lib.homeGrabLists().contains { $0.id == padel.id }, "a deleted list is still on Home")
        // The rest of his arrangement stands, first and in his order; the place Padel
        // left is taken by the list that was waiting (Home never keeps a hole).
        XCTAssertEqual(Array(lib.homeGrabLists().map(\.id).prefix(5)), Array(GRAB_FACTORY.map(\.id).prefix(5)),
                       "the rest of his arrangement stands")
        XCTAssertEqual(lib.homeGrabLists().count, 6)
    }

    /// The backup is the one bridge between devices and between apps — a list of
    /// his own that a backup drops is a list he loses on the next restore.
    func testHisOwnListsTravelInABackup() {
        var lib = Library()
        let padel = lib.addGrabList(label: "Padel", tone: "green", items: ["Racket", "Balls"])!
        _ = lib.setHomeGrabLists([padel.id] + GRAB_FACTORY.map(\.id).prefix(5))

        guard let json = try? JSONValue.parse(lib.backupData()) else { return XCTFail("the backup did not parse") }
        let (back, report) = Importer.library(from: BackupFile(json: json))
        XCTAssertTrue(report.isFaithful)
        XCTAssertEqual(back.ownGrabLists().map(\.label), ["Padel"], "his own list was lost in a backup")
        XCTAssertEqual(back.ownGrabLists().first?.items, ["Racket", "Balls"])
        XCTAssertEqual(back.homeGrabLists().first?.id, padel.id, "his arrangement was lost in a backup")
    }

    func testItAllSurvivesTheStoreRoundTrip() {
        var lib = Library()
        let padel = lib.addGrabList(label: "Padel", tone: "green", items: ["Racket", "Balls"])!
        _ = lib.setHomeGrabLists([padel.id] + GRAB_FACTORY.map(\.id).prefix(5))

        let again = Library(records: lib.records())
        XCTAssertEqual(again.ownGrabLists().map(\.label), ["Padel"])
        XCTAssertEqual(again.ownGrabLists()[0].items, ["Racket", "Balls"])
        XCTAssertEqual(again.homeGrabLists().first?.id, padel.id, "his arrangement was lost")
    }
}
