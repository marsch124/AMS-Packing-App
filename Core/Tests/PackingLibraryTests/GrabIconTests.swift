import XCTest
import PackingCore
@testable import PackingLibrary

/// A grab list's icon from the template icons (0.108) — his question, 2 Nov 2026: "Regarding grab
/// lists: how do I change icons?" Stored in the list's own `icon`, "icon:<key>"; the original
/// lists keep their doodles until he picks another. Invented data only.
final class GrabIconTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    func testATemplateIconIsKeptBehindItsOwnWordSoSwimIsNotTheDoodle() {
        XCTAssertEqual(Library.grabIcon(templateKey: "plane"), "icon:plane")
        XCTAssertEqual(Library.grabTemplateIcon("icon:plane")?.label, TemplateIconCatalog.icon("plane")?.label)
        XCTAssertEqual(Library.grabTemplateIcon("icon:swim")?.key, "swim", "the template's own swimmer")
        XCTAssertNil(Library.grabTemplateIcon("swim"), "the doodle is no template icon")
        XCTAssertNil(Library.grabTemplateIcon("icon:no-such-icon"))
        XCTAssertNil(Library.grabTemplateIcon(""))
        for ok in ["", "swim", "run-sun", "icon:plane", "icon:kayak"] { XCTAssertTrue(Library.isGrabIcon(ok), ok) }
        for no in ["kite", "icon:", "icon:nope", "plane"] { XCTAssertFalse(Library.isGrabIcon(no), no) }
    }

    func testHisOwnListTakesAnIconAndGoesBackToItsInitial() {
        var lib = Library()
        let padel = lib.addGrabList(label: "Padel", items: ["Racket", "Balls"])!
        XCTAssertEqual(lib.grabList(id: padel.id)?.icon, "", "a list he made wears its initial")
        XCTAssertTrue(lib.setGrabListIcon(id: padel.id, icon: "icon:racket"))
        let now = lib.grabList(id: padel.id)!
        XCTAssertEqual(now.icon, "icon:racket")
        XCTAssertEqual(now.items, ["Racket", "Balls"], "its things stay")
        XCTAssertEqual(now.label, "Padel")
        // Kept in the list's own entry in meta — the field it always had, nothing new to sync.
        let stored = lib.meta[GRAB_OWN_META]?.arrayValue?.first { $0["id"]?.stringValue == padel.id }
        XCTAssertEqual(stored?["icon"]?.stringValue, "icon:racket")
        XCTAssertTrue(lib.setGrabListIcon(id: padel.id, icon: ""))
        XCTAssertEqual(lib.grabList(id: padel.id)?.icon, "", "Letter: its initial again")
        XCTAssertFalse(lib.setGrabListIcon(id: padel.id, icon: "icon:nope"), "an icon the app cannot draw")
        XCTAssertFalse(lib.setGrabListIcon(id: "own-gone", icon: "icon:plane"), "no such list")
    }

    func testAnOriginalListKeepsItsDoodleUntilHePicksAnother() {
        var lib = Library()
        XCTAssertTrue(lib.setGrabListIcon(id: "swim", icon: ""), "its own doodle: nothing to change")
        XCTAssertTrue(lib.setGrabListIcon(id: "swim", icon: "swim"))
        XCTAssertTrue(lib.shared.filter { $0.kind == "grab" }.isEmpty, "choosing its own doodle wrote a row")
        XCTAssertEqual(lib.grabList(id: "swim")?.icon, "swim")

        XCTAssertTrue(lib.setGrabListIcon(id: "swim", icon: "icon:wetsuit"))
        let swim = lib.grabList(id: "swim")!
        XCTAssertEqual(swim.icon, "icon:wetsuit")
        XCTAssertEqual(swim.items, GRAB_FACTORY[0].items, "its things are the original's")
        XCTAssertEqual(swim.label, "Swim")
        XCTAssertEqual(swim.tone, "blue")
        // ONE grab row, in the Home-row order the web app keeps.
        let rows = lib.shared.filter { $0.kind == "grab" }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.order, 0)
        XCTAssertEqual(grabFromRows(lib.shared).first?.icon, "icon:wetsuit")
        // The others stay as they came.
        XCTAssertEqual(lib.grabList(id: "bike")?.icon, "bike")

        // Back to its own doodle: the row says nothing of an icon, and the doodle is drawn.
        XCTAssertTrue(lib.setGrabListIcon(id: "swim", icon: ""))
        XCTAssertEqual(lib.grabList(id: "swim")?.icon, "swim")
        XCTAssertEqual(grabFromRows(lib.shared).first?.icon, "")
        XCTAssertTrue(lib.setGrabListIcon(id: "swim", icon: "icon:wetsuit"))
        XCTAssertTrue(lib.setGrabListIcon(id: "swim", icon: "swim"), "naming its doodle is the same")
        XCTAssertEqual(grabFromRows(lib.shared).first?.icon, "")
    }

    func testAnEditedOriginalListKeepsItsThingsNameAndColourWithANewIcon() {
        var lib = Library()
        XCTAssertTrue(lib.saveGrabList(id: "bike", items: ["Helmet", "Shoes"]))
        lib.shared = lib.shared.map { row in
            guard row.kind == "grab" else { return row }
            var r = row
            var data = r.data.objectValue ?? [:]
            data["label"] = .string("Spin")
            data["tone"] = .string("red")
            r.data = .object(data)
            return r
        }
        XCTAssertTrue(lib.setGrabListIcon(id: "bike", icon: "icon:pump"))
        let bike = lib.grabList(id: "bike")!
        XCTAssertEqual(bike.icon, "icon:pump")
        XCTAssertEqual(bike.items, ["Helmet", "Shoes"])
        XCTAssertEqual(bike.label, "Spin")
        XCTAssertEqual(bike.tone, "red")
        XCTAssertEqual(lib.shared.filter { $0.kind == "grab" }.count, 1, "a second row for one list")
        // A later edit of its things keeps the icon.
        XCTAssertTrue(lib.saveGrabList(id: "bike", items: ["Helmet", "Shoes", "Bottle"]))
        XCTAssertEqual(lib.grabList(id: "bike")?.icon, "icon:pump")
    }

    func testASharedListBringsItsTemplateIcon() {
        var me = Library()
        let got = me.importGrab(GrabShare(name: "Trip", icon: "icon:plane", tone: "teal", items: ["Passport"]))
        XCTAssertEqual(got?.icon, "icon:plane")
        let odd = me.importGrab(GrabShare(name: "Odd", icon: "icon:nope", tone: "teal", items: ["Thing"]))
        XCTAssertEqual(odd?.icon, "", "an icon this app does not have: the standard look")
    }
}
