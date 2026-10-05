import XCTest
import PackingCore
@testable import PackingLibrary

/// The library's own sanity check. Both real accidents took the same shape and
/// neither showed on screen: templates existing twice, and things sitting on a
/// list that is no longer there.
final class HealthTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    private func sound() -> Library {
        var lib = Library()
        var base = newList(name: "Everyday", role: "base")
        base.items = [newItem(name: "Keys"), newItem(name: "Wallet")]
        lib.saveTemplate(base)
        var sea = newList(name: "Sailing", group: "WET")
        sea.items = [newItem(name: "Life jacket")]
        lib.saveTemplate(sea)
        return lib
    }

    func testASoundLibraryHasNothingToSay() {
        XCTAssertTrue(sound().worries().isEmpty)
    }

    func testTwoLibrariesThatMetAreNoticed() {
        var lib = sound()
        // What happened on his Mac: a second copy of every template arrives with
        // different ids, so nothing overwrites and the names simply double.
        var twin = newList(name: "Sailing", group: "WET")
        twin.items = [newItem(name: "Life jacket")]
        lib.saveTemplate(twin)

        let worries = lib.worries()
        XCTAssertEqual(worries.count, 1)
        XCTAssertTrue(worries[0].says.contains("twice"), "it did not say what is wrong: '\(worries[0].says)'")
        XCTAssertEqual(worries[0].names, ["Sailing"])
    }

    func testTheNameIsJudgedTheWayTheAppJudgesNames() {
        var lib = sound()
        var shouty = newList(name: "  SAILING ", group: "WET")
        shouty.items = [newItem(name: "Flare")]
        lib.saveTemplate(shouty)
        XCTAssertEqual(lib.worries().first?.names, ["Sailing"], "spacing and capitals should not hide a twin")
    }

    func testAThingOnAListThatIsGoneIsNoticed() {
        var lib = sound()
        guard let sailing = lib.templates.first(where: { $0.name == "Sailing" }) else { return XCTFail("no list") }
        lib.templates.removeAll { $0.id == sailing.id }      // the list goes, its memberships stay
        let worries = lib.worries()
        XCTAssertEqual(worries.count, 1)
        // "Template", not "list": since 0.34 a list is only what you pack from (the spec pass, 5 Oct 2026).
        XCTAssertEqual(worries[0].says.hasSuffix("on a template that no longer exists."), true, "'\(worries[0].says)'")
    }

    func testThingsOnNoListAreNotAWorry() {
        var lib = sound()
        _ = lib.addThing(name: "Spare key")            // deliberately on no list
        XCTAssertTrue(lib.worries().isEmpty, "keeping a thing loose is allowed")
    }
}

/// A photo nothing shows and whose age cannot be read: since 0.60 never offered with
/// the old ones, it stayed for ever and nothing said so (the spec pass, 2026-10-05).
/// It is named on its own, and only a press removes it.
final class UndatedPhotoTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-04T10:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    func testAPhotoWithNoDateIsNamedOnItsOwnAndGoesOnlyWhenAsked() {
        var lib = Library()
        var thing = newItem(name: "Tent")
        thing.photos = ["shown"]
        lib.items = [thing]
        lib.photos = [PhotoRecord(id: "shown", data: "data:image/jpeg;base64,AQID", createdAt: ""),
                      PhotoRecord(id: "old", data: "data:image/jpeg;base64,AQID", createdAt: "2026-10-01T09:00:00.000Z"),
                      PhotoRecord(id: "undated", data: "data:image/jpeg;base64,AQID", createdAt: ""),
                      PhotoRecord(id: "unreadable", data: "data:image/jpeg;base64,AQID", createdAt: "last week")]
        XCTAssertEqual(lib.unusedPhotos().map(\.id), ["old"], "an undated photo is never offered with the old ones")
        XCTAssertEqual(lib.undatedUnusedPhotos().map(\.id), ["undated", "unreadable"], "a photo still shown is no worry")
        let worry = lib.worries().first { $0.fix == Library.FIX_UNDATED_PHOTOS }
        XCTAssertEqual(worry?.says, "2 photos with no date are no longer shown anywhere.")
        XCTAssertEqual(worry?.fixSays, "Remove them")
        XCTAssertEqual(lib.repair(Library.FIX_UNDATED_PHOTOS), 2)
        XCTAssertEqual(lib.photos.map(\.id), ["shown", "old"], "the repair took more than the undated ones")
        XCTAssertNil(lib.worries().first { $0.fix == Library.FIX_UNDATED_PHOTOS })
        lib.photos.append(PhotoRecord(id: "one", data: "", createdAt: ""))
        XCTAssertEqual(lib.worries().first { $0.fix == Library.FIX_UNDATED_PHOTOS }?.says,
                       "1 photo with no date is no longer shown anywhere.")
    }
}
