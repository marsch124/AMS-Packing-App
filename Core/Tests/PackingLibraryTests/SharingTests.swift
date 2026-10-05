import XCTest
@testable import PackingCore
@testable import PackingLibrary

final class SharingTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    private func library() -> Library {
        var lib = Library()
        var swim = newList(name: "Swim", group: "WET")
        var towel = newItem(name: "Towel"); towel.weight = 340; towel.container = "Duffel bag"
        swim.items = [newItem(name: "Goggles"), towel]
        lib.saveTemplate(swim)
        var trip = newEvent(name: "Swim week", startDate: "2026-10-03", endDate: "2026-10-05")
        trip.activities = lib.templates.map(\.id)
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        trip.entries[0].checked = true
        lib.trips = [trip]
        return lib
    }

    /// A trip's link opens the web app, reads back as a trip, and arrives as a new
    /// trip of his: new ids, nothing ticked; the one it came from untouched.
    func testATripTravelsAsALink() throws {
        var lib = library()
        let link = try XCTUnwrap(lib.shareLink(tripId: lib.trips[0].id))
        XCTAssertTrue(link.hasPrefix(SHARE_WEB_BASE + "#/t/"), "not a web app link: \(link.prefix(60))")
        guard case .trip(let got)? = Library.readShared("Look at this: \(link) — see you") else {
            return XCTFail("the link does not read back as a trip")
        }
        XCTAssertEqual(got.name, "Swim week")
        XCTAssertEqual(got.entries.map(\.name).sorted(), ["Goggles", "Towel"])
        XCTAssertFalse(got.entries.contains { $0.checked }, "ticks travelled")
        lib.importTrip(got)
        XCTAssertEqual(lib.trips.count, 2)
        XCTAssertNotEqual(lib.trips[1].id, lib.trips[0].id)
        XCTAssertTrue(lib.trips[0].entries[0].checked, "the original lost its tick")
        let file = try XCTUnwrap(lib.shareFile(tripId: lib.trips[0].id))
        XCTAssertEqual(file.fileName, "Swim week trip.json")
        XCTAssertNoThrow(try parseTripBundle(String(decoding: file.data, as: UTF8.self)), "the file is not a trip the web app reads")
    }

    /// A template arrives as a new one; a thing he already has is linked, and HIS
    /// details stay (the sender's weight and bag do not overwrite them); a thing new
    /// to him comes with the sender's details. Replace keeps the template's id.
    func testATemplateArrivesWithoutTouchingHisThings() throws {
        var sender = library()
        sender.items[sender.items.firstIndex { $0.name == "Towel" }!].weight = 999
        var fins = newItem(name: "Fins"); fins.weight = 700
        var list = try XCTUnwrap(sender.resolvedTemplate(id: sender.templates[0].id))
        list.items.append(fins)
        sender.saveTemplate(list)
        let link = try XCTUnwrap(sender.shareLink(templateId: sender.templates[0].id))
        XCTAssertTrue(link.contains("#/l/"))
        guard case .template(let shared)? = Library.readShared(link) else { return XCTFail("not read as a template") }

        var me = library()
        let things = me.items.count
        XCTAssertEqual(me.templateNamed("swim")?.id, me.templates[0].id, "his Swim is not found by name")
        let made = try XCTUnwrap(me.importTemplate(shared))
        XCTAssertNotEqual(made.id, me.templates[0].id, "a new template took his old one's id")
        XCTAssertEqual(me.items.count, things + 1, "only Fins is new to him")
        XCTAssertEqual(me.items.first { $0.name == "Towel" }?.weight, 340, "the sender's weight overwrote his Towel")
        XCTAssertEqual(me.items.first { $0.name == "Towel" }?.container, "Duffel bag", "his Towel's bag was changed")
        XCTAssertEqual(me.items.first { $0.name == "Fins" }?.weight, 700, "a new thing lost the sender's details")
        XCTAssertEqual(me.resolvedTemplate(id: made.id)?.items.count, 3)

        let old = me.templates[0].id
        let replaced = try XCTUnwrap(me.importTemplate(shared, replacing: old))
        XCTAssertEqual(replaced.id, old, "Replace did not keep the template's id")
        XCTAssertEqual(me.resolvedTemplate(id: old)?.items.map(\.name).sorted(), ["Fins", "Goggles", "Towel"])
    }

    /// A grab list arrives in Grab Lists, waiting, not on Home.
    func testAGrabListWaitsInGrabLists() throws {
        var sender = Library()
        let own = try XCTUnwrap(sender.addGrabList(label: "Sauna", tone: "green", items: ["Towel", "Water", "Sandals"]))
        let link = try XCTUnwrap(sender.shareLink(grabId: own.id))
        XCTAssertTrue(link.contains("#/g/"))
        guard case .grab(let g)? = Library.readShared(link) else { return XCTFail("not read as a grab list") }
        var me = Library()
        // Home holds eight: with two of his own it is full, so the shared list waits.
        // (On a Home with a free place it takes that place — GrabCollectionTests.)
        _ = me.addGrabList(label: "Padel"); _ = me.addGrabList(label: "Golf")
        let home = me.homeGrabLists().map(\.id)
        XCTAssertEqual(home.count, GRAB_HOME_SLOTS)
        let got = try XCTUnwrap(me.importGrab(g))
        XCTAssertEqual(got.label, "Sauna")
        XCTAssertEqual(got.items, ["Towel", "Water", "Sandals"])
        XCTAssertEqual(me.homeGrabLists().map(\.id), home, "Home changed")
        XCTAssertTrue(me.waitingGrabLists().contains { $0.id == got.id }, "it is not waiting in Grab Lists")
        XCTAssertNil(Library.readShared("hello there"), "any text read as something")
        XCTAssertNil(Library.readShared("   "))
    }

    /// What the sender keeps to himself (the spec pass, 5 Oct 2026): a shared trip
    /// carried his "not this time" marks, the way home's ticks, used up and notes, bought
    /// on site, the luggage scale's readings and the ids of bag photos that never travel.
    /// Now it is just the list — out of the link, out of the file, and on arrival even
    /// from an older link that still carries them.
    func testASharedTripIsJustTheList() throws {
        var lib = library()
        let t = lib.trips[0].id
        let towel = lib.trips[0].entries[1].id
        _ = lib.setAside(true, tripId: t, entryId: towel)
        lib.trips[0].entries[0].extra[HOME_KEY] = .bool(true)
        lib.trips[0].entries[0].extra[USED_UP_KEY] = .bool(true)
        lib.trips[0].entries[0].extra[HOME_NOTE_KEY] = .string("Strap loose")
        lib.trips[0].entries[0].extra["packedAt"] = .string("2026-10-02T18:00:00.000Z")
        lib.trips[0].entries[0].edited = true
        _ = lib.addBoughtOnSite(tripId: t, name: "Sandals")
        _ = lib.setWeighed(tripId: t, bag: "Duffel bag", grams: 9500)
        _ = lib.addBagPhoto(tripId: t, bag: "Duffel bag", jpeg: Data([1, 2, 3]))
        let link = try XCTUnwrap(lib.shareLink(tripId: t))
        let file = try XCTUnwrap(lib.shareFile(tripId: t))
        let text = String(decoding: file.data, as: UTF8.self)
        for key in ["skipped", HOME_KEY, USED_UP_KEY, HOME_NOTE_KEY, BOUGHT_ON_SITE_KEY, "packedAt", "_edited", WEIGHED_KEY, BAG_PHOTOS_KEY] {
            XCTAssertFalse(text.contains("\"\(key)\""), "the file carries \(key)")
        }
        guard case .trip(let got)? = Library.readShared(link) else { return XCTFail("the link does not read back") }
        XCTAssertEqual(got.entries.map(\.name), ["Goggles", "Towel", "Sandals"], "the list itself must travel whole")
        XCTAssertEqual(got.entries.first { $0.name == "Towel" }?.container, "Duffel bag", "the bag must travel")
        XCTAssertFalse(got.entries.contains { $0.skipped }, "not this time travelled")
        XCTAssertTrue(got.entries.allSatisfy { $0.extra.isEmpty }, "a line's own marks travelled: \(got.entries.map(\.extra))")
        XCTAssertNil(got.extra[WEIGHED_KEY], "the scale's readings travelled")
        XCTAssertNil(got.extra[BAG_PHOTOS_KEY], "bag photo ids travelled")
        XCTAssertEqual(lib.weighed(tripId: t)["Duffel bag"], 9500, "sharing took the sender's own reading away")

        // An older link still carries the marks: they are left at the door.
        var old = lib.trips[0]
        old.entries[0].extra[HOME_NOTE_KEY] = .string("Strap loose")
        old.extra[WEIGHED_KEY] = .object(["Duffel bag": .number(9500)])
        guard let oldFrag = encodeTripLink(old), case .trip(let carried)? = Library.readShared(oldFrag) else {
            return XCTFail("an old-style link does not read back")
        }
        let arrived = lib.importTrip(carried)
        XCTAssertNil(arrived.extra[WEIGHED_KEY], "an old link's scale reading arrived")
        XCTAssertTrue(arrived.entries.allSatisfy { $0.extra.isEmpty && !$0.skipped }, "an old link's marks arrived")
        XCTAssertEqual(arrived.mode, "quick", "a trip someone sent arrives Quick: his own base does not pour in on Save")
    }
}
