import Foundation
import PackingCore

// Find your things in Spotlight (0.92 — his yes of 19 Oct 2026 to: "type 'headlamp' in Spotlight
// on the iPhone or Mac and see the thing and where it is, without opening the app").
//
// WHAT SPOTLIGHT SHOWS. One result per thing of his: its name, and under it where it is NOW — the
// answer "Where is my …?" gives (`whereIs(thingId:today:)`, the one Siri says and Search shows
// first), in words made for a line under a name:
//   on the trip under way    "Packed in the Backpack · Front pocket"
//                            "Packed for home in the Backpack · Lid"
//                            "Not packed yet · Goes in the Backpack · Front pocket · Kept at home: Garage"
//   otherwise                "Usually in the Carry-on / hand luggage · Front pocket · Kept at home: Garage"
//   inside a kit             "In the Camp pouch · Usually in the Day pack · Front pocket · Kept at home: Garage"
//                            (the KIT's bag and pocket — and the kit's place at home: the thing is in the kit)
//   taken out of its kit     "Taken out of the Camp pouch · Usually in the Tote"
//   nothing said anywhere    "No usual bag or place at home yet"
// "Kept at home" is said with a colon, as the thing's page labels it: a place is any words he chose
// ("Kim's room", "Förråd"), and "in the …" would not fit them all. It is said only while the thing
// is at home — never once it is packed.
//
// WHAT IT IS FOUND BY. Its name and the line above, and these words (`keywords`), each once: its
// kind of thing, whose it is, the templates it is on, its brand and model, and its Swedish name (the
// web app kept his original wording; "pannlampa" finds the Headlamp). NOT its notes, serial number,
// Valid until, price, purchase link, warranty or when it was bought: Spotlight can show a result to
// anyone holding an unlocked device, and those are free text or private numbers — notes can hold a
// code or a name. (The iPhone's index is also locked away while the iPhone is locked — the app's
// side, `ThingSpotlight`.)
//
// WHICH THINGS. Every thing of his (`ownThings`) but the ones set to "Not in use" (`retired`) and the
// to-dos (a reminder is no thing to find). A bag is a thing: "Backpack" finds the bag.
//
// KEPT CURRENT. Each thing's words carry a fingerprint (`SpotlightThing.fingerprint`, stable across
// launches and devices); the app remembers the fingerprints it handed Spotlight and hands over again
// only what changed — added, renamed, moved, packed, given a photo — and takes out what went
// (`SpotlightWords.changes`). A change of these words in a later version bumps `SpotlightWords.version`,
// which changes every fingerprint, so everything is handed over again once.

/// One thing as Spotlight shows it.
public struct SpotlightThing: Equatable, Sendable {
    /// The thing's id.
    public var id: String
    /// Its name — the result's title.
    public var title: String
    /// Where it is now — the line under the name.
    public var place: String
    /// The other words it is found by.
    public var keywords: [String]
    /// Its first photo on this device ("" = none: Spotlight shows the app's icon).
    public var photoId: String

    public init(id: String, title: String, place: String, keywords: [String], photoId: String) {
        self.id = id; self.title = title; self.place = place; self.keywords = keywords; self.photoId = photoId
    }

    /// The result's identifier in Spotlight — what a tapped result hands back to the app.
    public var identifier: String { SpotlightThing.prefix + id }

    /// What every thing's identifier starts with (a later kind of result — a trip — gets its own).
    public static let prefix = "thing:"

    /// The thing's id inside a tapped result's identifier; nil for one that is not a thing's.
    public static func thingId(_ identifier: String) -> String? {
        guard identifier.hasPrefix(prefix) else { return nil }
        let id = String(identifier.dropFirst(prefix.count))
        return id.isEmpty ? nil : id
    }

