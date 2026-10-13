import XCTest
import PackingCore
@testable import PackingLibrary

/// Travelling by (Plane / RV, neither = an ordinary trip stored as "Car") and the season a
/// trip's first day says — 0.76, his decisions of 13 Oct 2026. Invented data only — this
/// repository is public.
final class TravellingByTests: XCTestCase {

    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// At most one pill is on; the lit one goes off again — back to the ordinary "Car".
    func testATapLightsOneAndTheLitOneGoesBackToNeither() {
        XCTAssertEqual(Library.travelling("Car", tapped: "Plane"), "Plane", "Plane did not light")
        XCTAssertEqual(Library.travelling("Plane", tapped: "RV"), "RV", "RV did not take over from Plane")
        XCTAssertEqual(Library.travelling("RV", tapped: "RV"), "Car", "tapping the lit RV did not turn it off")
        XCTAssertEqual(Library.travelling("Plane", tapped: "Plane"), "Car", "tapping the lit Plane did not turn it off")
        XCTAssertEqual(Library.travelling("", tapped: "RV"), "RV")
        // Only a pill's own word lights it: Car, nothing, or a word the app does not know light neither.
        XCTAssertTrue(Library.travelLit("Plane", "Plane"))
        XCTAssertTrue(Library.travelLit("RV", "RV"))
        for word in ["Car", "", "Train", "plane"] {
            XCTAssertFalse(Library.travelLit(word, "Plane") || Library.travelLit(word, "RV"), "'\(word)' lit a pill")
        }
        XCTAssertFalse(Library.travelLit("Car", "Car"), "Car is no pill of its own any more")
        XCTAssertEqual(Library.travelPills, ["Plane", "RV"])
    }

    /// The stored words are unchanged: an ordinary trip made today packs exactly what a "Car"
    /// trip packed before, an RV trip brings the RV template, and a trip made before 0.76 reads
    /// the same.
    func testNeitherOnIsStillACarTripAndBringsWhatItAlwaysDid() {
        var lib = LibraryTests.sample()
        lib.trips = []
        var camper = newList(name: "Camper kit", role: "transport", transport: "RV")
        camper.items = [newItem(name: "Levelling blocks")]
        lib.saveTemplate(camper)
        let hiking = lib.templates.first { $0.name == "Hiking" }!
        var draft = newEvent(name: "Weekend")
        draft.activities = [hiking.id]
        draft.transport = Library.travelling(Library.travelling("Car", tapped: "RV"), tapped: "RV")   // on, then off
        XCTAssertEqual(draft.transport, "Car")
        let ordinary = lib.createTrip(draft)
        XCTAssertFalse(ordinary.entries.contains { $0.name == "Levelling blocks" }, "an ordinary trip brought the RV template")
        draft.transport = Library.travelling("Car", tapped: "RV")
        let rv = lib.createTrip(draft)
        XCTAssertTrue(rv.entries.contains { $0.name == "Levelling blocks" }, "an RV trip did not bring the RV template")
    }

    /// The line under the pills names his transport templates, read from the library — and
    /// leaves a part out when there is nothing to name.
    func testTheLineNamesTheTemplatesTheLibraryHolds() {
        var lib = LibraryTests.sample()
        XCTAssertEqual(lib.travelNote(quick: false),
                       "Leave both off for an ordinary trip. Plane adds the airport checks.",
                       "no RV template: the RV part is not left out")
        lib.saveTemplate(newList(name: "Camper kit", role: "transport", transport: "RV"))
        XCTAssertEqual(lib.travelNote(quick: false),
                       "Leave both off for an ordinary trip. Plane adds the airport checks \u{00B7} RV adds Camper kit.",
                       "the RV template is not named")
        lib.saveTemplate(newList(name: "Flight bag", role: "transport", transport: "Plane"))
        lib.saveTemplate(newList(name: "Van extras", role: "transport", transport: "RV"))
        XCTAssertEqual(lib.travelNote(quick: false),
                       "Leave both off for an ordinary trip. Plane adds Flight bag and the airport checks \u{00B7} RV adds Camper kit and Van extras.")
        // A Car template still comes on every ordinary Full trip: the line says so.
        lib.saveTemplate(newList(name: "Road kit", role: "transport", transport: "Car"))
        XCTAssertTrue(lib.travelNote(quick: false).hasPrefix("Leave both off for an ordinary trip \u{2014} it adds Road kit. "),
                      "the Car template is not named: '\(lib.travelNote(quick: false))'")
        // Quick packs no transport template: no names, the airport checks still count.
        XCTAssertEqual(lib.travelNote(quick: true), "Leave both off for an ordinary trip. Plane adds the airport checks.")
        // A template that is not a transport one, or has no transport, is never named.
        var lib2 = LibraryTests.sample()
        lib2.saveTemplate(newList(name: "RV", group: "GA"))
        lib2.saveTemplate(newList(name: "Loose", role: "transport"))
        XCTAssertEqual(lib2.travelNote(quick: false), "Leave both off for an ordinary trip. Plane adds the airport checks.")
        // Three names, and an unnamed one.
        XCTAssertEqual(Library.spoken(["A", "B", "C"]), "A, B and C")
        var lib3 = LibraryTests.sample()
        lib3.saveTemplate(newList(name: "  ", role: "transport", transport: "RV"))
        XCTAssertEqual(lib3.transportTemplateNames("RV"), "Untitled template")
    }

    /// Winter from November to March (he lives in Sweden); everything else, and no date, Summer.
    func testTheFirstDaySaysTheSeason() {
        let winter = ["2026-11-01", "2026-12-24", "2027-01-15", "2027-02-28", "2027-03-31"]
        let summer = ["2027-04-01", "2027-05-17", "2027-06-21", "2027-07-15", "2027-08-01", "2027-09-30", "2026-10-31"]
        for d in winter { XCTAssertEqual(Library.seasonFor(firstDay: d), "Winter", "\(d) is not Winter") }
        for d in summer { XCTAssertEqual(Library.seasonFor(firstDay: d), "Summer", "\(d) is not Summer") }
        for d in ["", "  ", "soon", "2026-13-01", "26-12-01", "2026-00-10"] {
            XCTAssertEqual(Library.seasonFor(firstDay: d), "Summer", "'\(d)' is not the default Summer")
        }
        XCTAssertTrue(SEASONS.contains(Library.seasonFor(firstDay: "2027-01-01")), "a season the app does not know")
    }
}
