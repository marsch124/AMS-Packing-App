import Foundation
import PackingCore
import PackingLibrary

/// An invented library for the UI tests (`-uiTesting`). Nothing of his is in here —
/// this repository is public.
enum SampleLibrary {
    static func make() -> Library {
        var lib = Library()
        func list(_ name: String, group: String = "", role: String = "", _ names: [String]) -> PackList {
            var l = newList(name: name, group: group, role: role)
            l.items = names.map { newItem(name: $0) }
            return l
        }
        lib.saveTemplate(list("Common base", role: "base", ["Passport", "Phone charger", "Toothbrush", "Headlamp"]))
        lib.saveTemplate(list("Hiking", group: "GA", ["Hiking boots", "Rain jacket", "Headlamp", "Map"]))
        // Care: the boots are overdue for waxing (long past, whatever today is);
        // the rain jacket has care notes but no schedule.
        if let n = lib.items.firstIndex(where: { $0.name == "Hiking boots" }) {
            lib.items[n].maintenance = Maintenance(notes: "Clean and wax", intervalDays: 90, lastDone: "2025-01-01")
        }
        if let n = lib.items.firstIndex(where: { $0.name == "Rain jacket" }) {
            lib.items[n].maintenance = Maintenance(notes: "Wash with tech wash, no softener")
        }
        // Weights and places, because his own library has them on almost every thing
        // — and the Care dashboard is built on exactly that. Only the seven things that
        // exist so far get them: Goggles, Swim cap and Towel come later, with Swim, and
        // have NO weight and NO place on purpose — the UI tests count on those three
        // under "No place set". (The tables once named them too, with weights never
        // applied; the spec pass, 5 Oct 2026.)
        let grams: [String: Double] = ["Hiking boots": 1250, "Rain jacket": 420, "Headlamp": 88, "Map": 60,
                                       "Passport": 35, "Phone charger": 120, "Toothbrush": 18]
        let places: [String: String] = ["Hiking boots": "Hall closet", "Rain jacket": "Hall closet",
                                        "Headlamp": "Garage", "Map": "Garage", "Passport": "Chest of drawers",
                                        "Phone charger": "Chest of drawers", "Toothbrush": "Bathroom cabinet"]
        // Owners the way his things carry them: one name on most things, another on
        // a few — and neither on the owners list (the "Whose it is" bug, 2026-09-26).
        let owned: [String: String] = ["Hiking boots": "Kim", "Rain jacket": "Kim", "Headlamp": "Kim",
                                       "Map": "Kim", "Passport": "Kim", "Phone charger": "Robin", "Toothbrush": "Robin"]
        for n in lib.items.indices {
            if let g = grams[lib.items[n].name] { lib.items[n].weight = g }
            if let p = places[lib.items[n].name] { lib.items[n].storage = p }
            if let o = owned[lib.items[n].name] { lib.items[n].ownedBy = o }
        }
        // Review history, as his reviews write it — so Refine has something to say:
        // the Map packed three times and never used; the Headlamp listed twice and
        // never packed; the Hiking boots one quiet trip only (not evidence).
        let history: [String: ItemStats] = ["Map": ItemStats(packed: 3, used: 0, unused: 3),
                                            "Headlamp": ItemStats(packed: 0, skipped: 2),
                                            "Hiking boots": ItemStats(packed: 1, used: 0, unused: 1)]
        for n in lib.items.indices {
            if let h = history[lib.items[n].name] { lib.items[n].stats = h }
        }

        // Two things the buy-list should offer, for two different reasons.
        if let n = lib.items.firstIndex(where: { $0.name == "Map" }) { lib.items[n].condition = "retire" }
        if let n = lib.items.firstIndex(where: { $0.name == "Toothbrush" }) { lib.items[n].consumable = true }
        lib.saveTemplate(list("Swim", group: "WET", ["Goggles", "Swim cap", "Towel"]))
        // One thing packed per night, for the laundry to cap (0.35). Only Swim holds
        // it, so the sample trip's own counts do not change.
        if let n = lib.items.firstIndex(where: { $0.name == "Towel" }) { lib.items[n].perNight = true }
        // His lists are built in sections, so the sample has one too.
        if let hiking = lib.templates.first(where: { $0.name == "Hiking" }),
           let lights = lib.addSection(templateId: hiking.id, name: "Lights"),
           let row = lib.resolvedTemplate(id: hiking.id)?.items.first(where: { $0.name == "Headlamp" })?.memId {
            lib.updateMembership(memId: row) { $0.section = lights.id }
        }
        // One trip, built from Hiking (and the base list, as a trip is) — always a month
        // ahead, counted from the day the tests run. Its first dates were fixed (3–5 Oct
        // 2026), and on those very days it was under way and "an empty Now" went red.
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        var trip = newEvent(name: "Weekend in the hills", startDate: day(30), endDate: day(32))
        trip.activities = lib.templates.filter { $0.name == "Hiking" }.map { $0.id }
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips = [trip]
        return lib
    }

