import XCTest
@testable import PackingCore

// Shared fixtures for the catalogue section's tests. INVENTED DATA ONLY.

/// JS: `const DATA_URL = 'data:image/jpeg;base64,/9j/4AAQSkZJRg=='`
let CATALOGUE_DATA_URL = "data:image/jpeg;base64,/9j/4AAQSkZJRg=="

/// JS: `richItem()` — a fully-described physical object, the way a well-kept item looks.
func catalogueRichItem() -> Item {
    newItem(
        name: "Insta360 X4", category: "electronics", container: "Day pack", phase: "day",
        weight: 203, storage: "Chest of drawers",
        photos: ["photo-abc123"], thumb: "data:image/jpeg;base64,AAAA",
        maintenance: Maintenance(intervalDays: 90, lastDone: "2026-05-01"),
        manufacturer: "Insta360", model: "X4",
        acquired: "2025-03-01", price: 4990, currency: "SEK", purchaseLink: "https://example.com",
        condition: "good", serial: "IX4-99812", qtyOwned: 1, warranty: "2027-03-01"
    )
}

/// A small stand-in for the web app's `seedLists()` (js/seed.js — 936 lines of the
/// owner's real lists, which are not part of this package and must not be: the
/// repository is public). It has every property the five seed-based JS tests lean on:
///   • "Socks" on several templates — most follow the default bag, some override it;
///   • "Towel" on Bike as an after-ride REMINDER and on Swim as a packable item;
///   • a "Golf" list; conditions of every kind; a same-name pair that differs only in
///     case; a blank-named row that must be ignored everywhere.
func miniSeedLists() -> [PackList] {
    func it(_ name: String, sv: String = "", cat: String = "Comfort & misc", con: String = "Duffel bag",
            ph: String = "week", rem: Bool = false, seas: [String] = [], ctx: [String] = [],
            tr: [String] = [], cater: [String] = [], we: [String] = [], short: Bool = false,
            charge: Bool = false, note: String = "") -> Item {
        newItem(name: name, swedish: sv, category: cat, container: con, phase: ph,
                itemType: rem ? "reminder" : "item", charging: charge, shortList: short,
                seasons: seas, contexts: ctx, transports: tr, catering: cater, weather: we, note: note)
    }
    return [
        newList(name: "Run", group: "WET", items: [
            it("Running shoes", sv: "Löparskor", cat: "Footwear", short: true),
            it("Socks", sv: "Strumpor", cat: "Clothing", short: true),
            it("Cap", cat: "Clothing", seas: ["Summer"]),
            it("Race belt", cat: "Sport gear", ctx: ["Race"]),
            it("Headlamp", cat: "Electronics", ctx: ["Outdoor"], charge: true),
        ]),
        newList(name: "Bike", group: "WET", items: [
            it("Helmet", cat: "Sport gear", con: "Triathlon bag"),
            it("Socks", sv: "Strumpor", cat: "Clothing"),
            it("Towel", sv: "Handduk", cat: "Toiletries", ph: "after", rem: true),
            it("Rain jacket", cat: "Adventure clothing", we: ["rain"]),
        ]),
        newList(name: "Swim", group: "WET", items: [
            it("Goggles", cat: "Sport gear", con: "Swim bag", ctx: ["Indoor"]),
            it("Towel", sv: "Handduk", cat: "Toiletries", ph: "after"),
            it("  "),   // blank-named: never an item, never a membership
        ]),
        newList(name: "Golf", group: "GA", items: [
            it("Golf clubs", cat: "Sport gear", con: "Golf bag"),
            it("Sunscreen", cat: "Toiletries", con: "Toiletry bag", seas: ["Summer"]),
            it("Rain jacket", cat: "Adventure clothing", con: "Golf bag", we: ["rain"]),
            it("socks", cat: "Clothing"),   // same thing, typed differently
        ]),
        newList(name: "Travel", role: "base", items: [
            it("Passport", cat: "Documents & money", con: "Carry-on / hand luggage", ph: "door", tr: ["Plane"]),
            it("Socks", sv: "Strumpor", cat: "Clothing", con: "Checked luggage"),
            it("Toothbrush", cat: "Toiletries", con: "Toiletry bag", ph: "morning"),
        ]),
        newList(name: "RV", role: "transport", transport: "RV", items: [
            it("Camping stove", cat: "Food & drink", con: "RV storage box", tr: ["RV"], cater: ["self", "mixed"]),
            it("Socks", sv: "Strumpor", cat: "Clothing", con: "RV storage box"),
        ]),
    ]
}
