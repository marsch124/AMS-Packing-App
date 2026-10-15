import XCTest
import PackingCore
@testable import PackingLibrary

/// His own small headings in a grab list (0.85) — his words, 15 Oct 2026: "How do I define the
/// small headings, and how do I group the items in the various headings? I need to be able to
/// do that, I believe." Invented names only (this repository is public).
final class GrabHeadingsTests: XCTestCase {

    /// A bike list as he would arrange it: two things above his first heading, then three
    /// headings, one of them with nothing under it yet.
    private let bike: [GrabLine] = [
        .thing("Water bottle"), .thing("- Sun cream"),
        .heading("On me"), .thing("Helmet"), .thing("❄️Gloves"),
        .heading("On the bike"), .thing("Pump"), .thing("Spare tube"),
        .heading("Empty for now"),
        .heading("After"), .thing("Towel"),
    ]

    // MARK: Reading and counting

    func testAListIsGroupedUnderHisHeadingsAndTheirThingsAreNeverHeadings() {
        let d = GrabDefinition(id: "x", label: "Bike", title: "Bike", tone: "blue", icon: "", lines: bike)
        XCTAssertEqual(d.items, ["Water bottle", "- Sun cream", "Helmet", "❄️Gloves", "Pump", "Spare tube", "Towel"],
                       "the things, in his order — and no heading among them")
        XCTAssertEqual(d.groups, [
            GrabGroup(heading: "", rows: [0, 1]),
            GrabGroup(heading: "On me", rows: [2, 3]),
            GrabGroup(heading: "On the bike", rows: [4, 5]),
            GrabGroup(heading: "After", rows: [6]),
        ], "things above the first heading under none; a heading with nothing under it not shown")
        XCTAssertTrue(d.hasHeadings)
    }

    func testAListWithoutHeadingsIsOneFlatGroupAsBefore() {
        let swim = GRAB_FACTORY[0]
        XCTAssertEqual(swim.groups, [GrabGroup(heading: "", rows: Array(0..<7))], "a list with no headings is flat")
        XCTAssertFalse(swim.hasHeadings)
        // His names that already make groups by hand stay things, exactly as typed.
        let mine = ["- Sunscreen", "❄️Hat", "## Not a heading", "#3 bottle", "Start fans"]
        XCTAssertEqual(GrabLine.lines(stored: mine), mine.map { .thing($0) }, "a name he typed was read as a heading")
        XCTAssertEqual(GrabLine.stored(GrabLine.lines(stored: mine)), mine, "his names changed on the way through")
    }

    /// Headings are never ticked, skipped or counted: the count, Still missing and "all there"
    /// read the THINGS — `items` — alone.
    func testHeadingsAreNeverCounted() {
        var lib = Library()
        XCTAssertTrue(lib.saveGrabList(id: "bike-out", lines: bike))
        let items = lib.grabList(id: "bike-out")!.items
        XCTAssertEqual(items.count, 7)
        var s = GrabState()
        XCTAssertEqual(s.active(items).count, 7, "a heading was counted as a thing to take")
        for name in items { s = s.tapped(name) }
        XCTAssertTrue(s.isComplete(items), "every thing in hand, and the headings kept it from 'all there'")
        XCTAssertEqual(GrabLine.thingCount(stored: GrabLine.stored(bike)), 7, "a shared list's count holds its headings")
        // "1 in 10" marks a thing, never a heading.
        lib.setSometimes(listId: "bike-out", names: ["On me", "Pump"])
        XCTAssertEqual(lib.sometimes(listId: "bike-out"), ["Pump"], "a heading was marked 'only sometimes'")
        XCTAssertEqual(lib.openingState(listId: "bike-out", held: nil).skipped, ["Pump"])
    }

    // MARK: Saving

