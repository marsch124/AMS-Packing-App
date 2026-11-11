import XCTest
import PackingCore
@testable import PackingLibrary

/// Papers (0.119): receipts and manuals kept with a thing, a kind each, the manual's link.
final class PapersTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    func testPapersAreKeptKindedRemovedAndGoWithTheThing() {
        var lib = Library()
        let kettle = newItem(name: "Kettle")
        lib.items.append(kettle)
        let id = kettle.id
        let r = lib.addPaper(id: id, jpeg: Data([1, 2, 3]))!
        let m = lib.addPaper(id: id, jpeg: Data([4]), kind: .manual)!
        XCTAssertNil(lib.addPaper(id: id, jpeg: Data()), "no bytes, no paper")
        XCTAssertEqual(lib.thingPapers(id: id).map(\.paper.kind), [.receipt, .manual])
        XCTAssertTrue(lib.thingPhotoIds(id: id).isEmpty, "papers are not the thing's photos")
        XCTAssertTrue(lib.photoInUse(r.id) && lib.photoIdsInUse().contains(m.id), "a paper is in use")
        XCTAssertTrue(lib.setPaperKind(id: id, paperId: r.id, kind: .deliveryNote))
        XCTAssertEqual(Library.papersLine(lib.items[0]), "Delivery note · Manual")
        XCTAssertTrue(lib.removePaper(id: id, paperId: r.id))
        XCTAssertFalse(lib.photos.contains { $0.id == r.id }, "a removed paper's picture goes")
        for _ in 1..<THING_PAPERS_MAX { lib.addPaper(id: id, jpeg: Data([9])) }
        XCTAssertNil(lib.addPaper(id: id, jpeg: Data([9])), "twelve at most")

        var it = lib.items[0]
        Library.setManualLink(&it, "  sony.com/manual  ")
        XCTAssertEqual(Library.manualLink(it), "sony.com/manual")
        XCTAssertEqual(Library.manualURL(it)?.absoluteString, "https://sony.com/manual")
        Library.setManualLink(&it, "not a link")
        XCTAssertNil(Library.manualURL(it))

        XCTAssertTrue(lib.deleteThing(id: id))
        XCTAssertFalse(lib.photos.contains { $0.id == m.id }, "a deleted thing's papers go with it")
    }
}
