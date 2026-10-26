import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Warn instead of merge (0.102, his decision of 26 Oct 2026 — option B of spec 01 Open question 32).
/// A block iCloud keeps whole (a grab list, a template's head, what a kit holds, a list of Your
/// choices) changed on the other device while a page had it open: Done asks — Keep both or Keep mine.
/// And a save of ours the other device's crossing save wrote over is found when that save arrives.
/// Invented data only — this repository is public.
final class WarnInsteadOfMergeTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-26T08:00:00.000Z") }
    override func tearDown() {
        PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES); _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    private let swim = GRAB_FACTORY[0]
    private func without(_ names: String...) -> [GrabLine] { swim.lines.filter { !names.contains($0.name) } }

    /// A template "Hiking" with a Torch and a Map, its Torch under a section "Lights".
    private func hiking() -> (Library, String) {
        var lib = Library()
        lib.saveTemplate(newList(name: "Hiking"))
        let t = lib.templates.first { $0.name == "Hiking" }!.id
        for name in ["Torch", "Map"] { _ = lib.addToTemplate(templateId: t, name: name) }
        let n = lib.templates.firstIndex { $0.id == t }!
        lib.templates[n].sections = [TemplateSection(json: ["id": "s-lights", "name": "Lights"])]
        return (lib, t)
    }

    // MARK: - 1. At Done

    /// The grab list's editor open; the other device took Flip-flops off meanwhile; the editor took
    /// Goggles off. Save asks: Keep both leaves neither, Keep mine brings Flip-flops back.
    func testAGrabListChangedOnTheOtherDeviceWhileItsEditorWasOpenAsks() {
        var live = Library()
        let opened = swim.lines
        XCTAssertFalse(live.grabEditCrosses(id: swim.id, opened: opened, openedSometimes: [], lines: without("Goggles"), sometimes: []),
                       "nothing changed meanwhile, and Save asked")
        XCTAssertTrue(live.saveGrabList(id: swim.id, lines: without("Flip-flops")))          // the other device's save arrives
        XCTAssertTrue(live.grabEditCrosses(id: swim.id, opened: opened, openedSometimes: [], lines: without("Goggles"), sometimes: []),
                      "the list changed on the other device meanwhile and Save did not ask")
        XCTAssertFalse(live.grabEditCrosses(id: swim.id, opened: opened, openedSometimes: [], lines: without("Flip-flops"), sometimes: []),
                       "both devices made the same change: there is nothing to choose")
        XCTAssertFalse(live.grabEditCrosses(id: swim.id, opened: opened, openedSometimes: [], lines: opened, sometimes: []),
                       "the editor changed nothing: there is nothing to choose")
        var both = live, mine = live
        both.saveGrabEdit(id: swim.id, opened: opened, openedSometimes: [], lines: without("Goggles"), sometimes: [])
        mine.saveGrabEdit(id: swim.id, lines: without("Goggles"), sometimes: [])
        XCTAssertEqual(both.grabList(id: swim.id)!.items, without("Goggles", "Flip-flops").map(\.name), "Keep both")
        XCTAssertEqual(mine.grabList(id: swim.id)!.items, without("Goggles").map(\.name), "Keep mine")
    }

    /// A "1 in 10" mark set on the other device meanwhile is part of the list: Save asks too.
    func testAMarkSetOnTheOtherDeviceMeanwhileAsks() {
        var live = Library()
        live.setSometimes(listId: swim.id, names: ["Towel"])
        XCTAssertTrue(live.grabEditCrosses(id: swim.id, opened: swim.lines, openedSometimes: [],
                                           lines: without("Goggles"), sometimes: []), "the other device's mark")
        XCTAssertFalse(live.grabEditCrosses(id: swim.id, opened: swim.lines, openedSometimes: ["Towel"],
                                            lines: swim.lines, sometimes: ["Swim cap", "Towel"]),
                       "marks are a set of names: their order alone is no change")
    }

    /// A template's page renamed it; the other device renamed its section meanwhile. Done asks about the
    /// template: Keep both has both, Keep mine the page's head whole. A change meanwhile somewhere
    /// else — a thing's notes — asks nothing.
    func testATemplatesPageAsksWhenTheTemplateChangedMeanwhile() {
        let (opened, t) = hiking()
        var page = opened
        let n = page.templates.firstIndex { $0.id == t }!
        page.templates[n].name = "Hiking trip"
        var live = opened
        _ = live.updateThing(id: live.items.first { $0.name == "Map" }!.id) { $0.note = "Fold it" }
        XCTAssertEqual(live.crossings(opened: opened, page: page), [], "a change elsewhere meanwhile, and Done asked")
        let m = live.templates.firstIndex { $0.id == t }!
        live.templates[m].sections[0].name = "Torches"
        XCTAssertEqual(live.crossings(opened: opened, page: page), [.template(t)], "the section renamed meanwhile")
        XCTAssertEqual(live.words(for: [.template(t)]), "The Hiking template")

        let both = live.applyingPage(from: opened, to: page, mine: [])
        let bothHead = both.templates.first { $0.id == t }!
        XCTAssertEqual(bothHead.name, "Hiking trip", "Keep both")
        XCTAssertEqual(bothHead.sections.map(\.name), ["Torches"], "Keep both lost the other device's section name")
        let mine = live.applyingPage(from: opened, to: page, mine: [.template(t)])
        let mineHead = mine.templates.first { $0.id == t }!
        XCTAssertEqual(mineHead.name, "Hiking trip", "Keep mine")
        XCTAssertEqual(mineHead.sections.map(\.name), ["Lights"], "Keep mine kept the other device's section name")
        XCTAssertEqual(mine.items.first { $0.name == "Map" }?.note, "Fold it", "Keep mine undid a change elsewhere")
    }

    /// Your choices: a place added on each device. Done asks about the places; Keep mine has the
    /// page's places only.
    func testYourChoicesAskAboutAPlaceAddedOnTheOtherDevice() {
        let opened = hiking().0
        var page = opened, live = opened
        XCTAssertNotNil(page.addChoice("places", "Shed"))
        XCTAssertNotNil(live.addChoice("places", "Attic"))
        XCTAssertEqual(live.crossings(opened: opened, page: page), [.choices("places")])
        XCTAssertEqual(live.words(for: .choices("places")), "Your storage places")
        let both = live.applyingPage(from: opened, to: page, mine: []).storagePlaces()
        XCTAssertTrue(both.contains("Shed") && both.contains("Attic"), "Keep both: \(both)")
        let mine = live.applyingPage(from: opened, to: page, mine: [.choices("places")]).storagePlaces()
        XCTAssertTrue(mine.contains("Shed") && !mine.contains("Attic"), "Keep mine: \(mine)")
    }

    /// A kit's page took the Lighter out of the pouch; the other device put the Cord in meanwhile.
    func testAKitsPageAsksWhenTheKitChangedMeanwhile() {
        var lib = Library()
        var ids: [String: String] = [:]
        for name in ["Pouch", "Lighter", "Plasters", "Cord"] { ids[name] = lib.addThing(name: name)!.id }
        let pouch = ids["Pouch"]!
        lib.setKit(kitId: pouch, contents: [ids["Lighter"]!, ids["Plasters"]!])
        let opened = Library.listedContents(lib.items.first { $0.id == pouch }!)
        XCTAssertFalse(lib.kitPageCrosses(kitId: pouch, opened: opened, openedOut: [], contents: [ids["Plasters"]!], out: []),
                       "nothing changed meanwhile, and Save asked")
        lib.setKit(kitId: pouch, contents: opened + [ids["Cord"]!])                            // the other device
        XCTAssertTrue(lib.kitPageCrosses(kitId: pouch, opened: opened, openedOut: [], contents: [ids["Plasters"]!], out: []),
                      "the kit changed meanwhile and Save did not ask")
        XCTAssertEqual(lib.words(for: .kit(pouch)), "What the Pouch holds")
    }

    /// The question names the other device once it has checked in here.
    func testTheQuestionAndTheNoteNameTheOtherDevice() {
        var lib = Library()
        XCTAssertEqual(lib.crossedTitle(thisDevice: "Mac"), "Changed on your other device meanwhile")
        lib.checkIn(device: "iPhone")
        XCTAssertEqual(lib.crossedTitle(thisDevice: "Mac"), "Changed on your iPhone meanwhile")
        XCTAssertEqual(lib.crossedTitle(thisDevice: "iPhone"), "Changed on your other device meanwhile")
        XCTAssertEqual(lib.crossedNote([.grabList("swim")], thisDevice: "Mac"),
                       "Indoor swim\u{2019}s grab list was also changed on your iPhone \u{2014} open it to check.")
        XCTAssertEqual(lib.crossedNote([.grabList("swim"), .kinds], thisDevice: "Mac"),
                       "Indoor swim\u{2019}s grab list and your kinds of thing were also changed on your iPhone \u{2014} open them to check.")
    }

    // MARK: - 2. The other device's save arrives after ours

    private func twoDevices(_ start: Library) throws -> (CrossingSavesTests.Cloud, CrossingSavesTests.Device, CrossingSavesTests.Device) {
        let cloud = CrossingSavesTests.Cloud(), phone = CrossingSavesTests.Device("iphone"), mac = CrossingSavesTests.Device("mac")
        try phone.apply(RecordChanges(puts: start.records()))
        cloud.send(phone)
        cloud.bring(mac)
        return (cloud, phone, mac)
    }

    /// The Mac took Goggles off Swim and sent it; the iPhone, before that arrived, took Flip-flops off
    /// and sent it last: iCloud keeps the iPhone's list whole and the Mac's change is gone. When the
    /// iPhone's list arrives on the Mac, the Mac's watch finds its change missing — told once. The
    /// iPhone, which holds its own list, is told nothing.
    func testASaveTheOtherDeviceWroteOverIsFoundWhenItArrives() throws {
        var start = hiking().0
        start.saveGrabList(id: swim.id, lines: swim.lines)            // the list is stored already: no twins
        let (cloud, phone, mac) = try twoDevices(start)
        var watchMac = RecentSaves(), watchPhone = RecentSaves()

        let onMac = try StoreSession.load(mac)
        var macNext = onMac.library
        macNext.saveGrabEdit(id: swim.id, opened: swim.lines, openedSometimes: [], lines: without("Goggles"), sometimes: [])
        _ = try StoreSession.save(macNext, held: onMac.held, to: mac)
        watchMac.note(before: onMac.library, after: macNext)
        XCTAssertEqual(watchMac.watching, [.grabList(swim.id)])

        PackingEnv.freeze(at: "2026-10-26T08:00:20.000Z")
        let onPhone = try StoreSession.load(phone)
        var phoneNext = onPhone.library
        phoneNext.saveGrabEdit(id: swim.id, opened: swim.lines, openedSometimes: [], lines: without("Flip-flops"), sometimes: [])
        _ = try StoreSession.save(phoneNext, held: onPhone.held, to: phone)
        watchPhone.note(before: onPhone.library, after: phoneNext)

        cloud.send(mac); cloud.send(phone)                             // the iPhone's arrives last
        cloud.bring(mac); cloud.bring(phone)
        let macNow = try StoreSession.load(mac).library, phoneNow = try StoreSession.load(phone).library
        XCTAssertEqual(macNow.grabList(id: swim.id)!.items, without("Flip-flops").map(\.name), "iCloud kept the last list sent")
        XCTAssertEqual(watchMac.arrived(macNow), [.grabList(swim.id)], "the Mac's lost change was not found")
        XCTAssertEqual(watchMac.arrived(macNow), [], "told twice")
        XCTAssertEqual(watchPhone.arrived(phoneNow), [], "the iPhone holds its own list and was told something")
    }

    /// The other device's later save that holds our change — it had seen ours — is no loss: nothing
    /// is told, and the block is no longer watched. Nor is a save that is older than the watch.
    func testALaterSaveThatHoldsOurChangeIsNoLoss() {
        let before = Library()
        var after = before
        after.saveGrabList(id: swim.id, lines: without("Goggles"))
        var watch = RecentSaves()
        watch.note(before: before, after: after)
        XCTAssertEqual(watch.arrived(after), [], "our own list, read again")
        var later = after
        later.saveGrabList(id: swim.id, lines: without("Goggles", "Towel"))
        XCTAssertEqual(watch.arrived(later), [], "the other device's save on top of ours")
        XCTAssertEqual(watch.watching, [])

        watch.note(before: before, after: after)
        let old = PackingEnv.now().addingTimeInterval(RecentSaves.window + 1)
        XCTAssertEqual(watch.arrived(before, now: old), [], "a save older than the watch")
    }
}
