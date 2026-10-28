import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A trip sorted by Template (0.74, spec 03 "Sorting and grouping"): its lines under
/// the templates they come from — a line on two templates once, under the first, "also" the other (0.106).
final class TripByTemplateTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    /// Invented: an always-packed base, Run and Bike — the Headlamp on all three, the
    /// Helmet on Bike only — and a trip with Bike ticked BEFORE Run.
    private func library(quick: Bool = false) -> (Library, String) {
        var lib = Library()
        func list(_ name: String, group: String = "", role: String = "", _ names: [String]) -> PackList {
            var l = newList(name: name, group: group, role: role)
            l.items = names.map { newItem(name: $0) }
            return l
        }
        lib.saveTemplate(list("Always packed", role: "base", ["Passport", "Headlamp"]))
        lib.saveTemplate(list("Run", group: "GA", ["Running shoes", "Headlamp"]))
        lib.saveTemplate(list("Bike", group: "GA", ["Helmet", "Headlamp"]))
        var trip = newEvent(name: "Test week")
        trip.mode = quick ? "quick" : "trip"
        trip.activities = ["Bike", "Run"].compactMap { n in lib.templates.first { $0.name == n }?.id }
        trip = lib.createTrip(trip)
        return (lib, trip.id)
    }

    private func headings(_ groups: [EntryGroup]) -> [String] { groups.map(\.label) }
    private func names(_ group: EntryGroup) -> [String] { group.entries.map(\.name) }

    /// 0.106 (his pick B, 28 Oct 2026): a line on three templates stands once, under the first in the
    /// trip's order; the other two are said on it ("also Bike, Run").
    func testALineOnSeveralTemplatesStandsOnceUnderTheFirst() {
        let (lib, id) = library()
        let trip = lib.trips[0]
        let groups = lib.linesByTemplate(tripId: id, lines: trip.entries)
        XCTAssertEqual(headings(groups), ["Always packed", "Bike", "Run"], "not the trip's template order")
        XCTAssertEqual(names(groups[0]), ["Passport", "Headlamp"])
        XCTAssertEqual(names(groups[1]), ["Helmet"], "the Headlamp stands under Bike too")
        XCTAssertEqual(names(groups[2]), ["Running shoes"], "the Headlamp stands under Run too")
        XCTAssertEqual(groups.flatMap(\.entries).filter { $0.name == "Headlamp" }.count, 1, "the Headlamp is shown more than once")
        XCTAssertEqual(trip.entries.filter { $0.name == "Headlamp" }.count, 1, "the trip holds the Headlamp twice")
        let also = lib.alsoOnTemplates(tripId: id)
        let lamp = trip.entries.first { $0.name == "Headlamp" }!
        XCTAssertEqual(also[lamp.id]?.map(\.name), ["Bike", "Run"], "the Headlamp does not say where else it is")
        XCTAssertNil(also[trip.entries.first { $0.name == "Helmet" }!.id], "a line on one template says \"also\"")
    }

    func testOneTickCountsOnce() {
        var (lib, id) = library()
        let lamp = lib.trips[0].entries.first { $0.name == "Headlamp" }!
        XCTAssertTrue(lib.setChecked(true, tripId: id, entryId: lamp.id))
        let groups = lib.linesByTemplate(tripId: id, lines: lib.trips[0].entries)
        XCTAssertEqual(groups.flatMap(\.entries).filter(\.checked).map(\.name), ["Headlamp"], "the tick shows more than once")
        XCTAssertEqual(progress(lib.trips[0].entries).done, 1, "the trip counts the shared line more than once")
    }

    func testLinesAddedOnTheTripComeLast() {
        var (lib, id) = library()
        _ = lib.addCustomLine(tripId: id, name: "Tripod")
        _ = lib.addBoughtOnSite(tripId: id, name: "Sun hat")
        var sent = newItem(name: "From a friend"); sent.custom = false
        lib.trips[0].entries.append(sent)                         // a shared trip's line: no template
        let groups = lib.linesByTemplate(tripId: id, lines: lib.trips[0].entries)
        XCTAssertEqual(groups.last?.label, Library.addedOnTheTrip)
        XCTAssertEqual(groups.last.map(names), ["Tripod", "Sun hat", "From a friend"])
        XCTAssertFalse(groups.dropLast().flatMap(\.entries).contains { $0.name == "Tripod" }, "a typed line under a template")
    }

    /// A template whose row would NOT come onto this trip (the wrong season here) does not
    /// claim the line another template brought.
    func testATemplateThatWouldNotBringTheThingDoesNotClaimIt() {
        var (lib, _) = library()
        let run = lib.templates.first { $0.name == "Run" }!.id
        let lampMem = lib.resolvedTemplate(id: run)!.items.first { $0.name == "Headlamp" }!.memId!
        _ = lib.updateMembership(memId: lampMem) { $0.seasons = ["Summer"] }
        var trip = newEvent(name: "Winter week")
        trip.season = "Winter"
        trip.activities = ["Bike", "Run"].compactMap { n in lib.templates.first { $0.name == n }?.id }
        trip = lib.createTrip(trip)
        let groups = lib.linesByTemplate(tripId: trip.id, lines: trip.entries)
        XCTAssertEqual(groups.first { $0.label == "Run" }.map(names), ["Running shoes"], "Run claims a summer-only Headlamp in winter")
        XCTAssertEqual(groups.first { $0.label == "Bike" }.map(names), ["Helmet"], "the Headlamp left Always packed")
        let lamp = trip.entries.first { $0.name == "Headlamp" }!
        XCTAssertEqual(lib.alsoOnTemplates(tripId: trip.id)[lamp.id]?.map(\.name), ["Bike"], "Run is said for a summer-only Headlamp in winter")
    }

    /// Quick: the ticked templates only — and a line whose template is no longer on the
    /// trip stands under that template's name, after the trip's own.
    func testQuickAndATemplateNoLongerOnTheTrip() {
        var (lib, id) = library(quick: true)
        XCTAssertEqual(headings(lib.linesByTemplate(tripId: id, lines: lib.trips[0].entries)), ["Bike", "Run"])
        let shoes = lib.trips[0].entries.first { $0.name == "Running shoes" }!
        _ = lib.setChecked(true, tripId: id, entryId: shoes.id)
        lib.trips[0].activities = lib.templates.filter { $0.name == "Bike" }.map(\.id)   // Run unticked, its tick kept
        let groups = lib.linesByTemplate(tripId: id, lines: lib.trips[0].entries)
        XCTAssertEqual(headings(groups), ["Bike", "Run"], "the kept line lost its template's name")
        XCTAssertEqual(groups.last.map(names), ["Running shoes"])
    }

    /// The one answer both the Template sorting and the line's icons read: per line, its
    /// templates in the trip's order, resolved (so the icon is there); none for a line
    /// added on the trip.
    func testEachLineKnowsItsTemplatesInTheTripsOrder() {
        var (lib, id) = library()
        let bike = lib.templates.first { $0.name == "Bike" }!.id
        _ = lib.setTemplateIcon(id: bike, key: "bike")
        _ = lib.addCustomLine(tripId: id, name: "Tripod")
        let from = lib.lineTemplates(tripId: id)
        func of(_ name: String) -> [String]? {
            lib.trips[0].entries.first { $0.name == name }.flatMap { from[$0.id] }?.map(\.name)
        }
        XCTAssertEqual(of("Headlamp"), ["Always packed", "Bike", "Run"])
        XCTAssertEqual(of("Helmet"), ["Bike"])
        XCTAssertEqual(of("Passport"), ["Always packed"])
        XCTAssertNil(of("Tripod"), "a line typed on the trip comes from a template")
        let helmet = lib.trips[0].entries.first { $0.name == "Helmet" }!
        XCTAssertEqual(from[helmet.id].map { $0.map(Library.icon(of:)) }, [Optional("bike")], "the icon is not read from the template")
        XCTAssertEqual(lib.lineTemplates(tripId: "nope"), [:])
    }

    func testOnlyTheLinesGivenAreGroupedAndEmptyHeadingsGo() {
        let (lib, id) = library()
        let some = lib.trips[0].entries.filter { $0.name == "Helmet" }
        XCTAssertEqual(headings(lib.linesByTemplate(tripId: id, lines: some)), ["Bike"])
        XCTAssertEqual(lib.linesByTemplate(tripId: id, lines: []), [])
    }
}
