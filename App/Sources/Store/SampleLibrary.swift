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
        // Two things the buy-list should offer, for two different reasons.
        if let n = lib.items.firstIndex(where: { $0.name == "Map" }) { lib.items[n].condition = "retire" }
        if let n = lib.items.firstIndex(where: { $0.name == "Toothbrush" }) { lib.items[n].consumable = true }
        lib.saveTemplate(list("Swim", group: "WET", ["Goggles", "Swim cap", "Towel"]))
        // His lists are built in sections, so the sample has one too.
        if let hiking = lib.templates.first(where: { $0.name == "Hiking" }),
           let lights = lib.addSection(templateId: hiking.id, name: "Lights"),
           let row = lib.resolvedTemplate(id: hiking.id)?.items.first(where: { $0.name == "Headlamp" })?.memId {
            lib.updateMembership(memId: row) { $0.section = lights.id }
        }
        // One trip, built from Hiking (and the base list, as a trip is).
        var trip = newEvent(name: "Weekend in the hills", startDate: "2026-10-03", endDate: "2026-10-05")
        trip.activities = lib.templates.filter { $0.name == "Hiking" }.map { $0.id }
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips = [trip]
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