    func testASaveKeepsHisHeadingsWhereHePutThem() {
        var lib = Library()
        let messy: [GrabLine] = [.heading("  On me "), .thing(" Helmet "), .thing("helmet"), .thing("  "),
                                 .heading("   "), .heading("After"), .thing("Towel"), .heading("After")]
        XCTAssertTrue(lib.saveGrabList(id: "swim", lines: messy))
        XCTAssertEqual(lib.grabList(id: "swim")?.lines,
                       [.heading("On me"), .thing("Helmet"), .heading("After"), .thing("Towel"), .heading("After")],
                       "names trimmed, a blank and a twin thing dropped; two headings may share a name")
        let long = String(repeating: "h", count: 80)
        XCTAssertTrue(lib.saveGrabList(id: "swim", lines: [.heading(long), .thing("Towel")]))
        XCTAssertEqual(lib.grabList(id: "swim")?.lines.first, .heading(String(repeating: "h", count: GRAB_HEADING_MAX)),
                       "a heading too long for a share link")
    }

    /// A list of headings and nothing to take is not a list: refused whole, and its "1 in 10"
    /// marks kept (the 0.62 rule).
    func testAListOfHeadingsAloneIsRefused() {
        var lib = Library()
        XCTAssertTrue(lib.saveGrabEdit(id: "swim", lines: [.heading("On me"), .thing("Towel"), .thing("Goggles")], sometimes: ["Goggles"]))
        XCTAssertFalse(lib.saveGrabEdit(id: "swim", lines: [.heading("On me"), .heading("After")], sometimes: []),
                       "a list of headings and no thing was saved")
        XCTAssertEqual(lib.grabList(id: "swim")?.items, ["Towel", "Goggles"])
        XCTAssertEqual(lib.sometimes(listId: "swim"), ["Goggles"], "a refused save lost the marks")
        let padel = lib.addGrabList(label: "Padel", items: ["Racket"])!
        XCTAssertFalse(lib.saveGrabList(id: padel.id, lines: [.heading("Court")]), "his own list too")
    }

    /// Removing a heading in Edit keeps its things: they join what is above.
    func testRemovingAHeadingKeepsItsThings() {
        var lib = Library()
        XCTAssertTrue(lib.saveGrabList(id: "bike-out", lines: bike))
        var lines = lib.grabList(id: "bike-out")!.lines
        lines.removeAll { $0 == .heading("On the bike") }
        XCTAssertTrue(lib.saveGrabList(id: "bike-out", lines: lines))
        let d = lib.grabList(id: "bike-out")!
        XCTAssertEqual(d.items.count, 7, "a thing went with its heading")
        XCTAssertEqual(d.groups.map(\.heading), ["", "On me", "After"])
        XCTAssertEqual(d.groups[1].rows, [2, 3, 4, 5], "Pump and the tube did not join On me")
        // …and with every heading gone, the list is flat again.
        XCTAssertTrue(lib.saveGrabList(id: "bike-out", lines: d.lines.filter { !$0.isHeading }))
        XCTAssertEqual(lib.grabList(id: "bike-out")!.groups.count, 1)
    }

    /// Today's ticks stay through a Save that adds a heading (the 5 Oct 2026 rule).
    func testAddingAHeadingKeepsTodaysTicks() {
        var lib = Library()
        let held = GrabState().tapped("Towel")
        XCTAssertTrue(lib.saveGrabList(id: "swim", lines: [.heading("Bag")] + GRAB_FACTORY[0].lines))
        let after = lib.stateAfterEdit(listId: "swim", held: held, markedBefore: [])
        XCTAssertEqual(after.done, ["Towel"], "a heading added started the list over")
    }

    // MARK: Where they are kept — every door

