import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A thing's page writes only what was changed on it (0.93, the outside review of 0.92): a change
/// made on the other device while the page was open stays.
final class ThingPageSaveTests: XCTestCase {
    func testOnlyWhatThePageChangedIsWritten() {
        var opened = newItem(name: "Map")
        opened.container = "Carry-on / hand luggage"
        opened.note = ""
        opened.weight = 60
        var live = opened                                   // the other device, meanwhile
        live.container = "Checked luggage"
        live.weight = 75
        var page = opened                                   // only the notes changed here
        page.note = "Fold along the creases"

        var saved = live
        saved.takePage(opened: opened, page: page)
        XCTAssertEqual(saved.note, "Fold along the creases", "the notes typed on the page were not written")
        XCTAssertEqual(saved.container, "Checked luggage", "Save put back the bag the page opened with")
        XCTAssertEqual(saved.weight, 75, "Save put back the weight the page opened with")

        // A field changed on both: the page's, as Save is the later word.
        page.container = "Hiking backpack"
        saved = live
        saved.takePage(opened: opened, page: page)
        XCTAssertEqual(saved.container, "Hiking backpack")

        // A thing made on the page: everything is the page's.
        saved = live
        saved.takePage(opened: nil, page: page)
        XCTAssertEqual(saved.weight, 60)
        XCTAssertEqual(saved.container, "Hiking backpack")
    }
}
