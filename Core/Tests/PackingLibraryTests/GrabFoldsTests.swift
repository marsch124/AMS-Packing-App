import XCTest
import PackingCore
@testable import PackingLibrary

/// Done headings turn green and fold (0.87) — his yes, 15 Oct 2026: "in a grab list, when
/// everything under a heading is in hand, it turns green and folds to one line, like the groups on
/// a trip. You scroll less at the door." Invented names only (this repository is public).
final class GrabFoldsTests: XCTestCase {

    /// One thing above his first heading, then "On me" (3), "On the bike" (2), "After" (1).
    private let bike = GrabDefinition(id: "x", label: "Bike", title: "Bike", tone: "blue", icon: "", lines: [
        .thing("Check the tyres"),
        .heading("On me"), .thing("Helmet"), .thing("Gloves"), .thing("Watch"),
        .heading("On the bike"), .thing("Bottle"), .thing("Pump"),
        .heading("After"), .thing("Towel"),
    ])

    private func ticked(_ names: [String], skipped: [String] = []) -> GrabState {
        var s = GrabState()
        for n in skipped { s = s.skipToggled(n) }
        for n in names { s = s.tapped(n) }
        return s
    }

    func testAHeadingIsDoneWhenEveryThingUnderItIsInHand() {
        let on = bike.groups[1]
        XCTAssertEqual(on.heading, "On me")
        XCTAssertEqual(GrabState().progress(of: on, items: bike.items), GrabGroupProgress(inHand: 0, toTake: 3))
        let two = ticked(["Helmet", "Gloves"])
        XCTAssertEqual(two.progress(of: on, items: bike.items), GrabGroupProgress(inHand: 2, toTake: 3))
        XCTAssertFalse(two.progress(of: on, items: bike.items).done, "a heading with a thing left to take is done")
        XCTAssertFalse(bike.folds(1, two), "a heading with a thing left to take folds")
        let all = ticked(["Helmet", "Gloves", "Watch"])
        XCTAssertTrue(all.progress(of: on, items: bike.items).done, "every thing in hand, and the heading is not done")
        XCTAssertEqual(bike.foldedGroups(all, opened: []), [1], "only the done heading folds")
        // Its neighbours are not touched by it.
        XCTAssertFalse(bike.folds(2, all))
        XCTAssertFalse(bike.folds(3, all))
    }

    /// A skipped thing does not hold its heading open; a heading of skips alone is not done.
    func testASkipCountsAsDoneButSkipsAloneAreNot() {
        let s = ticked(["Bottle"], skipped: ["Pump"])
        XCTAssertEqual(s.progress(of: bike.groups[2], items: bike.items), GrabGroupProgress(inHand: 1, toTake: 1))
        XCTAssertTrue(bike.folds(2, s), "a skipped thing held its heading open")
        let skipsOnly = ticked([], skipped: ["Bottle", "Pump"])
        XCTAssertEqual(skipsOnly.progress(of: bike.groups[2], items: bike.items), GrabGroupProgress(inHand: 0, toTake: 0))
        XCTAssertFalse(bike.folds(2, skipsOnly), "a heading with nothing in hand folded — its skips could not be taken back")
    }

    /// The things above his first heading stand under none and never fold; nor does a list
    /// without headings.
    func testWhatIsUnderNoHeadingNeverFolds() {
        let s = ticked(["Check the tyres"])
        XCTAssertTrue(s.progress(of: bike.groups[0], items: bike.items).done)
        XCTAssertFalse(bike.folds(0, s), "the things above every heading folded")
        let swim = GRAB_FACTORY[0]
        let every = ticked(swim.items)
        XCTAssertTrue(every.isComplete(swim.items))
        XCTAssertEqual(swim.foldedGroups(every, opened: []), [], "a list without headings folded")
    }

    /// Opened by a tap: it stays open while done; unticked, that is forgotten, so ticked again it folds.
    func testAHeadingOpenedByHandFoldsAgainOnceDoneAgain() {
        var s = ticked(["Helmet", "Gloves", "Watch", "Towel"])
        XCTAssertEqual(bike.foldedGroups(s, opened: []), [1, 3])
        var opened: Set<Int> = [1]
        XCTAssertEqual(bike.foldedGroups(s, opened: opened), [3], "a heading opened by a tap stayed folded")
        opened = bike.keptOpen(opened, s)
        XCTAssertEqual(opened, [1], "a done heading opened by hand was folded again by a change elsewhere")
        s = s.tapped("Gloves")                                       // unticked
        opened = bike.keptOpen(opened, s)
        XCTAssertEqual(opened, [], "a heading no longer done is still remembered as opened")
        XCTAssertEqual(bike.foldedGroups(s, opened: opened), [3], "an unticked thing is hidden")
        s = s.tapped("Gloves")                                       // ticked again
        XCTAssertEqual(bike.foldedGroups(s, opened: bike.keptOpen(opened, s)), [1, 3], "done again, it did not fold")
    }

    /// A tap on a thing never hides what is still to take — whatever is folded, nothing in it is missing.
    func testNothingStillToTakeIsEverFolded() {
        var s = GrabState()
        for name in ["Helmet", "Bottle", "Gloves", "Watch", "Pump", "Towel", "Gloves", "Pump"] {
            s = s.tapped(name)
            let missing = Set(s.missing(bike.items))
            for g in bike.foldedGroups(s, opened: []) {
                let hidden = bike.groups[g].rows.map { bike.items[$0] }
                XCTAssertTrue(missing.isDisjoint(with: hidden), "after '\(name)', '\(bike.groups[g].heading)' hides a thing still to take")
            }
        }
        XCTAssertEqual(bike.foldedGroups(s, opened: []), [3], "Gloves and Pump were unticked: their headings are open")
    }
}