    /// The sample library ready for Check before you go (`-uiTestingChecks`): a plane
    /// trip three weeks out, built from Hiking and the base template, which now carries a pocket
    /// knife and sun cream in the carry-on (where every sample thing goes); the sun
    /// cream runs out during the trip, the passport five months after it.
    static func checks() -> Library {
        var lib = make()
        lib.addBag(name: "Carry-on / hand luggage")
        if let base = lib.templates.first(where: { $0.role == "base" }) {
            for name in ["Pocket knife", "Sun cream"] {
                if let t = lib.addThing(name: name) { _ = lib.setOnTemplate(itemId: t.id, templateId: base.id, on: true) }
            }
        }
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        for n in lib.items.indices {
            switch lib.items[n].name {
            case "Pocket knife": lib.items[n].restricted = true
            case "Sun cream": lib.items[n].liquid = true; lib.items[n].expiry = day(25)
            case "Passport": lib.items[n].category = DOCUMENTS_CATEGORY; lib.items[n].expiry = day(180)
            default: break
            }
        }
        var trip = newEvent(name: "Sunny weeks", startDate: day(20), endDate: day(34))
        trip.transport = "Plane"
        // A trip has a template (Trip settings will not save one without).
        trip.activities = lib.templates.filter { $0.name == "Hiking" }.map { $0.id }
        lib.trips = []
        _ = lib.createTrip(trip)
        return lib
    }

    /// The sample library as the table left it before 0.62 (`-uiTestingOldConditions`):
    /// the Goggles' condition stored as the LABEL "Needs replacing", not its id — the
    /// app must repair it when it reads the library, so To buy offers them.
    static func oldConditions() -> Library {
        var lib = make()
        if let n = lib.items.firstIndex(where: { $0.name == "Goggles" }) { lib.items[n].condition = "Needs replacing" }
        return lib
    }

    /// The sample library with its trip under way (`-uiTestingOnSite`): it began
    /// yesterday and ends in two days, so it stands at On site in the loop and its On
    /// site page is open without anything bought.
    static func underWay() -> Library {
        var lib = make()
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        if !lib.trips.isEmpty {
            lib.trips[0].startDate = day(-1)
            lib.trips[0].endDate = day(2)
        }
        // A note the passport already had: one written on site goes on a line of its own.
        if let n = lib.items.firstIndex(where: { $0.name == "Passport" }) { lib.items[n].note = "Keep it dry" }
        return lib
    }

