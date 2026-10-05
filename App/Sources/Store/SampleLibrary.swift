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
