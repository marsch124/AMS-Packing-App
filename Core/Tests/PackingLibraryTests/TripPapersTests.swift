import XCTest
import PackingCore
@testable import PackingLibrary

/// Trip papers (0.125): booking confirmations, boarding passes and hotel details kept with a trip.
final class TripPapersTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    private func libWithTrip() -> (Library, String) {
        var lib = Library()
        let trip = newEvent(name: "Rome")
        lib.trips.append(trip)
        return (lib, trip.id)
    }

    func testPapersAreKeptKindedAndLimited() {
        var (lib, t) = libWithTrip()
        let photo = lib.addTripPaper(tripId: t, jpeg: Data([1, 2, 3]))!
        XCTAssertEqual(photo.kind, .booking)
        let pdf = lib.addTripPaperPDF(tripId: t, pdf: Data("%PDF-1.4 x".utf8), name: " Hotel Sol.PDF ")!
        XCTAssertEqual(pdf.file, "Hotel Sol", "the .pdf is stripped")
        XCTAssertNil(lib.addTripPaperPDF(tripId: t, pdf: Data("hello".utf8), name: "x.pdf"), "not a PDF")
        XCTAssertNil(lib.addTripPaper(tripId: t, jpeg: Data()), "no bytes, no paper")
        XCTAssertTrue(lib.setTripPaperKind(tripId: t, paperId: photo.id, kind: .boardingPass))
        XCTAssertEqual(Library.tripPapers(lib.trips[0]).map(\.kind), [.boardingPass, .booking])
        for _ in 2..<TRIP_PAPERS_MAX { XCTAssertNotNil(lib.addTripPaper(tripId: t, jpeg: Data([9]))) }
        XCTAssertNil(lib.addTripPaper(tripId: t, jpeg: Data([9])), "the 21st is refused")
        XCTAssertEqual(Library.tripPapers(lib.trips[0]).count, TRIP_PAPERS_MAX)
    }

    func testAPaperIsInUseAndGoesWithRemovalAndWithTheTrip() {
        var (lib, t) = libWithTrip()
        let a = lib.addTripPaper(tripId: t, jpeg: Data([1]))!
        let b = lib.addTripPaper(tripId: t, jpeg: Data([2]))!
        let later = Date().addingTimeInterval(10 * 86_400)
        XCTAssertTrue(lib.photoInUse(a.id) && lib.photoIdsInUse().contains(b.id))
        XCTAssertTrue(lib.unusedPhotos(now: later).isEmpty, "Worth a look never offers a trip paper")
        XCTAssertTrue(lib.removeTripPaper(tripId: t, paperId: a.id))
        XCTAssertFalse(lib.photos.contains { $0.id == a.id }, "a removed paper's picture goes")
        XCTAssertTrue(lib.deleteTrip(id: t))
        XCTAssertFalse(lib.photos.contains { $0.id == b.id }, "a deleted trip's papers go with it")
    }

    func testASharedTripCarriesNoPapers() {
        var (lib, t) = libWithTrip()
        let p = lib.addTripPaper(tripId: t, jpeg: Data([1, 2, 3]))!
        XCTAssertNotNil(lib.trips[0].extra[TRIP_PAPERS_KEY])
        XCTAssertNil(Library.justTheList(lib.trips[0]).extra[TRIP_PAPERS_KEY])
        let text = String(decoding: lib.shareFile(tripId: t)!.data, as: UTF8.self)
        XCTAssertFalse(text.contains(p.id), "the file holds no paper")
    }

    func testTheFoldedLine() {
        var (lib, t) = libWithTrip()
        XCTAssertEqual(Library.tripPapersLine(lib.trips[0]), "")
        let a = lib.addTripPaper(tripId: t, jpeg: Data([1]))!
        let b = lib.addTripPaper(tripId: t, jpeg: Data([2]))!
        let c = lib.addTripPaper(tripId: t, jpeg: Data([3]))!
        lib.setTripPaperKind(tripId: t, paperId: a.id, kind: .boardingPass)
        lib.setTripPaperKind(tripId: t, paperId: b.id, kind: .boardingPass)
        lib.setTripPaperKind(tripId: t, paperId: c.id, kind: .hotel)
        XCTAssertEqual(Library.tripPapersLine(lib.trips[0]), "Boarding pass \u{00D7}2 \u{00B7} Hotel")
    }
}
