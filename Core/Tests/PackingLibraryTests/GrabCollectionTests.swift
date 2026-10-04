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
    ///
    /// That arrangement was saved by a version before 0.46, which kept no note of
    /// the lists left off — so it is written here as THAT version wrote it. (Saved
    /// today, an arrangement leaves the others waiting: see the test below.)
    func testHisArrangedSixAreJoinedByTheNextTwo() {
        var lib = Library()
        let padel = lib.addGrabList(label: "Padel")!
        let golf = lib.addGrabList(label: "Golf")!
        var six = GRAB_FACTORY.map(\.id)
        six.swapAt(0, 5)
        lib.meta[GRAB_HOME_META] = JSONValue(six)
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

        // He takes Padel off too: Home shows SEVEN, and Padel waits beside Golf.
        // Until 4 Oct 2026 this test expected the free place to be filled from the
        // waiting lists in order — which put the list he had just taken off (or
        // Golf, which he had left off) straight back, so "Off Home" seemed to do
        // nothing. His choice now stands until he changes it.
        eight.removeLast()
        XCTAssertTrue(lib.setHomeGrabLists(eight))
        XCTAssertEqual(lib.homeGrabLists().map(\.id), eight, "a list he took off came back, or one he left off was pulled in")
        XCTAssertEqual(Set(lib.waitingGrabLists().map(\.id)), [own[0].id, own[1].id])
    }

    /// "Off Home" keeps a list off Home — it waits in Grab Lists, whole, until he
    /// puts it back; Home simply shows one tile fewer. That holds through the
    /// store (what syncs) and a backup. Only a list that is NEW since he arranged
    /// Home takes a free place by itself.
    func testAListHeTakesOffHomeStaysOff() {
        var lib = Library()
        let off = GRAB_FACTORY.map(\.id).filter { $0 != "swim" }
        XCTAssertTrue(lib.setHomeGrabLists(off))
        XCTAssertEqual(lib.homeGrabLists().map(\.id), off, "the list he took off came straight back")
        XCTAssertEqual(lib.waitingGrabLists().map(\.id), ["swim"])
        XCTAssertEqual(lib.waitingGrabLists()[0].items, GRAB_FACTORY[0].items, "it lost its things on the way")

        // It stays off on the other device (records) and after a restore.
        XCTAssertEqual(Library(records: lib.records()).homeGrabLists().map(\.id), off, "it came back through the store")
        guard let json = try? JSONValue.parse(lib.backupData()) else { return XCTFail("the backup did not parse") }
        let (back, report) = Importer.library(from: BackupFile(json: json))
        XCTAssertTrue(report.isFaithful)
        XCTAssertEqual(back.homeGrabLists().map(\.id), off, "it came back through a backup")

        // A list he makes now is new: it takes a free place. Swim keeps waiting.
        let padel = lib.addGrabList(label: "Padel", items: ["Racket"])!
        XCTAssertEqual(lib.homeGrabLists().map(\.id), off + [padel.id], "a new list did not take the free place")
        XCTAssertEqual(lib.waitingGrabLists().map(\.id), ["swim"])

        // He puts Swim back: it is on Home again, where he put it.
        XCTAssertTrue(lib.setHomeGrabLists(lib.homeGrabLists().map(\.id) + ["swim"]))
        XCTAssertEqual(lib.homeGrabLists().last?.id, "swim")
        XCTAssertTrue(lib.waitingGrabLists().isEmpty)
        XCTAssertFalse(lib.offHomeIds().contains("swim"), "a list back on Home is still marked as off")
    }

    /// The place he frees is not handed to another list: one that was waiting
    /// because Home was full keeps waiting too.
    func testThePlaceHeFreesStaysFree() {
        var lib = Library()
        let own = ["Padel", "Golf", "Kayak"].map { lib.addGrabList(label: $0, items: ["\($0) thing"])! }
        XCTAssertEqual(lib.waitingGrabLists().map(\.id), [own[2].id], "Home holds eight; the ninth waits")

        let seven = lib.homeGrabLists().map(\.id).filter { $0 != "bike" }
        XCTAssertTrue(lib.setHomeGrabLists(seven))
        XCTAssertEqual(lib.homeGrabLists().map(\.id), seven, "Kayak was pulled onto Home in the place he freed")
        XCTAssertEqual(Set(lib.waitingGrabLists().map(\.id)), ["bike", own[2].id])
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
        // The rest of his arrangement stands, in his order. The place Padel left
        // stays free: the list he left off Home (Outdoor run) is not pulled in.
        // (Until 4 Oct 2026 every free place was refilled from the waiting lists.)
        XCTAssertEqual(lib.homeGrabLists().map(\.id), Array(GRAB_FACTORY.map(\.id).prefix(5)),
                       "the rest of his arrangement does not stand, or a list he left off was pulled in")
        XCTAssertEqual(lib.waitingGrabLists().map(\.id), ["run-out"])
        // A list he makes next is new, and takes the free place.
        let golf = lib.addGrabList(label: "Golf")!
        XCTAssertEqual(lib.homeGrabLists().last?.id, golf.id)
    }

    /// A list he made himself is filled through the same door as the original six
    /// (the editor's Save) — and it sticks, through the store, like theirs. Until 4
    /// Oct 2026 that door took the original six only, so "Make" gave a list with no
    /// things and his additions to it were silently thrown away.
    func testAListOfHisOwnIsFilledThroughTheSameDoorAsTheOriginals() {
        var lib = Library()
        let padel = lib.addGrabList(label: "Padel")!
        XCTAssertTrue(padel.items.isEmpty, "Make gives an empty list")

        XCTAssertTrue(lib.saveGrabList(id: padel.id, items: ["Racket", " Balls ", "", "balls", "Grip"]),
                      "his own list could not be saved")
        let saved = lib.grabList(id: padel.id)
        XCTAssertEqual(saved?.items, ["Racket", "Balls", "Grip"], "trimmed, blanks and repeats dropped")
        XCTAssertEqual(saved?.label, "Padel", "its name changed")
        XCTAssertEqual(saved?.title, "Padel")
        XCTAssertEqual(lib.grabLists(), GRAB_FACTORY, "the original six were touched")
        XCTAssertTrue(lib.records().filter { $0.table == .shared }.isEmpty, "an own list became a web-app row")
        XCTAssertEqual(Library(records: lib.records()).grabList(id: padel.id)?.items, ["Racket", "Balls", "Grip"],
                       "the things were lost between writing the library and reading it back")

        XCTAssertFalse(lib.saveGrabList(id: padel.id, items: ["  "]), "a list emptied by blanks is refused, as for the six")
        XCTAssertEqual(lib.grabList(id: padel.id)?.items, ["Racket", "Balls", "Grip"])
        XCTAssertFalse(lib.saveGrabList(id: "own-no-such", items: ["Towel"]))
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
