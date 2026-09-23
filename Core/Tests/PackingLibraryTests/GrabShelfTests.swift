import XCTest
import PackingCore
@testable import PackingLibrary

/// More lists than Home can hold: six slots, his order, and a shelf where the
/// rest wait with everything they hold. Making room never deletes anything.
final class GrabShelfTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    func testAFreshLibraryShowsTheOriginalSix() {
        let lib = Library()
        XCTAssertEqual(lib.homeGrabLists().count, 6)
        XCTAssertEqual(lib.homeGrabLists().map(\.id), GRAB_FACTORY.map(\.id))
        XCTAssertTrue(lib.shelvedGrabLists().isEmpty)
        XCTAssertTrue(lib.ownGrabLists().isEmpty)
    }

    func testANewListGoesOnTheShelfNotOnHome() {
        var lib = Library()
        guard let made = lib.addGrabList(label: "Padel", items: ["Racket", "Balls", "Grip"]) else {
            return XCTFail("it was not made")
        }
        XCTAssertEqual(lib.ownGrabLists().map(\.label), ["Padel"])
        XCTAssertEqual(lib.homeGrabLists().count, 6, "Home still holds six")
        XCTAssertFalse(lib.homeGrabLists().contains { $0.id == made.id }, "it pushed something off Home by itself")
        XCTAssertEqual(lib.shelvedGrabLists().map(\.id), [made.id])
        XCTAssertEqual(lib.allGrabLists().count, 7)
    }

    func testHeChoosesTheSixAndTheirOrder() {
        var lib = Library()
        let padel = lib.addGrabList(label: "Padel", items: ["Racket"])!
        var six = GRAB_FACTORY.map(\.id)
        six[0] = padel.id                                  // Padel takes the first slot
        XCTAssertTrue(lib.setHomeGrabLists(six))
        XCTAssertEqual(lib.homeGrabLists().first?.id, padel.id)
        XCTAssertEqual(lib.homeGrabLists().count, 6)

        // …and the one that stepped back is on the shelf, whole.
        let shelved = lib.shelvedGrabLists()
        XCTAssertEqual(shelved.map(\.id), [GRAB_FACTORY[0].id])
        XCTAssertEqual(shelved[0].items, GRAB_FACTORY[0].items, "the list that stepped back lost its things")
    }

    func testSevenOnHomeIsRefused() {
        var lib = Library()
        let padel = lib.addGrabList(label: "Padel")!
        XCTAssertFalse(lib.setHomeGrabLists(GRAB_FACTORY.map(\.id) + [padel.id]),
                       "seven were allowed onto a screen that holds six")
        XCTAssertEqual(lib.homeGrabLists().count, 6)
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
        XCTAssertEqual(lib.homeGrabLists().count, 5, "the rest of his arrangement stands")
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
