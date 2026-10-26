import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// 0.101, his list of 26 Oct 2026: Fold all on a trip, Before you go folded to one line, and the
/// To do page in parts — Priority, the others, Done. Invented data only — this repository is public.
final class ListFoldsTests: XCTestCase {

    override func setUp() { PackingEnv.freeze(at: "2026-10-26T08:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    // MARK: - Fold all

    func testFoldAllFoldsEveryHeadingOfThatSortingAndUnfoldAllOpensThem() {
        let trips: Set<String> = ["t1", "t2"]
        // One heading of t1 folded under From where, one under When, and one of t2.
        var raw = ["t1|stored|Garage", "t1|when|Packing", "t2|stored|Garage"].joined(separator: "\n")
        let headings = ["Garage", "Hall closet", "No place set"]
        XCTAssertFalse(TripFolds.allFolded(raw, trip: "t1", view: "stored", headings: headings))

        raw = TripFolds.settingAll(raw, trip: "t1", view: "stored", headings: headings, folded: true, trips: trips)
        XCTAssertTrue(TripFolds.allFolded(raw, trip: "t1", view: "stored", headings: headings))
        XCTAssertEqual(raw.split(separator: "\n").filter { $0 == "t1|stored|Garage" }.count, 1, "a fold written twice: \(raw)")
        XCTAssertTrue(TripFolds.isFolded(raw, "t1|when|Packing"), "another sorting's fold was touched")
        XCTAssertTrue(TripFolds.isFolded(raw, "t2|stored|Garage"), "another trip's fold was touched")

        raw = TripFolds.settingAll(raw, trip: "t1", view: "stored", headings: headings, folded: false, trips: trips)
        XCTAssertFalse(headings.contains { TripFolds.isFolded(raw, "t1|stored|\($0)") }, "Unfold all left a fold: \(raw)")
        XCTAssertTrue(TripFolds.isFolded(raw, "t1|when|Packing"))
        XCTAssertTrue(TripFolds.isFolded(raw, "t2|stored|Garage"))
    }

    func testFoldAllSweepsOutTheFoldsOfTripsThisDeviceNoLongerHas() {
        let raw = TripFolds.settingAll("gone|stored|Garage\ngone|beforego|folded", trip: "t1", view: "when",
                                       headings: ["Packing"], folded: true, trips: ["t1"])
        XCTAssertEqual(raw, "t1|when|Packing")
    }

    func testNothingToFoldIsNeverAllFolded() {
        XCTAssertFalse(TripFolds.allFolded("", trip: "t1", view: "when", headings: []))
    }

    // MARK: - Before you go

    func testBeforeYouGoFoldsByTheRuleUntilHeChoosesAndThenByHisChoice() {
        let trips: Set<String> = ["t1", "t2"]
        // The rule (0.77): folded only when All set.
        XCTAssertFalse(TripFolds.beforeYouGoFolded("", trip: "t1", allSet: false))
        XCTAssertTrue(TripFolds.beforeYouGoFolded("", trip: "t1", allSet: true))

        // Folded with things left — and it stays folded whatever comes, until he opens it.
        var raw = TripFolds.beforeYouGoToggled("", trip: "t1", allSet: false, trips: trips)
        XCTAssertTrue(TripFolds.beforeYouGoFolded(raw, trip: "t1", allSet: false))
        XCTAssertTrue(TripFolds.beforeYouGoFolded(raw, trip: "t1", allSet: true))
        XCTAssertFalse(TripFolds.beforeYouGoFolded(raw, trip: "t2", allSet: false), "another trip took the fold")

        // Opened: open, All set or not.
        raw = TripFolds.beforeYouGoToggled(raw, trip: "t1", allSet: false, trips: trips)
        XCTAssertFalse(TripFolds.beforeYouGoFolded(raw, trip: "t1", allSet: true))
        XCTAssertEqual(raw.split(separator: "\n").count, 1, "both choices kept: \(raw)")

        // Forgotten (a tapped Charge tonight): the rule again.
        raw = TripFolds.beforeYouGoReset(raw, trip: "t1")
        XCTAssertEqual(raw, "")
        XCTAssertTrue(TripFolds.beforeYouGoFolded(raw, trip: "t1", allSet: true))
    }

    func testBeforeYouGosFoldNeitherFoldsAHeadingNorIsUndoneByFoldAll() {
        let trips: Set<String> = ["t1"]
        var raw = TripFolds.beforeYouGoToggled("", trip: "t1", allSet: false, trips: trips)
        raw = TripFolds.settingAll(raw, trip: "t1", view: "when", headings: ["Packing"], folded: true, trips: trips)
        raw = TripFolds.settingAll(raw, trip: "t1", view: "when", headings: ["Packing"], folded: false, trips: trips)
        XCTAssertTrue(TripFolds.beforeYouGoFolded(raw, trip: "t1", allSet: false), "Unfold all opened Before you go")
        XCTAssertEqual(TripFolds.without(trip: "t1", in: raw), "", "a deleted trip kept its Before you go choice")
    }

    // MARK: - The To do page in parts

    private func library() -> Library {
        var lib = Library()
        for (n, text) in ["Book the ferry", "Charge the lamp", "Print the map", "Renew the passport"].enumerated() {
            PackingEnv.freeze(at: "2026-10-26T08:0\(n):00.000Z", idPrefix: "todo\(n)-")
            lib.addAction(text: text, priority: text == "Renew the passport" ? "high" : "normal")
        }
        PackingEnv.freeze(at: "2026-10-26T08:05:00.000Z", idPrefix: "buy-")
        lib.addAction(text: "Milk", kind: "shopping")
        PackingEnv.freeze(at: "2026-10-26T09:00:00.000Z", idPrefix: "later-")
        return lib
    }

    private func id(_ lib: Library, _ text: String) -> String { lib.actions.first { $0.text == text }!.id }

    func testTheToDoPageIsPriorityThenTheOthersThenDoneInTheListsOwnOrder() {
        var lib = library()
        lib.setActionDone(true, id: id(lib, "Charge the lamp"))
        let parts = lib.toDoParts()
        XCTAssertEqual(parts.priority.map(\.text), ["Renew the passport"])
        XCTAssertEqual(parts.others.map(\.text), ["Print the map", "Book the ferry"], "newest first, as the list always was")
        XCTAssertEqual(parts.done.map(\.text), ["Charge the lamp"])
        XCTAssertEqual(parts.all, lib.sortedActions(), "the parts are not runs of the central list")
        XCTAssertEqual(parts.open, 3)
        // A priority done is done, not a priority.
        lib.setActionDone(true, id: id(lib, "Renew the passport"))
        XCTAssertEqual(lib.toDoParts().priority, [])
        XCTAssertEqual(lib.toDoParts().done.map(\.text), ["Renew the passport", "Charge the lamp"])
    }

    func testToBuyHasNoPriorityPartOnlyOpenAndBought() {
        var lib = library()
        lib.setActionPriority(true, id: id(lib, "Milk"))            // a web app line may carry one
        let parts = lib.toDoParts(kind: "shopping")
        XCTAssertEqual(parts.priority, [])
        XCTAssertEqual(parts.others.map(\.text), ["Milk"])
    }

    func testMarkingAPriorityChangesTheWebAppsOwnFieldAndStampsIt() {
        var lib = library()
        let ferry = id(lib, "Book the ferry")
        XCTAssertTrue(lib.setActionPriority(true, id: ferry))
        let a = lib.actions.first { $0.id == ferry }!
        XCTAssertEqual(a.priority, "high")
        XCTAssertEqual(a.updatedAt, "2026-10-26T09:00:00.000Z")
        XCTAssertEqual(a.json["priority"], "high", "not the web app's own key")
        XCTAssertNil(a.extra["important"], "a key of its own")
        XCTAssertEqual(lib.toDoParts().priority.map(\.text), ["Renew the passport", "Book the ferry"], "newest first among the priorities")
        XCTAssertFalse(lib.setActionPriority(true, id: ferry), "marked twice is no change")
        XCTAssertTrue(lib.setActionPriority(false, id: ferry))
        XCTAssertEqual(lib.actions.first { $0.id == ferry }!.priority, "normal")
        XCTAssertFalse(lib.setActionPriority(true, id: "no-such"))
    }

    /// The store: a to-do is one record holding its whole JSON — the priority comes back from it.
    func testAPriorityComesBackFromTheStore() {
        var lib = library()
        lib.setActionPriority(true, id: id(lib, "Book the ferry"))
        let back = Library(records: lib.records())
        XCTAssertEqual(back.actions.first { $0.text == "Book the ferry" }?.priority, "high")
        XCTAssertEqual(back.toDoParts(), lib.toDoParts())
    }

    /// A backup (the file the web app reads too) and its restore: the priority comes back.
    func testAPriorityComesBackFromABackup() throws {
        var lib = library()
        lib.setActionPriority(true, id: id(lib, "Book the ferry"))
        let data = lib.backupData(exportedAt: "2026-10-26T09:00:00.000Z")
        let json = try JSONValue.parse(data)
        let (back, report) = Importer.library(from: BackupFile(json: json))
        XCTAssertTrue(report.isFaithful, report.mismatches.joined(separator: "; "))
        XCTAssertEqual(back.actions.first { $0.text == "Book the ferry" }?.priority, "high")
        XCTAssertEqual(back.toDoParts().priority.map(\.text), ["Renew the passport", "Book the ferry"])
    }

    /// Both devices: a priority marked on a page's copy and a tick from the other device meanwhile
    /// both stay (the field-wise merge of 0.95); and the other way round.
    func testAPriorityAndATickFromTheOtherDeviceBothStay() {
        let opened = library()
        let ferry = id(opened, "Book the ferry")
        var page = opened
        page.setActionPriority(true, id: ferry)
        var live = opened
        live.setActionDone(true, id: ferry)

        let saved = live.applyingPage(from: opened, to: page)
        let a = saved.actions.first { $0.id == ferry }!
        XCTAssertEqual(a.priority, "high", "the page's priority was not handed over")
        XCTAssertTrue(a.done, "the tick from the other device was undone")

        var page2 = opened
        page2.setActionDone(true, id: ferry)
        var live2 = opened
        live2.setActionPriority(true, id: ferry)
        let saved2 = live2.applyingPage(from: opened, to: page2)
        XCTAssertEqual(saved2.actions.first { $0.id == ferry }?.priority, "high", "the other device's priority was undone")
        XCTAssertEqual(saved2.actions.first { $0.id == ferry }?.done, true)
    }
}