    /// Everything Spotlight is handed, as one short text that is the same on every launch and
    /// every device (FNV-1a, 64 bits — Swift's own `hashValue` changes from launch to launch).
    public var fingerprint: String {
        let said = ["v\(SpotlightWords.version)", id, title, place, keywords.joined(separator: "\u{1F}"), photoId]
            .joined(separator: "\u{1E}")
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in said.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

public enum SpotlightWords {
    /// The words' own version: a change to how a line or the keywords are made bumps it, and every
    /// thing is handed to Spotlight again.
    public static let version = 1

    /// The line under a thing's name: where it is now (see the top of this file). `keptAt` is where
    /// it is kept at home — for a thing inside a kit, where the kit is kept.
    public static func place(_ a: WhereAnswer, keptAt: String) -> String {
        var parts: [String] = []
        if !a.kit.isEmpty { parts.append("In the \(a.kit)") }
        if !a.takenOutOf.isEmpty { parts.append("Taken out of the \(a.takenOutOf)") }
        let bag = jsTrim(a.bag)
        // "the Backpack · Front pocket" — a pocket is a bag's, so none is said without its bag.
        let inBag = bag.isEmpty ? "" : "the " + Library.bagAndPocket(bag, a.pocket)
        switch a.kind {
        case .packed: parts.append(inBag.isEmpty ? "Packed, not in a bag" : "Packed in \(inBag)")
        case .packedHome: parts.append(inBag.isEmpty ? "Packed for home, not in a bag" : "Packed for home in \(inBag)")
        case .notPacked:
            parts.append("Not packed yet")
            if !inBag.isEmpty { parts.append("Goes in \(inBag)") }
        case .usual:
            if !inBag.isEmpty { parts.append("Usually in \(inBag)") }
        }
        // Where it is kept at home — only while it is there (not once it is packed).
        let home = jsTrim(keptAt)
        if !home.isEmpty, a.kind == .usual || a.kind == .notPacked { parts.append("Kept at home: \(home)") }
        return parts.isEmpty ? "No usual bag or place at home yet" : parts.joined(separator: " \u{00B7} ")
    }

    /// The other words a thing is found by, each once (capitals and accents aside), in this order:
    /// kind of thing, whose it is, its templates, brand, model, its Swedish name. Never its name
    /// again, and nothing private (notes, serial, Valid until, price, link, warranty, bought).
    public static func keywords(_ thing: Item, templates: [String]) -> [String] {
        var seen: Set<String> = [normName(thing.name)]
        var out: [String] = []
        for word in [thing.category, thing.ownedBy] + templates + [thing.manufacturer, thing.model, thing.swedish] {
            let clean = jsTrim(word)
            guard !clean.isEmpty, seen.insert(normName(clean)).inserted else { continue }
            out.append(clean)
        }
        return out
    }

    /// What to hand Spotlight and what to take out of it: every thing whose fingerprint differs from
    /// the one handed over last (or that was never handed over), and every thing handed over that is
    /// no longer to be shown (deleted, set to Not in use, made a to-do). In the order given.
    public static func changes(_ now: [SpotlightThing], indexed: [String: String]) -> (put: [SpotlightThing], drop: [String]) {
        let put = now.filter { indexed[$0.id] != $0.fingerprint }
        let keep = Set(now.map(\.id))
        let drop = indexed.keys.filter { !keep.contains($0) }.sorted()
        return (put, drop)
    }
}

extension Library {
    /// Every thing Spotlight shows, A–Z as Your things lists them (see the top of this file).
    public func spotlightThings(today: String) -> [SpotlightThing] {
        let ctx = SpotlightContext(self, today: today)
        return thingRows().compactMap { row in spotlightThing(row.item, templates: row.templates, ctx) }
    }

    /// One thing as Spotlight shows it; nil for no thing, or one Spotlight does not show.
    public func spotlightThing(id: String, today: String) -> SpotlightThing? {
        guard let row = thingRows().first(where: { $0.item.id == id }) else { return nil }
        return spotlightThing(row.item, templates: row.templates, SpotlightContext(self, today: today))
    }

    private func spotlightThing(_ thing: Item, templates: [String], _ ctx: SpotlightContext) -> SpotlightThing? {
        guard !thing.retired, !Library.isReminder(thing), !jsTrim(thing.name).isEmpty,
              let a = whereIs(thingId: thing.id, today: ctx.today, kits: ctx.kits, trip: ctx.trip) else { return nil }
        // Inside its kit (not taken out): it is where the kit is, at home too.
        let kept = a.kit.isEmpty ? thing.storage : (ctx.kits.holder[thing.id].flatMap { ctx.byId[$0]?.storage } ?? "")
        let photo = firstThingPhoto(id: thing.id)?.id ?? ""
        return SpotlightThing(id: thing.id, title: jsTrim(thing.name), place: SpotlightWords.place(a, keptAt: kept),
                              keywords: SpotlightWords.keywords(thing, templates: templates), photoId: photo)
    }
}

/// What every thing's answer shares, worked out once for all of them: who holds what, the trip under
/// way, the things by id. (Asked thing by thing, `whereIs(thingId:today:)` works out the kits again
/// for every thing — his ~420 things, after every change.)
struct SpotlightContext {
    let today: String
    let kits: KitIndex
    let trip: TripEvent?
    let byId: [String: Item]

    init(_ library: Library, today: String) {
        self.today = today
        kits = library.kitIndex()
        trip = library.tripUnderWay(today: today)
        var byId: [String: Item] = [:]
        for i in library.items where byId[i.id] == nil { byId[i.id] = i }
        self.byId = byId
    }
}
