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
        // He has a Swim already: as a new one it takes a name of its own (the spec pass).
        let made = try XCTUnwrap(me.importTemplate(shared, named: me.freeTemplateName(shared.name)))
        XCTAssertEqual(made.name, "Swim 2")
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

    /// As a NEW template a shared one needs a name he does not have yet — New and
    /// Rename refuse a second of one name too, and Worth a look reads two as "two
    /// libraries may have met" (the spec pass, 5 Oct 2026).
    func testASharedTemplateIsNotAddedUnderANameHeHas() throws {
        var me = library()
        let link = try XCTUnwrap(me.shareLink(templateId: me.templates[0].id))
        guard case .template(let shared)? = Library.readShared(link) else { return XCTFail("not read as a template") }
        let before = me
        XCTAssertNil(me.importTemplate(shared), "a second Swim was made")
        XCTAssertEqual(me, before, "a refused import changed something")
        let made = try XCTUnwrap(me.importTemplate(shared, named: " Swim club "))
        XCTAssertEqual(made.name, "Swim club")
        XCTAssertTrue(me.worries().isEmpty, "\(me.worries())")
        XCTAssertNil(me.importTemplate(shared, named: "swim CLUB"), "a name he has, given as the new one")
    }

    /// A thing he has is linked — and keeps HIS spelling of its name.
    func testALinkedThingKeepsHisSpelling() throws {
        var sender = Library()
        var list = newList(name: "Pool", group: "WET")
        list.items = [newItem(name: "towel"), newItem(name: "Kickboard")]
        sender.saveTemplate(list)
        let link = try XCTUnwrap(sender.shareLink(templateId: sender.templates[0].id))
        guard case .template(let shared)? = Library.readShared(link) else { return XCTFail("not read as a template") }
        var me = library()
        XCTAssertNotNil(me.importTemplate(shared))
        XCTAssertEqual(me.items.filter { normName($0.name) == "towel" }.map(\.name), ["Towel"], "his Towel was renamed")
    }

    /// The finding of the spec pass: a shared always-packed template KEEPS its role as
    /// a new one (said on the screen before he adds it), so every new trip packs it;
    /// Replace keeps where HIS template lives, so his activity never becomes one.
    func testASharedAlwaysPackedTemplateStaysOneButReplaceKeepsHisPlace() throws {
        var sender = Library()
        var base = newList(name: "Swim", role: "base")
        base.items = [newItem(name: "Fins")]
        sender.saveTemplate(base)
        let link = try XCTUnwrap(sender.shareLink(templateId: sender.templates[0].id))
        guard case .template(let shared)? = Library.readShared(link) else { return XCTFail("not read as a template") }
        XCTAssertEqual(shared.role, "base")

        var me = library()
        let added = try XCTUnwrap(me.importTemplate(shared, named: "Pool base"))
        XCTAssertEqual(added.role, "base", "as a new one it is no longer always packed")
        let trip = me.createTrip(newEvent(name: "Any trip", startDate: "2026-11-01", endDate: "2026-11-02"))
        XCTAssertTrue(trip.entries.contains { $0.name == "Fins" }, "a new always-packed template is not packed on every trip")

        let mine = me.templates.first { $0.name == "Swim" }!
        let replaced = try XCTUnwrap(me.importTemplate(shared, replacing: mine.id))
        XCTAssertEqual(replaced.id, mine.id)
        XCTAssertEqual(replaced.role, "", "Replace turned his activity into an always-packed template")
        XCTAssertEqual(replaced.group, "WET", "Replace moved his template out of its area")
        XCTAssertEqual(me.resolvedTemplate(id: mine.id)?.items.map(\.name), ["Fins"])
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

    /// A shared grab list keeps a drawing and a colour this app has; anything else
    /// becomes the look a new list gets — its initial, in blue. (Until 5 Oct 2026 an
    /// unknown drawing showed as the runner and an unknown colour as slate.)
    func testAReceivedGrabListGetsTheStandardLookForWhatIsUnknown() {
        var me = Library()
        let known = me.importGrab(GrabShare(name: "Lake", icon: "swim-sun", tone: "teal", items: ["Wetsuit"]))
        XCTAssertEqual(known?.icon, "swim-sun")
        XCTAssertEqual(known?.tone, "teal")
        let odd = me.importGrab(GrabShare(name: "Kite", icon: "kite", tone: "magenta", items: ["Board"]))
        XCTAssertEqual(odd?.icon, "", "an unknown drawing was kept (it shows as the runner)")
        XCTAssertEqual(odd?.tone, "blue", "an unknown colour was kept (it shows as slate)")
        XCTAssertEqual(me.ownGrabLists().map(\.icon), ["swim-sun", ""])
    }
}