    /// The store (and so iCloud: a record is a row's JSON) — both kinds of list.
    func testHeadingsSurviveTheStore() {
        var lib = Library()
        XCTAssertTrue(lib.saveGrabList(id: "bike-out", lines: bike))
        let padel = lib.addGrabList(label: "Padel", items: ["Racket"])!
        XCTAssertTrue(lib.saveGrabList(id: padel.id, lines: [.heading("Court"), .thing("Racket"), .heading("After"), .thing("Shirt")]))
        let again = Library(records: lib.records())
        XCTAssertEqual(again.grabList(id: "bike-out")?.lines, GrabLine.cleaned(bike), "the factory list's headings were lost in the store")
        XCTAssertEqual(again.grabList(id: padel.id)?.lines, [.heading("Court"), .thing("Racket"), .heading("After"), .thing("Shirt")],
                       "his own list's headings were lost in the store")
        XCTAssertEqual(again.grabList(id: "bike-out")?.title, "Outdoor bike")
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.map(\.key), ["grab:bike-out"], "still one record")
    }

    /// The backup and its restore — the bridge between devices and between apps.
    func testHeadingsSurviveABackupAndItsRestore() throws {
        var lib = Library()
        XCTAssertTrue(lib.saveGrabList(id: "bike-out", lines: bike))
        let padel = lib.addGrabList(label: "Padel", items: ["Racket"])!
        XCTAssertTrue(lib.saveGrabList(id: padel.id, lines: [.heading("Court"), .thing("Racket")]))
        let json = try JSONValue.parse(lib.backupData())
        let (back, report) = Importer.library(from: BackupFile(json: json))
        XCTAssertTrue(report.isFaithful)
        XCTAssertEqual(back.grabList(id: "bike-out")?.lines, GrabLine.cleaned(bike), "a restore lost the factory list's headings")
        XCTAssertEqual(back.grabList(id: padel.id)?.lines, [.heading("Court"), .thing("Racket")], "a restore lost his own list's headings")
    }

    /// A change to ONE of his own lists rewrites them all (one record): the others keep their
    /// headings — and so does deleting one.
    func testChangingOneOwnListKeepsTheOthersHeadings() {
        var lib = Library()
        let padel = lib.addGrabList(label: "Padel", items: ["Racket"])!
        let golf = lib.addGrabList(label: "Golf", items: ["Clubs"])!
        let kayak = lib.addGrabList(label: "Kayak", items: ["Paddle"])!
        XCTAssertTrue(lib.saveGrabList(id: padel.id, lines: [.heading("Court"), .thing("Racket")]))
        XCTAssertTrue(lib.saveGrabList(id: golf.id, items: ["Clubs", "Tees"]))
        XCTAssertTrue(lib.setSometimes(listId: golf.id, names: ["Tees"]))
        XCTAssertTrue(lib.deleteOwnGrabList(id: kayak.id))
        XCTAssertEqual(lib.grabList(id: padel.id)?.lines, [.heading("Court"), .thing("Racket")],
                       "another list's change took this one's heading")
    }

    /// Share: the headings go as their own lines, and this app reads them back as headings.
    func testHeadingsTravelInAShareLinkAndComeBackAsHeadings() throws {
        var sender = Library()
        XCTAssertTrue(sender.saveGrabList(id: "bike-out", lines: bike))
        let link = try XCTUnwrap(sender.shareLink(grabId: "bike-out"))
        guard case .grab(let g)? = Library.readShared(link) else { return XCTFail("not read as a grab list") }
        XCTAssertEqual(g.items.count, 11, "the link's lines: 7 things and 4 headings")
        XCTAssertEqual(GrabLine.thingCount(stored: g.items), 7)
        var me = Library()
        let got = try XCTUnwrap(me.importGrab(g))
        XCTAssertEqual(got.lines, GrabLine.cleaned(bike), "the headings did not come back as headings")
        XCTAssertEqual(me.grabList(id: got.id)?.items.count, 7)
    }

    /// The reserved form is never a name: every way a list is read gives the heading's NAME,
    /// and no thing is ever stored in that form.
    func testTheStoredFormIsNeverShown() throws {
        var lib = Library()
        XCTAssertTrue(lib.saveGrabList(id: "bike-out", lines: bike))
        let stored = try XCTUnwrap(grabFromRows(lib.shared).first?.items)
        XCTAssertEqual(stored.filter { $0.hasPrefix(GRAB_HEADING_MARK) }.count, 4, "the headings are kept among the names")
        XCTAssertEqual(GrabLine.storedHeading("On me"), "\u{2063}## On me")
        for d in lib.allGrabLists() {
            for name in d.items + d.lines.map(\.name) + d.groups.map(\.heading) {
                XCTAssertFalse(name.unicodeScalars.contains("\u{2063}"), "'\(name)' shows the stored form")
            }
        }
        XCTAssertEqual(GrabLine.headingName(stored: "\u{2063}##"), "", "a heading without a name")
        XCTAssertEqual(GrabLine.lines(stored: ["\u{2063}##", "Towel"]), [.thing("Towel")], "a nameless heading is no line")
    }
}