    /// The sample library with its trip leaving today (`-uiTestingLeaving`, 0.75): it starts
    /// today and ends in two days, and "I leave at" says 08:00 on the first day — so with the
    /// tests' clock (`-clockAt`) before 08:00 it is still at Pack, and from 08:00 On site.
    static func leaving() -> Library {
        var lib = make()
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Today.now)!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        if !lib.trips.isEmpty {
            lib.trips[0].startDate = day(0)
            lib.trips[0].endDate = day(2)
            _ = Library.setLeaveTime(&lib.trips[0], "08:00", home: false)
        }
        return lib
    }

    /// The sample library for a place's code (`-uiTestingPlaces <when>`, 0.69): the
    /// Garage's code is G4R (as if its label were printed), and its trip is moved:
    /// "soon" = it starts in 2 days, inside the packing week, so a code opens it on that
    /// place's lines; "home" = it began 3 days ago and ends today, every line ticked on
    /// the way out, so a code shows what goes back there. Anything else = the sample as
    /// it is (its trip a month ahead): a code shows everything kept there. The Garage
    /// holds the Headlamp and the Map.
    static func places(_ when: String) -> Library {
        var lib = make()
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        lib.meta[Library.placeCodeKey("G4R")] = .string("Garage")
        guard !lib.trips.isEmpty else { return lib }
        switch when {
        case "soon":
            lib.trips[0].startDate = day(2)
            lib.trips[0].endDate = day(4)
        case "home":
            lib.trips[0].startDate = day(-3)
            lib.trips[0].endDate = day(0)
            for n in lib.trips[0].entries.indices { lib.trips[0].entries[n].checked = true }
        default:
            break
        }
        return lib
    }

    /// The sample library with its trip inside the forecast's reach (`-uiTestingSoon`, 0.75): it
    /// starts in 10 days and lasts two nights — not yet the packing week — so Weather asks for
    /// the trip's own days. (The sample's own trip is a month ahead, past the reach: its weather
    /// card says when the forecast comes, and asks for none.)
    static func soon() -> Library {
        var lib = make()
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        if !lib.trips.isEmpty {
            lib.trips[0].startDate = day(10)
            lib.trips[0].endDate = day(12)
        }
        return lib
    }

    /// The sample library with notes to search (`-uiTestingNotes`, 0.69): the Passport's
    /// own note, and a note the Hiking template keeps for the Map — neither name says
    /// the words searched for.
    static func notes() -> Library {
        var lib = make()
        if let n = lib.items.firstIndex(where: { $0.name == "Passport" }) {
            lib.items[n].note = "Renew before May\nKeep it in the blue pouch with the tickets"
        }
        if let hiking = lib.templates.first(where: { $0.name == "Hiking" }),
           let map = lib.items.first(where: { $0.name == "Map" }),
           let m = lib.memberships.firstIndex(where: { $0.templateId == hiking.id && $0.itemId == map.id }) {
            lib.memberships[m].note = "The waterproof one, folded in the lid"
        }
        return lib
    }

    /// The sample library under way, with pockets and the times he leaves
    /// (`-uiTestingPockets`, 0.69): a Backpack with three pockets — Main, Front pocket,
    /// Lid — that the Phone charger (usually in the Front pocket) and the Headlamp (no
    /// usual pocket) go in; the Passport already ticked; "I leave at" 07:30 on the first
    /// day (yesterday, so no check is left for it) and 10:00 on the last for home.
    static func pockets() -> Library {
        var lib = underWay()
        guard let bag = lib.addBag(name: "Backpack") else { return lib }
        for p in ["Main", "Front pocket", "Lid"] { _ = lib.addPocket(bagId: bag.id, name: p) }
        for n in lib.items.indices where ["Phone charger", "Headlamp"].contains(lib.items[n].name) {
            lib.items[n].container = "Backpack"
        }
        if let charger = lib.items.first(where: { $0.name == "Phone charger" }) {
            _ = lib.setUsualPocket(thingId: charger.id, pocket: "Front pocket")
        }
        guard !lib.trips.isEmpty else { return lib }
        lib.trips[0].entries = buildTotalEntries(lib.trips[0], lib.resolvedTemplates())
        if let n = lib.trips[0].entries.firstIndex(where: { $0.name == "Passport" }) { lib.trips[0].entries[n].checked = true }
        _ = Library.setLeaveTime(&lib.trips[0], "07:30", home: false)
        _ = Library.setLeaveTime(&lib.trips[0], "10:00", home: true)
        return lib
    }

    /// Four bags for sorting Your bags and duplicating a bag (`-uiTestingBags`, 0.90 — his asks of
    /// 19 Oct 2026). Made 40, 30, 20 and 10 days ago — the Sports bag, the Camera bag, the Wheeled
    /// duffel, the Backpack — and arranged by him as Wheeled duffel, Sports bag, Backpack, Camera bag
    /// (`bag-0` … `bag-3`). The Map goes in the Camera bag (on the sample trip, a month ahead); the
    /// Towel in the Sports bag (on "Old coast", two months ago); the other two never went on a trip. So:
    /// A–Z Backpack, Camera bag, Sports bag, Wheeled duffel; Last used Camera bag, Sports bag, then
    /// Wheeled duffel and Backpack (his order); Last added Backpack, Wheeled duffel, Camera bag, Sports
    /// bag — and Last edited the same until one is changed. The Wheeled duffel is described in full —
    /// 23 kg, 90 litres, 3400 g, Exempel, Black, Duffel, Large, a red strap, a Lid pocket, a note — for
    /// Duplicate. All invented.
    static func bags() -> Library {
        var lib = make()
        let clock = PackingEnv.now
        defer { PackingEnv.now = clock }
        for (days, name) in [(40, "Sports bag"), (30, "Camera bag"), (20, "Wheeled duffel"), (10, "Backpack")] {
            let then = Date().addingTimeInterval(-Double(days) * 86_400)
            PackingEnv.now = { then }
            _ = lib.addBag(name: name)
        }
        PackingEnv.now = clock
        _ = lib.moveBag(named: "Wheeled duffel", by: -1)
        _ = lib.moveBag(named: "Wheeled duffel", by: -1)
        _ = lib.moveBag(named: "Backpack", by: -1)
        if let duffel = lib.bags().first(where: { $0.name == "Wheeled duffel" })?.id {
            _ = lib.setBag(id: duffel, maxKg: 23, capacityL: 90, emptyGrams: 3400)
            _ = lib.setBagDetails(BagDetails(brand: "Exempel", colour: "Black", type: .duffel, size: .large,
                                             sizeNote: "80 \u{00D7} 40 \u{00D7} 40 cm", marks: "red strap"), id: duffel)
            _ = lib.addPocket(bagId: duffel, name: "Lid")
            _ = lib.setThingNote(id: duffel, "Wheels squeak a little")
        }
        for n in lib.items.indices {
            if lib.items[n].name == "Map" { lib.items[n].container = "Camera bag" }
            if lib.items[n].name == "Towel" { lib.items[n].container = "Sports bag" }
        }
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        if !lib.trips.isEmpty { lib.trips[0].entries = buildTotalEntries(lib.trips[0], lib.resolvedTemplates()) }
        if let swim = lib.templates.first(where: { $0.name == "Swim" }) {
            var old = newEvent(name: "Old coast", startDate: day(-60), endDate: day(-58))
            old.activities = [swim.id]
            old.entries = buildTotalEntries(old, lib.resolvedTemplates())
            lib.trips.append(old)
        }
        return lib
    }

    /// The sample library for the Packing day (`-uiTestingPackingDay`, 0.79 — spec 07 part 17): a
    /// Day pack, one of his bags WITH an AirTag, that the Hiking boots and the Rain jacket go in;
    /// the rest stays in the carry-on (only a name on the lines, no AirTag). So the trip, a month
    /// ahead and at Pack, has two bags: the carry-on (5 lines, `day-bag-0`) and the Day pack (2,
    /// `day-bag-1`). `almost` (`-packingDayAlmost`): every station done but the last line — the
    /// Map unticked — so ticking it makes the day Ready (and Weigh, all weighed, stays shut).
    /// `byPlane` (`-packingDayByPlane`, 0.80 — spec 07 part 18 B): the trip goes by Plane, so Tags
    /// and the Bags card ask for each bag's tag number. `inner` (`-packingDayInner`, 0.86 — spec 07
    /// part 17 "0.86"): a Toiletry bag, one of his bags WITH an AirTag, that the Toothbrush goes in —
    /// and that is itself on Common base, packed in the carry-on. So the trip has three bags, the
    /// Toiletry bag first (the web app's bag order: `day-bag-0`, the carry-on `day-bag-1` with 5
    /// lines, the Day pack `day-bag-2`), and Tags asks only about the carry-on and the Day pack.
    static func packingDay(almost: Bool = false, byPlane: Bool = false, inner: Bool = false) -> Library {
        var lib = make()
        guard let pack = lib.addBag(name: "Day pack") else { return lib }
        _ = lib.setBagAirTag(id: pack.id, true)
        for n in lib.items.indices where ["Hiking boots", "Rain jacket"].contains(lib.items[n].name) {
            lib.items[n].container = "Day pack"
        }
        if inner, let base = lib.templates.first(where: { $0.name == "Common base" }),
           let wash = lib.addBag(name: "Toiletry bag") {
            _ = lib.setBagAirTag(id: wash.id, true)
            _ = lib.setOnTemplate(itemId: wash.id, templateId: base.id, on: true)
            for n in lib.items.indices {
                if lib.items[n].id == wash.id { lib.items[n].container = "Carry-on / hand luggage" }
                if lib.items[n].name == "Toothbrush" { lib.items[n].container = "Toiletry bag" }
            }
        }
        guard !lib.trips.isEmpty else { return lib }
        if byPlane { lib.trips[0].transport = "Plane" }
        lib.trips[0].entries = buildTotalEntries(lib.trips[0], lib.resolvedTemplates())
        guard almost else { return lib }
        let id = lib.trips[0].id
        for line in lib.trips[0].entries where line.name != "Map" { _ = lib.setChecked(true, tripId: id, entryId: line.id) }
        for (bag, grams) in [("Carry-on / hand luggage", 6400.0), ("Day pack", 2100.0)] {
            _ = lib.setBagOut(true, tripId: id, bag: bag)
            _ = lib.setWeighed(tripId: id, bag: bag, grams: grams)
            _ = lib.setNameTag(true, tripId: id, bag: bag)
            if let jpeg = JPEG.sample() { _ = lib.addBagPhoto(tripId: id, bag: bag, jpeg: jpeg) }
        }
        _ = lib.setAirTagIn(true, tripId: id, bag: "Day pack")
        if let jpeg = JPEG.sample() { _ = lib.setGroupPhoto(tripId: id, jpeg: jpeg) }
        return lib
    }

    /// The sample library for the Lost bag page (`-uiTestingLostBag`, 0.80 — spec 07 part 18 C):
    /// the Packing day's two bags (`packingDay`) on a trip by PLANE, with two flights (SK 1234 out,
    /// SK 1235 home), Málaga and a stay at the Hotel Exempel — but no bag-tag number; the Day pack
    /// (`bag-1`) a green Exempel backpack, medium, with a red strap, and one photo of it packed;
    /// the carry-on (`bag-0`) only a name on the lines, nothing known about it. His details for the
    /// desk: a name and a phone, no e-mail, no address. All invented.
    static func lostBag() -> Library {
        var lib = packingDay()
        guard !lib.trips.isEmpty else { return lib }
        let id = lib.trips[0].id
        lib.trips[0].transport = "Plane"
        _ = lib.setTravel(TripTravel(flights: [FlightLeg(number: "SK 1234", from: "ARN", to: "AGP"),
                                               FlightLeg(number: "SK 1235", from: "AGP", to: "ARN")],
                                     destination: "M\u{00E1}laga",
                                     stay: TripStay(name: "Hotel Exempel", address: "Calle Falsa 1\nM\u{00E1}laga", phone: "+34 900 000 000")),
                          tripId: id)
        _ = lib.setBagDetails(BagDetails(brand: "Exempel", colour: "Green", type: .backpack, size: .medium,
                                         sizeNote: "55 \u{00D7} 35 \u{00D7} 25 cm", marks: "red strap"), bag: "Day pack")
        if let jpeg = JPEG.sample() { _ = lib.addBagPhoto(tripId: id, bag: "Day pack", jpeg: jpeg) }
        lib.setDeskDetails(DeskDetails(name: "Kim Example", phone: "+46 70 000 00 00"))
        return lib
    }

    /// The sample library with its trip been and reviewed (`-uiTestingReviewed`), for the
    /// trip's page in his Obsidian vault (0.70): it ran from six days ago to three days
    /// ago, everything went, the carry-on was weighed (2.4 kg) and photographed, a sun hat
    /// was bought on site, the rain jacket's zip broke, the map was not used and a power
    /// bank was missed (onto Hiking). The review was saved yesterday — and no page is asked
    /// for, as after a review saved before 0.70, so the button starts from the beginning.
    static func reviewed() -> Library {
        var lib = make()
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        guard !lib.trips.isEmpty else { return lib }
        let id = lib.trips[0].id
        lib.trips[0].startDate = day(-6)
        lib.trips[0].endDate = day(-3)
        lib.trips[0].nights = 3
        for e in lib.trips[0].entries { lib.setChecked(true, tripId: id, entryId: e.id) }
        let bag = "Carry-on / hand luggage"
        lib.setWeighed(tripId: id, bag: bag, grams: 2400)
        if let jpeg = JPEG.sample() { _ = lib.addBagPhoto(tripId: id, bag: bag, jpeg: jpeg) }
        _ = lib.addBoughtOnSite(tripId: id, name: "Sun hat")
        if let jacket = lib.trips[0].entries.first(where: { $0.name == "Rain jacket" }) {
            lib.setHomeNote("zip broken", tripId: id, entryId: jacket.id)
        }
        let unused = Set(lib.trips[0].entries.filter { $0.name == "Map" }.map(\.id))
        let hiking = lib.templates.first { $0.name == "Hiking" }?.id ?? ""
        let when = cal.date(byAdding: .day, value: -1, to: Date()).map { ISO8601DateFormatter().string(from: $0) } ?? nowISO()
        lib.saveReview(tripId: id, unused: unused, missed: [Library.Missed(name: "Power bank", templateId: hiking)], when: when)
        lib.trips[0].extra[VAULT_WAITING_KEY] = nil
        return lib
    }

    /// The reviewed sample with its trip's dates taken away (`-uiTestingReviewedUndated`,
    /// 0.73): a trip reviewed but undated belongs in Done, folded under Reviewed — it sat
    /// in Coming up while the piles went by the dates alone.
    static func reviewedUndated() -> Library {
        var lib = reviewed()
        guard !lib.trips.isEmpty else { return lib }
        lib.trips[0].startDate = ""
        lib.trips[0].endDate = ""
        lib.trips[0].nights = 0
        return lib
    }

    /// The sample as stored after the two devices' saves of a template crossed (0.97, his check 6,
    /// `-uiTestingLostSection`): Hiking's record without its section Lights — the Headlamp's line
    /// still carries Lights' name — and Swim's Goggles naming a section whose name is stored nowhere
    /// (a line stored before 0.97, his "mvho3cjj-0-r6dbge").
    static func lostSection() -> [StoredRecord] {
        var lib = make()
        guard let hiking = lib.templates.first(where: { $0.name == "Hiking" })?.id,
              let swim = lib.templates.first(where: { $0.name == "Swim" })?.id,
              let goggles = lib.resolvedTemplate(id: swim)?.items.first(where: { $0.name == "Goggles" })?.memId
        else { return lib.records() }
        lib.updateMembership(memId: goggles) { $0.section = "lost7abc-0-x1y2z3" }
        return lib.records().map { r in
            guard r.table == .templates, r.key == hiking, var o = r.json.objectValue else { return r }
            var lost = r
            o["sections"] = .array([])
            lost.json = .object(o)
            return lost
        }
    }

    /// The sample library with a photo nothing shows any more, from long ago — what a
    /// trip deleted before 0.59 left behind (`-uiTestingOldPhoto`).
    static func oldPhoto() -> Library {
        var lib = make()
        lib.photos.append(PhotoRecord(id: "left-behind", data: "data:image/jpeg;base64,AQID", createdAt: "2026-01-01T09:00:00.000Z"))
        // …and one whose age cannot be read: never offered with the first, named on its own.
        lib.photos.append(PhotoRecord(id: "no-date", data: "data:image/jpeg;base64,BAUG", createdAt: ""))
        return lib
    }

    /// The sample library with every template a SECOND time, under new ids — what
    /// a device holds when two libraries have met on one account (31 August 2026,
    /// and again on 23 September). Used by `-uiTestingTwoLibraries`.
    static func doubled() -> Library {
        var lib = make()
        for template in lib.resolvedTemplates() {
            var twin = newList(name: template.name, group: template.group, role: template.role)
            twin.items = template.items.map { newItem(name: $0.name) }
            lib.saveTemplate(twin)
        }
        return lib
    }

    /// The sample library with Hiking under TWO headings and a thing under none
    /// (`-uiTestingSections`), for arranging a template: Lights (Headlamp, Spare
    /// batteries), Clothes (Hiking boots, Rain jacket, Wool socks), and the Map
    /// under no heading. Two things are new here, so the other tests' counts stay.
    /// Its trip is packed from Hiking as it now reads (0.64), so the trip sorted by
    /// Section has headings: Clothes, Lights, and Everything else — the base
    /// template's Headlamp wins over Hiking's, so the Lights line is the batteries.
    static func sectioned() -> Library {
        var lib = make()
        guard let hiking = lib.templates.first(where: { $0.name == "Hiking" }),
              var list = lib.resolvedTemplate(id: hiking.id) else { return lib }
        list.items += ["Spare batteries", "Wool socks"].map { newItem(name: $0) }
        lib.saveTemplate(list)
        for (name, things) in [("Lights", ["Headlamp", "Spare batteries"]),
                               ("Clothes", ["Hiking boots", "Rain jacket", "Wool socks"])] {
            guard let section = lib.addSection(templateId: hiking.id, name: name) else { continue }
            for thing in things {
                if let row = lib.resolvedTemplate(id: hiking.id)?.items.first(where: { $0.name == thing })?.memId {
                    lib.updateMembership(memId: row) { $0.section = section.id }
                }
            }
        }
        if !lib.trips.isEmpty { lib.trips[0].entries = buildTotalEntries(lib.trips[0], lib.resolvedTemplates()) }
        return lib
    }

    /// The sample library with a second workout and things for one context only
    /// (`-uiTestingWorkouts`), for Context PER WORKOUT (0.67): Run — Trail shoes
    /// (Outdoor), Treadmill towel (Indoor), Running cap (any) — and a Wetsuit (Outdoor)
    /// on Swim. A Quick trip of Swim indoors and Run outdoors is then five lines:
    /// Goggles, Swim cap, Towel, Trail shoes, Running cap. One Context for both (the old
    /// way, Indoor and Outdoor) would be all seven.
    static func workouts() -> Library {
        var lib = make()
        var run = newList(name: "Run", group: "WET")
        run.items = [newItem(name: "Trail shoes", contexts: ["Outdoor"]),
                     newItem(name: "Treadmill towel", contexts: ["Indoor"]),
                     newItem(name: "Running cap")]
        lib.saveTemplate(run)
        if let swim = lib.templates.first(where: { $0.name == "Swim" }), var full = lib.resolvedTemplate(id: swim.id) {
            full.items.append(newItem(name: "Wetsuit", contexts: ["Outdoor"]))
            lib.saveTemplate(full)
        }
        return lib
    }

    /// The sample library with an RV transport template (`-uiTestingTravel`, 0.76 — Travelling
    /// by): "Camper kit" (an invented name) holding Levelling blocks and Wheel chocks, under
    /// Templates → By transport. No Plane or Car template. The sample trip stays an ordinary
    /// one ("Car"), so it opens in Trip settings with Plane and RV both off.
    static func travel() -> Library {
        var lib = make()
        var camper = newList(name: "Camper kit", role: "transport", transport: "RV")
        camper.items = [newItem(name: "Levelling blocks"), newItem(name: "Wheel chocks")]
        lib.saveTemplate(camper)
        return lib
    }

    /// The sample library with his own headings on a grab list (`-uiTestingGrabHeadings`,
    /// 0.85): Outdoor bike (`grab-4`) as he might arrange it — "Check the tyres" above every
    /// heading (free text, no thing of his), then "On me" (Helmet, Sunglasses, Cycling gloves,
    /// Sports watch), "On the bike" (Drink / water bottle, Spare tube & pump, iPhone) and
    /// "After" (Towel, Recovery drink): ten things, three headings. Invented names.
    static func grabHeadings() -> Library {
        var lib = make()
        _ = lib.saveGrabList(id: "bike-out", lines: [
            .thing("Check the tyres"),
            .heading("On me"), .thing("Helmet"), .thing("Sunglasses"), .thing("Cycling gloves"), .thing("Sports watch"),
            .heading("On the bike"), .thing("Drink / water bottle"), .thing("Spare tube & pump"), .thing("iPhone"),
            .heading("After"), .thing("Towel"), .thing("Recovery drink"),
        ])
        return lib
    }

    /// The sample library with two kits (`-uiTestingKits`, 0.70): a Camp pouch (60 g, on
    /// Hiking, kept in the Garage) holding a Lighter (30 g, not allowed in the cabin), Spare
    /// cord (80 g) and Plasters (20 g, valid for 10 more days — before the trip ends); and a
    /// Wash bag (100 g, on no template, checked before each trip) holding the Toothbrush
    /// (still on Common base on its own) and Soap (90 g). Its trip is rebuilt as a new trip
    /// would be: the Wash bag in the toothbrush's place, the Camp pouch last — eight lines,
    /// the kits at `trip-line-2` (Wash bag) and `trip-line-7` (Camp pouch). A second trip
    /// from the same lists, "Autumn in the hills" two months ahead (`trip-row-1`, 0.73),
    /// stays live while a test reviews the first: the past and the live side by side.
    ///
    /// `underWay` (`-uiTestingKits -kitsUnderWay`, 0.73 "Where is my …?" for a thing in a
    /// kit): the trip began yesterday and ends in two days, and the Camp pouch usually goes
    /// in a Day pack with two pockets — Main, Front pocket — in its Front pocket.
    static func kits(underWay: Bool = false) -> Library {
        var lib = make()
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        guard let hiking = lib.templates.first(where: { $0.name == "Hiking" }) else { return lib }
        var made: [String: String] = [:]
        for (name, grams) in [("Camp pouch", 60.0), ("Lighter", 30), ("Spare cord", 80), ("Plasters", 20),
                              ("Wash bag", 100), ("Soap", 90)] {
            guard let t = lib.addThing(name: name) else { continue }
            made[name] = t.id
            _ = lib.updateThing(id: t.id) { $0.weight = grams }
        }
        guard let pouch = made["Camp pouch"], let wash = made["Wash bag"],
              let brush = lib.items.first(where: { $0.name == "Toothbrush" })?.id else { return lib }
        _ = lib.updateThing(id: pouch) { $0.storage = "Garage" }
        if let lighter = made["Lighter"] { _ = lib.updateThing(id: lighter) { $0.restricted = true } }
        if let plasters = made["Plasters"] { _ = lib.updateThing(id: plasters) { $0.expiry = day(10) } }
        _ = lib.setOnTemplate(itemId: pouch, templateId: hiking.id, on: true)
        // The pouch is NOT checked before each trip: switched off, as he may (a new kit starts on, 0.76).
        lib.setKit(kitId: pouch, contents: ["Lighter", "Spare cord", "Plasters"].compactMap { made[$0] }, check: false)
        lib.setKit(kitId: wash, contents: [brush] + ["Soap"].compactMap { made[$0] }, check: true)
        if underWay, let pack = lib.addBag(name: "Day pack") {
            for p in ["Main", "Front pocket"] { _ = lib.addPocket(bagId: pack.id, name: p) }
            _ = lib.updateThing(id: pouch) { $0.container = "Day pack" }
            _ = lib.setUsualPocket(thingId: pouch, pocket: "Front pocket")
            if !lib.trips.isEmpty {
                lib.trips[0].startDate = day(-1)
                lib.trips[0].endDate = day(2)
            }
        }
        if !lib.trips.isEmpty {
            lib.trips[0].entries = lib.builtLines(lib.trips[0])
            var later = newEvent(name: "Autumn in the hills", startDate: day(60), endDate: day(62))
            later.activities = lib.trips[0].activities
            lib.createTrip(later)
        }
        return lib
    }

    /// The sample library for batteries and To charge (`-uiTestingBattery`, 0.75 — spec 07 part
    /// 15): the kits sample (`kits()`) with its first trip starting TOMORROW, so its To charge card
    /// shows; a Power bank (180 g, with a battery) in the Camp pouch; the Toothbrush — in the Wash
    /// bag — with a battery. The Headlamp has none until a test switches it on. The card then
    /// reads "Toothbrush, in the Wash bag" (`trip-charge-0`) and "Power bank, in the Camp pouch"
    /// (`trip-charge-1`), "0 of 2"; the second trip, two months ahead (`trip-row-1`), has none.
    ///
    /// `byPlane` (`-uiTestingBattery -batteryByPlane`, 0.76 — a battery in the hold): the first
    /// trip goes by plane and the Camp pouch in the Checked luggage, so Before you go's flags have
    /// one line, "Power bank, in the Camp pouch" (`trip-check-cabin-0`) — the Toothbrush is in
    /// the Wash bag in the carry-on, and the Lighter, not allowed on board, is in the hold.
    ///
    /// `toDo` (`-batteryToDo`, 0.77 — Before you go, one card): Hiking has a reminder "Check the
    /// forecast" a week ahead, so with `byPlane` the trip's Before you go holds all three parts —
    /// the power bank in the hold, the reminder due, and To charge "0 of 2": 4 left.
    static func battery(byPlane: Bool = false, toDo: Bool = false) -> Library {
        var lib = kits()
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        if let bank = lib.addThing(name: "Power bank"), let pouch = lib.items.first(where: { $0.name == "Camp pouch" })?.id {
            _ = lib.updateThing(id: bank.id) { $0.weight = 180 }
            _ = lib.addToKit(kitId: pouch, thingId: bank.id)
            _ = lib.setThingBattery(id: bank.id, true)
        }
        if let brush = lib.items.first(where: { $0.name == "Toothbrush" })?.id { _ = lib.setThingBattery(id: brush, true) }
        if !lib.trips.isEmpty {
            lib.trips[0].startDate = day(1)
            lib.trips[0].endDate = day(3)
        }
        if byPlane, !lib.trips.isEmpty, let pouch = lib.items.first(where: { $0.name == "Camp pouch" })?.id {
            _ = lib.updateThing(id: pouch) { $0.container = "Checked luggage" }
            lib.trips[0].transport = "Plane"
            lib.trips[0].entries = lib.builtLines(lib.trips[0])
        }
        if toDo, !lib.trips.isEmpty, let hiking = lib.templates.first(where: { $0.name == "Hiking" }) {
            lib.addReminder(templateId: hiking.id, name: "Check the forecast", when: "week")
            lib.trips[0].entries = lib.builtLines(lib.trips[0])
        }
        return lib
    }

    /// The sample library for Apple Health in the review (`-uiTestingHealth`, 0.70): the
    /// workouts of `workouts()` plus a Race belt (Race only) on Run, a Bike template with a
    /// Bike helmet, the Towel on the common base too, and the Running cap Robin's (Kim is on
    /// most things, so Kim is "him"). ONE trip, "Training camp", six to two days ago, from
    /// Swim, Run and Bike (and the base), nothing ticked — its review asks about all 13
    /// lines, in this order: Passport, Phone charger, Toothbrush, Headlamp, Towel (base);
    /// Goggles, Swim cap, Wetsuit (Swim); Trail shoes, Treadmill towel, Running cap, Race
    /// belt (Run); Bike helmet (Bike). The invented Apple Health (`InventedHealth`) has three
    /// pool swims and two outdoor runs on those days, so "Use these" marks the Wetsuit, the
    /// Treadmill towel and the Bike helmet "didn't use", and leaves the base, the cap and
    /// the belt as they are.
    static func health() -> Library {
        var lib = workouts()
        if let run = lib.templates.first(where: { $0.name == "Run" }), var full = lib.resolvedTemplate(id: run.id) {
            full.items.append(newItem(name: "Race belt", contexts: ["Race"]))
            lib.saveTemplate(full)
        }
        lib.saveTemplate(newList(name: "Bike", group: "WET", items: [newItem(name: "Bike helmet")]))
        if let base = lib.templates.first(where: { $0.role == "base" }), var full = lib.resolvedTemplate(id: base.id) {
            full.items.append(newItem(name: "Towel"))
            lib.saveTemplate(full)
        }
        if let n = lib.items.firstIndex(where: { $0.name == "Running cap" }) { lib.items[n].ownedBy = "Robin" }
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        let id = { (name: String) in lib.templates.first { $0.name == name }?.id ?? "" }
        var trip = newEvent(name: "Training camp", startDate: day(-6), endDate: day(-2))
        trip.activities = [id("Swim"), id("Run"), id("Bike")]
        lib.trips = []
        _ = lib.createTrip(trip)
        return lib
    }

    /// The sample library for Before you start (`-uiTestingBeforeStart`, spec 07 part 19): Sun cream
    /// on the base running out on the trip's last day, and used up on an earlier trip ("Summer hike",
    /// reviewed, two months ago); the Map already needs replacing (the sample's own); the Headlamp has a
    /// battery; Hiking's reminders a week ahead, the day before, and on the morning (no preparation).
    /// Its trip starts in ten days, nothing ticked: 2 to buy (Sun cream, Map), 2 to prepare (the
    /// forecast from three days on, the route note), 1 to charge.
    static func beforeStart() -> Library {
        var lib = make()
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        if let base = lib.templates.first(where: { $0.role == "base" }), let cream = lib.addThing(name: "Sun cream") {
            _ = lib.setOnTemplate(itemId: cream.id, templateId: base.id, on: true)
            _ = lib.updateThing(id: cream.id) { $0.expiry = day(12); $0.consumable = true; $0.weight = 120 }
        }
        if let lamp = lib.items.first(where: { $0.name == "Headlamp" })?.id { _ = lib.setThingBattery(id: lamp, true) }
        if let hiking = lib.templates.first(where: { $0.name == "Hiking" }) {
            lib.addReminder(templateId: hiking.id, name: "Check the forecast", when: "week")
            lib.addReminder(templateId: hiking.id, name: "Leave a route note", when: "daybefore")
            lib.addReminder(templateId: hiking.id, name: "Water the plants", when: "morning")
        }
        let hiking = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        var summer = newEvent(name: "Summer hike", startDate: day(-60), endDate: day(-58))
        summer.activities = hiking
        let past = lib.createTrip(summer).id
        if let t = lib.trips.firstIndex(where: { $0.id == past }), let e = lib.trips[t].entries.firstIndex(where: { $0.name == "Sun cream" }) {
            lib.trips[t].entries[e].checked = true
            _ = lib.setUsedUp(true, tripId: past, entryId: lib.trips[t].entries[e].id)
            lib.trips[t].status = "done"
            lib.trips[t].reviewedAt = "\(day(-57))T10:00:00.000Z"
        }
        if let t = lib.trips.firstIndex(where: { $0.name == "Weekend in the hills" }) {
            lib.trips[t].startDate = day(10)
            lib.trips[t].endDate = day(12)
            lib.trips[t].entries = lib.builtLines(lib.trips[t])
        }
        return lib
    }

    /// The sample library with reminders on Hiking (`-uiTestingReminders`, 0.70 — spec
    /// 07, part 12): "Check the forecast" a week ahead and "Leave a route note" the day
    /// before; its trip starts in three days, so the first is due and the second not yet.
    static func reminders() -> Library {
        var lib = make()
        guard let hiking = lib.templates.first(where: { $0.name == "Hiking" }) else { return lib }
        lib.addReminder(templateId: hiking.id, name: "Check the forecast", when: "week")
        lib.addReminder(templateId: hiking.id, name: "Leave a route note", when: "daybefore")
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        if !lib.trips.isEmpty {
            lib.trips[0].startDate = day(3)
            lib.trips[0].endDate = day(5)
            lib.trips[0].entries = buildTotalEntries(lib.trips[0], lib.resolvedTemplates())
        }
        return lib
    }

    /// The sample library + "Long trips", a BIG always-packed template (23 things under
    /// Clothes, Toiletries, Tech, Papers and no heading; Socks and Snacks per night), and
    /// a Camp pouch kit holding a Lighter (`-uiTestingBigBase`, 0.71: "Make a small core
    /// from this…").
    static func bigBase() -> Library {
        var lib = make()
        var big = newList(name: "Long trips", role: "base")
        let heads = ["Clothes", "Toiletries", "Tech", "Papers"].map { TemplateSection(name: $0) }
        big.sections = heads
        func row(_ name: String, _ h: Int?, perNight: Bool = false) -> Item {
            var i = newItem(name: name); i.section = h.map { heads[$0].id } ?? ""; i.perNight = perNight; return i
        }
        big.items = [row("Socks", 0, perNight: true), row("T-shirt", 0), row("Trousers", 0), row("Sweater", 0),
                     row("Toothpaste", 1), row("Razor", 1), row("Deodorant", 1),
                     row("Laptop", 2), row("Cable", 2), row("Power bank", 2), row("Earphones", 2), row("Adapter", 2),
                     row("Wallet", 3), row("Notebook", 3), row("Pen", 3),
                     row("Umbrella", nil), row("Sunglasses", nil), row("Book", nil), row("Snacks", nil, perNight: true),
                     row("Water bottle", nil), row("Pillow", nil), row("Blanket", nil), row("Playing cards", nil)]
        lib.saveTemplate(big)
        if let pouch = lib.addThing(name: "Camp pouch"), let lighter = lib.addThing(name: "Lighter") {
            lib.setKit(kitId: pouch.id, contents: [lighter.id])
        }
        return lib
    }

    /// An invented library at the size of a real one (`-uiTestingBigLibrary`, 0.91 — for measuring how
    /// an edit feels, `EditTiming`): the `bags()` sample + 400 invented things on eight templates of 80,
    /// sixteen more bags, 24 trips built from three templates each (about 4,000 lines in all) and 20
    /// photos the size a camera's are after the app's squeeze. Nothing of his is in it.
    static func big() -> Library {
        var lib = bags()
        let groups = ["GA", "WET", "SNO", "BIK", "RUN", "TRV", "WRK", "HOM"]
        var names: [String] = []
        for n in 1...400 { names.append(String(format: "Invented thing %03d", n)) }
        var lists: [String] = []
        for k in 0..<8 {
            var l = newList(name: "Invented list \(k + 1)", group: groups[k])
            // 80 each, overlapping by 30 with the next: a thing on two or three templates, as his are.
            l.items = (0..<80).map { i in newItem(name: names[(k * 50 + i) % names.count]) }
            lib.saveTemplate(l)
            lists.append(l.name)
        }
        for n in 1...16 { lib.addBag(name: String(format: "Invented bag %02d", n)) }
        let bagNames = lib.bags().map(\.name)
        for n in lib.items.indices where lib.items[n].name.hasPrefix("Invented thing") {
            lib.items[n].weight = Double(20 + (n * 37) % 900)
            lib.items[n].container = bagNames[n % bagNames.count]
            lib.items[n].storage = ["Hall closet", "Garage", "Chest of drawers", "Bathroom cabinet"][n % 4]
        }
        let ids = lists.compactMap { name in lib.templates.first { $0.name == name }?.id }
        let cal = Calendar(identifier: .gregorian)
        func day(_ n: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: n, to: Date())!)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        for t in 0..<24 {
            var trip = newEvent(name: "Invented trip \(t + 1)", startDate: day(-400 + t * 17), endDate: day(-397 + t * 17))
            trip.activities = [ids[t % 8], ids[(t + 3) % 8], ids[(t + 5) % 8]]
            trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
            lib.trips.append(trip)
        }
        let things = lib.items.filter { $0.name.hasPrefix("Invented thing") }
        for k in 0..<20 {
            if let jpeg = JPEG.measuring(seed: k) { lib.addThingPhoto(id: things[k * 7].id, jpeg: jpeg) }
        }
        return lib
    }

    /// A DIFFERENT, smaller invented library, as a backup FILE. Under `-uiTesting`
    /// the restore button reads this instead of opening Apple's file window (which
    /// no test can drive): 2 things where the device holds 10, so a restore that
    /// only ADDS would be caught.
    static func fileToRestore() -> Data {
        var lib = Library()
        var day = newList(name: "Day out", role: "base")
        day.items = [newItem(name: "Water bottle"), newItem(name: "Sun hat")]
        lib.saveTemplate(day)
        return lib.backupData(exportedAt: "2026-09-22T09:00:00.000Z")
    }
}
