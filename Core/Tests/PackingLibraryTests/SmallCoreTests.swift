import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// "Make a small core from this…" (0.71): a big always-packed template gives a small
/// always-packed core of the rows he ticks, and becomes a template he ticks himself.
final class SmallCoreTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    /// "Everything" (always packed): Clothes (Socks per night, Shirt), Wash bag
    /// (Toothbrush), Tech (Laptop, Cable 2), then Umbrella, Kettle per night under no
    /// heading — and 16 more under Tech to make it big. Plus a Hiking template.
    private func library() -> Library {
        var lib = Library()
        var big = newList(name: "Everything", role: "base")
        let clothes = TemplateSection(name: "Clothes"), wash = TemplateSection(name: "Wash bag"), tech = TemplateSection(name: "Tech")
        big.sections = [clothes, wash, tech]
        func row(_ name: String, _ section: TemplateSection?, perNight: Bool = false) -> Item {
            var i = newItem(name: name); i.section = section?.id ?? ""; i.perNight = perNight; return i
        }
        big.items = [row("Socks", clothes, perNight: true), row("Shirt", clothes), row("Toothbrush", wash),
                     row("Laptop", tech), row("Cable 2", tech), row("Umbrella", nil), row("Kettle", nil, perNight: true)]
            + (1...16).map { row("Gadget \(Character(UnicodeScalar(64 + $0)!))", tech) }
        lib.saveTemplate(big)
        var hike = newList(name: "Hiking", group: "GA"); hike.items = [newItem(name: "Boots")]
        lib.saveTemplate(hike)
        // One row's own answers, to see them carried over.
        let socks = lib.memberships.first { m in lib.items.first { $0.id == m.itemId }?.name == "Socks" }!
        lib.updateMembership(memId: socks.id) { $0.note = "Wool"; $0.qty = "3"; $0.container = "Duffel bag"
            $0.phase = "night-before"; $0.seasons = ["Winter"] }
        return lib
    }
    private func tpl(_ lib: Library, _ name: String) -> PackList { lib.templates.first { $0.name == name }! }
    private func mem(_ lib: Library, _ thing: String, on t: String) -> Membership {
        let tid = tpl(lib, t).id
        return lib.memberships.first { m in m.templateId == tid && lib.items.first { $0.id == m.itemId }?.name == thing }!
    }
    private func names(_ lines: [Item]) -> [String] { lines.map(\.name).sorted() }

    func testTheDoorShowsOnlyOnABigAlwaysPackedTemplate() {
        var lib = library()
        XCTAssertTrue(lib.offersSmallCore(templateId: tpl(lib, "Everything").id))
        XCTAssertFalse(lib.offersSmallCore(templateId: tpl(lib, "Hiking").id), "a ticked template offered it")
        var small = newList(name: "Small", role: "base"); small.items = [newItem(name: "Keys")]
        lib.saveTemplate(small)
        XCTAssertFalse(lib.offersSmallCore(templateId: small.id), "a small always-packed template offered it")
    }

    func testClothesWashingAndPerNightAreTickedAtFirst() {
        let lib = library()
        let id = tpl(lib, "Everything").id
        XCTAssertEqual(lib.smallCoreGroups(templateId: id).map(\.title), ["Clothes", "Wash bag", "Tech", "Everything else"])
        let first = lib.smallCoreSuggestion(templateId: id)
        let picked = lib.smallCoreRows(templateId: id).filter { first.contains($0.memId!) }
        XCTAssertEqual(names(picked), ["Kettle", "Shirt", "Socks", "Toothbrush"])
        for word in ["Clothing", "KLÄDER", "klader", "Hygien & toalett", "Underwear", "Bathroom bits", "Toiletries"] {
            XCTAssertTrue(Library.readsAsCore(sectionName: word), word)
        }
        XCTAssertFalse(Library.readsAsCore(sectionName: "Tech"))
    }

    func testHisPastedListTicksWhatItNames() {
        let lib = library()
        let id = tpl(lib, "Everything").id
        XCTAssertEqual(Library.pastedNames("- Socks\n2. shirt, • [x] Umbrella\n\n3-in-1 plug"),
                       ["Socks", "shirt", "Umbrella", "3-in-1 plug"])
        let plan = lib.planPaste("* SOCK\n1) Cable\nlaptop, Umbrella\nHammock; Gadget P\nHammock\nGadgets", templateId: id)
        let picked = lib.smallCoreRows(templateId: id).filter { plan.ticked.contains($0.memId!) }
        XCTAssertEqual(names(picked).filter { !$0.hasPrefix("Gadget ") || $0 == "Gadget P" }.count, 5)
        XCTAssertEqual(names(picked).count, 4 + 16, "Gadgets did not tick every Gadget")
        XCTAssertEqual(plan.notFound, ["Hammock"], "a name not found once, or a found name, was reported")
        XCTAssertEqual(plan.found, 6)
        XCTAssertEqual(plan.several, ["matched 16 things for Gadgets"])
        XCTAssertTrue(plan.words.hasPrefix("6 found \u{00B7} 1 not found: Hammock"), plan.words)
        // A whole word of a longer name: "T-shirts" is the "Spare top / t-shirt".
        var more = lib
        var spare = newItem(name: "Spare top / t-shirt"); spare.section = ""
        var big = more.resolvedTemplate(id: id)!; big.items.append(spare); more.saveTemplate(big)
        let words = more.planPaste("T-shirts", templateId: id)
        XCTAssertEqual(names(more.smallCoreRows(templateId: id).filter { words.ticked.contains($0.memId!) }), ["Spare top / t-shirt"])
    }

    /// His list holds KITS: a line with lines indented under it.
    func testANestedLineMakesAKit() {
        var lib = library()
        let id = tpl(lib, "Everything").id
        let text = "Socks\nCable pouch\n  - Cable\n\tLaptop\n  - Kayak\nUmbrella"
        XCTAssertEqual(Library.pastedLines(text).map(\.depth), [0, 0, 1, 1, 1, 0])
        let plan = lib.planPaste(text, templateId: id)
        XCTAssertEqual(plan.kits.count, 1)
        XCTAssertNil(plan.kits[0].thingId, "a kit nobody has was not to be made")
        XCTAssertEqual(plan.kits[0].inside.compactMap { i in lib.items.first { $0.id == i }?.name }, ["Cable 2", "Laptop"])
        XCTAssertEqual(plan.notFound, ["Kayak"])
        XCTAssertFalse(lib.items.contains { $0.name == "Cable pouch" }, "reading the paste changed the library")
        let ticked = plan.ticked
        let core = lib.makeSmallCore(from: id, name: "Core", ticked: ticked, bigArea: "", plan: plan)!
        let pouch = lib.items.first { $0.name == "Cable pouch" }!
        XCTAssertEqual(lib.kitContents(kitId: pouch.id).map(\.thing.name), ["Cable 2", "Laptop"])
        XCTAssertEqual(pouch.container, "", "a new kit got a bag")
        XCTAssertEqual(names(lib.resolvedTemplate(id: core.id)!.items), ["Cable pouch", "Socks", "Umbrella"],
                       "the kit itself is not on the core, or its things are")
        // Under the heading of what is inside it (Tech).
        let r = lib.resolvedTemplate(id: core.id)!
        let kitRow = r.items.first { $0.name == "Cable pouch" }!
        XCTAssertEqual(r.sections.first { $0.id == kitRow.section }?.name, "Tech")
    }

    /// A thing sits in one kit only: one in another kit is not moved — he may ask for
    /// a second one instead.
    func testAThingInAnotherKitIsNotMovedButCanBeMadeTwice() {
        var lib = library()
        let id = tpl(lib, "Everything").id
        let camp = lib.addThing(name: "Camp pouch")!
        let laptop = lib.items.first { $0.name == "Laptop" }!.id
        lib.setKit(kitId: camp.id, contents: [laptop])
        lib.updateThing(id: laptop) { $0.weight = 1200 }
        let text = "Cable pouch\n  Laptop\n  Cable\nDesk kit\n  Cable"
        let plan = lib.planPaste(text, templateId: id)
        XCTAssertEqual(plan.clashes.map(\.words), ["Laptop is already in Camp pouch \u{2014} a thing sits in one kit only",
                                                   "Cable 2 is already in Cable pouch \u{2014} a thing sits in one kit only"])
        // He asks for a second Laptop only.
        let core = lib.makeSmallCore(from: id, name: "Core", ticked: [], bigArea: "", plan: plan, seconds: [plan.clashes[0].id])
        XCTAssertNotNil(core)
        XCTAssertEqual(lib.kitHolding(thingId: laptop)?.name, "Camp pouch", "the Laptop was moved")
        let cable = lib.items.first { $0.name == "Cable pouch" }!.id
        XCTAssertEqual(lib.kitContents(kitId: cable).map(\.thing.name), ["Cable 2", "Laptop 2"])
        XCTAssertEqual(lib.items.first { $0.name == "Laptop 2" }?.weight, 1200, "the second one has other details")
        XCTAssertNil(lib.items.first { $0.name == "Desk kit" }, "a kit holding nothing was made (or the Cable went in two kits)")
    }

    func testTheSmallCoreIsMadeAndTheBigOneIsTickedFromThen() {
        var lib = library()
        let bigId = tpl(lib, "Everything").id
        let bigRowsBefore = lib.memberships.filter { $0.templateId == bigId }
        let ticked = Set(["Socks", "Toothbrush", "Umbrella"].map { mem(lib, $0, on: "Everything").id })
        XCTAssertEqual(lib.smallCoreProblem(templateId: bigId, name: " ", ticked: ticked), "Give the small core a name.")
        XCTAssertEqual(lib.smallCoreProblem(templateId: bigId, name: "hiking", ticked: ticked), "You already have a template called that.")
        XCTAssertEqual(lib.smallCoreProblem(templateId: bigId, name: "Core", ticked: []), "Tick at least one thing for the small core.")
        XCTAssertNil(lib.makeSmallCore(from: bigId, name: "Core", ticked: ticked, bigArea: "XX"), "an area that is not his")
        XCTAssertNil(lib.makeSmallCore(from: tpl(lib, "Hiking").id, name: "Core", ticked: ticked, bigArea: ""), "made from a ticked template")
        XCTAssertNil(lib.templates.first { $0.name == "Core" }, "a refused try left something behind")

        let core = lib.makeSmallCore(from: bigId, name: "Everything short", ticked: ticked, bigArea: "")!
        XCTAssertEqual(core.role, "base")
        XCTAssertEqual(tpl(lib, "Everything").role, "", "the big one is still always packed")
        XCTAssertEqual(tpl(lib, "Everything").group, "")
        XCTAssertEqual(lib.memberships.filter { $0.templateId == bigId }, bigRowsBefore, "the big one's rows changed")
        // The same things, with each row's own answers; only the headings that hold one.
        XCTAssertEqual(names(lib.resolvedTemplate(id: core.id)!.items), ["Socks", "Toothbrush", "Umbrella"])
        let a = mem(lib, "Socks", on: "Everything"), b = mem(lib, "Socks", on: "Everything short")
        XCTAssertEqual(b.itemId, a.itemId, "a new thing was made instead of the same one")
        XCTAssertEqual([b.note, b.qty, b.container, b.phase], [a.note, a.qty, a.container, a.phase])
        XCTAssertEqual(b.seasons, a.seasons)
        XCTAssertNotEqual(b.id, a.id)
        XCTAssertEqual(core.sections.map(\.name), ["Clothes", "Wash bag"])
        let rows = lib.resolvedTemplate(id: core.id)!
        func heading(_ thing: String) -> String {
            let s = rows.items.first { $0.name == thing }!.section
            return rows.sections.first { $0.id == s }?.name ?? ""
        }
        XCTAssertEqual([heading("Socks"), heading("Toothbrush"), heading("Umbrella")], ["Clothes", "Wash bag", ""])

        // A Full trip: the small core, not the big one — unless ticked. (The Socks are
        // "Only on" Winter, on both: this trip has no season, so they stay home.)
        var trip = newEvent(name: "Weekend"); trip.activities = [tpl(lib, "Hiking").id]
        XCTAssertEqual(names(lib.createTrip(trip).entries), ["Boots", "Toothbrush", "Umbrella"])
        XCTAssertTrue(lib.activityChoices().flatMap(\.lists).contains { $0.id == bigId }, "the big one cannot be ticked")
        trip.activities.append(bigId)
        XCTAssertEqual(lib.createTrip(trip).entries.count, 1 + 22, "ticked, the big one did not come in full")
    }

    func testTheBigOneCanGoToAnActivityArea() {
        var lib = library()
        let bigId = tpl(lib, "Everything").id
        let one = Set([mem(lib, "Shirt", on: "Everything").id])
        XCTAssertNotNil(lib.makeSmallCore(from: bigId, name: "Core", ticked: one, bigArea: "OE"))
        XCTAssertEqual(tpl(lib, "Everything").group, "OE")
    }
}
