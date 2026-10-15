import Foundation
import PackingCore

// The Packing day — his yes of 13 Oct 2026, from his own packing walk-through: the bags laid
// out on the living-room floor for a week; pack per kit, then per template, then per place it
// is kept; take breaks; weigh; name tags and AirTags; photos for lost luggage; ready. Inside a
// trip's Pack step, a row of STATIONS — Bags out → Pack → Weigh → Tags → Photos → Ready — each
// green when it is done, a tap opens it, and the next open one is offered. (Spec 07, part 17.)
//
// Here is what each station asks and when it is done; the screens only show it. Everything
// is kept on the trip (or, for "Has an AirTag", on the bag), in extra keys — so it is synced,
// backed up and restored with its record, and the web app's model is untouched (parity
// 211/211). The ticks are kept by the bag's NAME, as the trip's scale readings and bag photos
// are, and follow a rename the same way (`moveBagNotes` in Bags.swift).

/// A trip's extra key: the bags ticked "out" (Bags out), `[bag name]`. Removed when empty.
public let DAY_BAGS_OUT_KEY = "dayBagsOut"
/// A trip's extra key: the bags whose name tag is on (Tags), `[bag name]`.
public let DAY_NAME_TAGS_KEY = "dayNameTags"
/// A trip's extra key: the bags whose AirTag is in (Tags), `[bag name]`.
public let DAY_AIRTAGS_KEY = "dayAirTags"
/// A trip's extra key: the id of the ONE photo of all the trip's bags together (Photos).
public let DAY_GROUP_PHOTO_KEY = "dayBagsPhoto"
/// A trip's extra key: true once the day has opened Weigh by itself (the last thing ticked).
public let DAY_WEIGH_OFFERED_KEY = "dayWeighOffered"
/// A bag's (thing's) extra key: true = it has an AirTag; absent = it has none. Never false.
public let AIRTAG_KEY = "airTag"
/// The bag-name lists the day keeps on a trip — they follow a bag's rename (Bags.swift). Since 0.81
/// also the bags "+ Add a bag" put on the trip (`DAY_ADDED_BAGS_KEY`, PackingStations.swift).
public let DAY_BAG_KEYS = [DAY_BAGS_OUT_KEY, DAY_NAME_TAGS_KEY, DAY_AIRTAGS_KEY, DAY_ADDED_BAGS_KEY]
/// Every key the day writes on a trip — none travels in a shared trip (Sharing.swift).
public let DAY_TRIP_KEYS = DAY_BAG_KEYS + [DAY_GROUP_PHOTO_KEY, DAY_WEIGH_OFFERED_KEY]

/// The six stations, in the row's order.
public enum PackingDayStation: String, CaseIterable, Sendable, Identifiable {
    case bagsOut = "bags", pack, weigh, tags, photos, ready

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .bagsOut: return "Bags out"
        case .pack: return "Pack"
        case .weigh: return "Weigh"
        case .tags: return "Tags"
        case .photos: return "Photos"
        case .ready: return "Ready"
        }
    }

    /// The word on its chip, in the trip's row and at the top of the sheet (0.84, his ask of 15
    /// Oct 2026: shorter chips) — "Bags", "Pack", "Weigh", "Tag", "Photo", "Ready". `name` stays
    /// the full name where there is room to read it: the sheet's "Next: Bags out", Ready's list
    /// of stations, How it works and Words.
    public var chip: String {
        switch self {
        case .bagsOut: return "Bags"
        case .pack: return "Pack"
        case .weigh: return "Weigh"
        case .tags: return "Tag"
        case .photos: return "Photo"
        case .ready: return "Ready"
        }
    }

    /// Bags out, Weigh, Tags and Photos ask about the trip's bags: with none, they cannot be done.
    public var needsBags: Bool { self == .bagsOut || self == .weigh || self == .tags || self == .photos }

    /// The station's own mark — his pick of 13 Oct 2026 from the station sheet: one 1.9 stroke
    /// on the 24-point grid, round caps and joins, no fill, as the loop's step marks.
    public var mark: LoopStepMark {
        switch self {
        case .bagsOut:   // A — two bags side by side on the floor: a carry-on, handle up, and a duffel
            return LoopStepMark(key: "bagsOnFloor", label: "Two bags on the floor",
                                path: "M2.5 20.5h19 M5.1 9.5h4.8a1.3 1.3 0 0 1 1.3 1.3v6.4a1.3 1.3 0 0 1 -1.3 1.3h-4.8a1.3 1.3 0 0 1 -1.3 -1.3v-6.4a1.3 1.3 0 0 1 1.3 -1.3Z M6 9.5V5.5h3v4 M5.6 18.5v2 M9.4 18.5v2 M13.5 20.5v-3.7a2.8 2.8 0 0 1 2.8-2.8h2.4a2.8 2.8 0 0 1 2.8 2.8v3.7 M15.6 14c0-1.7.8-2.7 1.9-2.7s1.9 1 1.9 2.7")
        case .pack:      // C — a list curving into an open case: packing from the list
            return LoopStepMark(key: "listIntoCase", label: "A list going into an open case",
                                path: "M4 12.5h16 M4 12.5v5.8c0 1.2 1 2.2 2.2 2.2h11.6c1.2 0 2.2-1 2.2-2.2v-5.8 M4 4h6 M4 7.2h4.5 M13 4.5c3.2 0 5 1.6 5 5 M16 7.5l2 2 2-2")
        case .weigh:     // A — a luggage scale held up: grip, round dial, a bag hanging from it
            return LoopStepMark(key: "luggageScale", label: "A luggage scale, a bag hanging from it",
                                path: "M9 2.8h6 M12 2.8v2.3 M8.8 8.3a3.2 3.2 0 1 0 6.4 0a3.2 3.2 0 1 0 -6.4 0 M12 8.3l1.3-1.3 M12 11.5v1.8 M6.6 16h10.8a1.6 1.6 0 0 1 1.6 1.6v1.8a1.6 1.6 0 0 1 -1.6 1.6h-10.8a1.6 1.6 0 0 1 -1.6 -1.6v-1.8a1.6 1.6 0 0 1 1.6 -1.6Z M9.5 16v-1.7c0-.6.4-1 1-1h3c.6 0 1 .4 1 1V16")
        case .tags:      // A — a luggage tag on its string, a round AirTag beside it
            return LoopStepMark(key: "tagAndAirTag", label: "A luggage tag and an AirTag",
                                path: "M3.5 10.5 7.75 6.5 12 10.5V19.5c0 .6-.4 1-1 1H4.5c-.6 0-1-.4-1-1Z M7.75 10h.01 M7.75 10c0-3 1.5-5.5 4.5-6 M6 15h3.5 M6 17.5h2.5 M14.25 16a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0 -7 0 M17.75 16h.01")
        case .photos:    // C — a photo print, slightly tilted, a bag in the picture
            return LoopStepMark(key: "photoPrint", label: "A photo print with a bag",
                                path: "M4.81 3.92L16.69 2.25A1.5 1.5 -8 0 1 18.38 3.53L20.47 18.38A1.5 1.5 -8 0 1 19.19 20.08L7.31 21.75A1.5 1.5 -8 0 1 5.62 20.47L3.53 5.62A1.5 1.5 -8 0 1 4.81 3.92Z M5.13 17L19.98 14.92 M8.96 9.8L14.31 9.05A1 1 -8 0 1 15.44 9.9L15.72 11.88A1 1 -8 0 1 14.87 13.01L9.52 13.76A1 1 -8 0 1 8.39 12.91L8.11 10.93A1 1 -8 0 1 8.96 9.8Z M10.25 9.62L10.1 8.53C10.04 8.13 10.3 7.8 10.69 7.74L12.08 7.55C12.48 7.49 12.82 7.75 12.87 8.14L13.02 9.23")
        case .ready:     // A — the app's own door (the "I leave at" mark), a bag standing by it
            return LoopStepMark(key: "bagByDoor", label: "A bag by the door",
                                path: "M2.5 20.5h19 M4.5 20.5V4.8A1.3 1.3 0 0 1 5.8 3.5h6.4A1.3 1.3 0 0 1 13.5 4.8V20.5 M10.5 12.5h1.2 M16.7 11h3.1a1.2 1.2 0 0 1 1.2 1.2v5.1a1.2 1.2 0 0 1 -1.2 1.2h-3.1a1.2 1.2 0 0 1 -1.2 -1.2v-5.1a1.2 1.2 0 0 1 1.2 -1.2Z M17 11V8h2.5v3 M16.8 18.5v2 M19.7 18.5v2")
        }
    }

    /// The Packing day's own mark (B): a sun rising out of an open case.
    public static let dayMark = LoopStepMark(key: "sunCase", label: "A sun rising out of an open case",
                                             path: "M4 12.5h16 M4 12.5v5.8c0 1.2 1 2.2 2.2 2.2h11.6c1.2 0 2.2-1 2.2-2.2v-5.8 M8.4 12.5a3.6 3.6 0 0 1 7.2 0 M12 6.9L12 4.7 M7.71 8.9L6.02 7.49 M16.29 8.9L17.98 7.49")
}

/// Where a trip's Packing day stands: its bags and what each station has done.
public struct PackingDay: Equatable, Sendable {
    /// One bag of the trip, as the day sees it.
    public struct Bag: Equatable, Sendable {
        /// As the trip's lines name it.
        public var name: String
        /// Its lines not set aside (reminders left out) — "6 things".
        public var things: Int
        public var out: Bool
        /// What the luggage scale said, in grams; nil = not weighed.
        public var scaleGrams: Double?
        public var nameTag: Bool
        /// The bag has an AirTag (the bag's own switch) — only then is its AirTag asked for.
        public var hasAirTag: Bool
        public var airTag: Bool
        /// Its photos of it packed, as stored (one on its way from the other device counts).
        public var photos: Int
        public init(name: String, things: Int = 0, out: Bool = false, scaleGrams: Double? = nil, nameTag: Bool = false,
                    hasAirTag: Bool = false, airTag: Bool = false, photos: Int = 0) {
            self.name = name; self.things = things; self.out = out; self.scaleGrams = scaleGrams
            self.nameTag = nameTag; self.hasAirTag = hasAirTag; self.airTag = airTag; self.photos = photos
        }
    }

    public var bags: [Bag]
    /// The trip header's counts: lines not set aside, and how many of them are ticked.
    public var packed: Int
    public var total: Int
    /// The photo of all the bags together; "" = none.
    public var groupPhoto: String

    public init(bags: [Bag], packed: Int, total: Int, groupPhoto: String = "") {
        self.bags = bags; self.packed = packed; self.total = total; self.groupPhoto = groupPhoto
    }

    /// With two bags or more, a photo of all of them together is asked for; with one, the
    /// bag's own photo is that photo.
    public var groupPhotoAsked: Bool { bags.count > 1 }

    /// A station that asks about the bags cannot be done on a trip without any.
    public func usable(_ s: PackingDayStation) -> Bool { !s.needsBags || !bags.isEmpty }

    /// How much of a station is done, of how much it asks: Bags out the bags out; Pack the
    /// header's count; Weigh the bags weighed; Tags the ticks asked for (a name tag per bag, an
    /// AirTag per bag that has one); Photos each bag's photo and the one of all of them; Ready
    /// the other stations that can be done.
    public func counts(_ s: PackingDayStation) -> (done: Int, of: Int) {
        switch s {
        case .bagsOut: return (bags.filter(\.out).count, bags.count)
        case .pack: return (packed, total)
        case .weigh: return (bags.filter { ($0.scaleGrams ?? 0) > 0 }.count, bags.count)
        case .tags:
            let asked = bags.count + bags.filter(\.hasAirTag).count
            let on = bags.filter(\.nameTag).count + bags.filter { $0.hasAirTag && $0.airTag }.count
            return (on, asked)
        case .photos:
            let group = groupPhotoAsked ? 1 : 0
            return (bags.filter { $0.photos > 0 }.count + (groupPhotoAsked && !groupPhoto.isEmpty ? 1 : 0), bags.count + group)
        case .ready:
            let others = PackingDayStation.allCases.filter { $0 != .ready && usable($0) }
            return (others.filter(done).count, others.count)
        }
    }

    /// Is a station done? Pack by the trip header's own rule (something to pack, and all of it
    /// packed); a station that asks about bags, when every bag has what it asks; Ready when
    /// every other station that can be done is. A station that cannot be done is not done.
    public func done(_ s: PackingDayStation) -> Bool {
        guard usable(s) else { return false }
        let c = counts(s)
        if s == .pack { return c.of > 0 && c.done == c.of }
        return c.done == c.of
    }

    /// All green: Ready to go.
    public var ready: Bool { done(.ready) }

    /// The next station to do: the first, in the row's order, that can be done and is not —
    /// Ready when all are.
    public var current: PackingDayStation {
        PackingDayStation.allCases.first { $0 != .ready && usable($0) && !done($0) } ?? .ready
    }

    /// The station offered after `shown`: the first open one after it, round from the start
    /// again, never `shown` itself; Ready only when nothing else is open; none from Ready.
    public func next(after shown: PackingDayStation) -> PackingDayStation? {
        guard shown != .ready else { return nil }
        let all = PackingDayStation.allCases.filter { $0 != .ready }
        let start = all.firstIndex(of: shown) ?? 0
        for k in 1..<all.count {
            let s = all[(start + k) % all.count]
            if usable(s) && !done(s) { return s }
        }
        return .ready
    }

    /// What a station says: "1 of 2 out", "12 of 40 packed", "1 of 2 weighed", "3 of 4
    /// ticked", "1 of 3 photos", "3 of 5 done" — Ready, once all are green, "Ready to go".
    public func words(_ s: PackingDayStation) -> String {
        let c = counts(s)
        switch s {
        case .bagsOut: return "\(c.done) of \(c.of) out"
        case .pack: return "\(c.done) of \(c.of) packed"
        case .weigh: return "\(c.done) of \(c.of) weighed"
        case .tags: return "\(c.done) of \(c.of) ticked"
        case .photos: return "\(c.done) of \(c.of) photo\(c.of == 1 ? "" : "s")"
        case .ready: return ready ? "Ready to go" : "\(c.done) of \(c.of) done"
        }
    }

    /// A station's state in a word or a few — what a chip's value says: "done", "no bags yet",
    /// or its words.
    public func state(_ s: PackingDayStation) -> String {
        guard usable(s) else { return "no bags yet" }
        return done(s) ? "done" : words(s)
    }
}

extension Library {
    // MARK: - The trip's bags

    /// The bags a trip's Packing day asks about: the bags its Bags card lists — every bag a
    /// line not set aside is packed in, reminders left out, in the card's order — without "Not
    /// in a bag" (the card's "Other": loose things are no bag to lay out, weigh, tag or photograph);
    /// since 0.81 then the bags "+ Add a bag" put on the trip, empty ones too, in the order added.
    public func dayBags(tripId: String) -> [String] { dayRows(tripId: tripId).map(\.load.container) }

    /// The Bags card's rows the day asks about (see `dayBags`).
    func dayRows(tripId: String) -> [WeighedBag] {
        weighedBags(tripId: tripId).filter { Library.isRealBag($0.load.container) && ($0.load.items > 0 || $0.added) }
    }

    /// A bag's name that is one: not empty, not "Other" (no bag).
    static func isRealBag(_ name: String) -> Bool { !jsTrim(name).isEmpty && name != "Other" }

    /// Where a trip's Packing day stands. Nil for no such trip.
    public func packingDay(tripId: String) -> PackingDay? {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return nil }
        let p = progress(trip.entries)
        let scale = weighed(tripId: tripId)
        let out = Library.dayNames(trip, DAY_BAGS_OUT_KEY)
        let tags = Library.dayNames(trip, DAY_NAME_TAGS_KEY)
        let airs = Library.dayNames(trip, DAY_AIRTAGS_KEY)
        func has(_ names: [String], _ bag: String) -> Bool { names.contains { normName($0) == normName(bag) } }
        let bags = dayRows(tripId: tripId).map { w in
            let name = w.load.container
            return PackingDay.Bag(name: name, things: w.load.items, out: has(out, name), scaleGrams: scale[name],
                                  nameTag: has(tags, name), hasAirTag: hasAirTag(container: name), airTag: has(airs, name),
                                  photos: bagPhotoIds(tripId: tripId, bag: name).count)
        }
        return PackingDay(bags: bags, packed: p.done, total: p.total, groupPhoto: Library.groupPhotoId(trip))
    }

    // MARK: - Bags out and Tags: ticks of the trip, per bag

    /// The bag names one of the day's lists holds on a trip (blank ones left out).
    static func dayNames(_ trip: TripEvent, _ key: String) -> [String] {
        (trip.extra[key]?.arrayValue ?? []).compactMap(\.stringValue).filter { !jsTrim($0).isEmpty }
    }

    /// Tick (or untick) a bag in one of the day's lists. The name is kept as given; the lists
    /// compare by `normName`, so one bag is never in a list twice. Empty lists go.
    mutating func setDayTick(_ on: Bool, key: String, tripId: String, bag: String) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }), Library.isRealBag(bag) else { return false }
        var names = Library.dayNames(trips[n], key).filter { normName($0) != normName(bag) }
        if on { names.append(bag) }
        trips[n].extra[key] = names.isEmpty ? nil : .array(names.map(JSONValue.string))
        trips[n].updatedAt = nowISO()
        return true
    }

    /// Bags out: the bag is laid out (or not).
    @discardableResult
    public mutating func setBagOut(_ on: Bool, tripId: String, bag: String) -> Bool {
        setDayTick(on, key: DAY_BAGS_OUT_KEY, tripId: tripId, bag: bag)
    }

    /// Tags: the bag's name tag is on (or not).
    @discardableResult
    public mutating func setNameTag(_ on: Bool, tripId: String, bag: String) -> Bool {
        setDayTick(on, key: DAY_NAME_TAGS_KEY, tripId: tripId, bag: bag)
    }

    /// Tags: the bag's AirTag is in it (or not).
    @discardableResult
    public mutating func setAirTagIn(_ on: Bool, tripId: String, bag: String) -> Bool {
        setDayTick(on, key: DAY_AIRTAGS_KEY, tripId: tripId, bag: bag)
    }

    // MARK: - Has an AirTag: the bag's own

    /// Does this bag have an AirTag? Its own switch (one of his bags); a bag that is only a
    /// name on the lines has none.
    public static func hasAirTag(_ bag: Item) -> Bool { bag.extra[AIRTAG_KEY]?.boolValue == true }

    public func hasAirTag(container: String) -> Bool {
        guard let bag = bags().first(where: { normName($0.name) == normName(container) }) else { return false }
        return Library.hasAirTag(items.first { $0.id == bag.id } ?? bag)
    }

    /// Say whether one of his bags has an AirTag. Only a bag takes it; off removes the key.
    @discardableResult
    public mutating func setBagAirTag(id: String, _ on: Bool) -> Bool {
        guard bags().contains(where: { $0.id == id }) else { return false }
        return updateThing(id: id) { $0.extra[AIRTAG_KEY] = on ? .bool(true) : nil }
    }

    /// The same from a trip: a name that is not a bag yet BECOMES one (as "Goes in the cabin"
    /// does from the trip) — switched on. Switched off, a name that is no bag stays none.
    @discardableResult
    public mutating func setAirTag(container: String, _ on: Bool) -> Bool {
        let name = jsTrim(container)
        guard Library.isRealBag(name) else { return false }
        if let bag = bags().first(where: { normName($0.name) == normName(name) }) { return setBagAirTag(id: bag.id, on) }
        guard on, let bag = addBag(name: name) else { return !on }
        return setBagAirTag(id: bag.id, true)
    }

    // MARK: - The photo of all the bags together

    /// Its id on a trip; "" = none.
    public static func groupPhotoId(_ trip: TripEvent) -> String { trip.extra[DAY_GROUP_PHOTO_KEY]?.stringValue ?? "" }

    /// The photo itself, when its record is on this device.
    public func groupPhoto(tripId: String) -> PhotoRecord? {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return nil }
        let id = Library.groupPhotoId(trip)
        return id.isEmpty ? nil : photos.first { $0.id == id }
    }

    /// Keep the photo of all the trip's bags (JPEG bytes) — ONE per trip: a new one replaces
    /// the old, whose record goes unless something else still shows it.
    @discardableResult
    public mutating func setGroupPhoto(tripId: String, jpeg: Data) -> PhotoRecord? {
        guard let n = trips.firstIndex(where: { $0.id == tripId }), !jpeg.isEmpty else { return nil }
        let old = Library.groupPhotoId(trips[n])
        let photo = PhotoRecord(id: PackingEnv.makeId(), data: "data:image/jpeg;base64,\(jpeg.base64EncodedString())",
                                createdAt: nowISO())
        photos.append(photo)
        trips[n].extra[DAY_GROUP_PHOTO_KEY] = .string(photo.id)
        trips[n].updatedAt = nowISO()
        if !old.isEmpty, !photoInUse(old) { photos.removeAll { $0.id == old } }
        return photo
    }

    /// Take the photo of all the bags away; its record goes too, unless something else shows it.
    @discardableResult
    public mutating func removeGroupPhoto(tripId: String) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }) else { return false }
        let old = Library.groupPhotoId(trips[n])
        guard !old.isEmpty else { return false }
        trips[n].extra[DAY_GROUP_PHOTO_KEY] = nil
        trips[n].updatedAt = nowISO()
        if !photoInUse(old) { photos.removeAll { $0.id == old } }
        return true
    }

    // MARK: - Weigh opens by itself, once

    public static func weighOffered(_ trip: TripEvent) -> Bool { trip.extra[DAY_WEIGH_OFFERED_KEY]?.boolValue == true }

    /// Does the trip open Weigh by itself now that everything is packed? Only at Pack, with
    /// something packed and nothing left, with bags, Weigh not done — and never twice.
    public func weighOpensItself(tripId: String, today: String, time: String = END_OF_DAY) -> Bool {
        guard let trip = trips.first(where: { $0.id == tripId }), !Library.weighOffered(trip),
              loopStep(tripId: tripId, today: today, time: time) == .pack,
              let day = packingDay(tripId: tripId), day.done(.pack), day.usable(.weigh) else { return false }
        return !day.done(.weigh)
    }

    /// The trip has opened Weigh by itself: never again on this trip.
    @discardableResult
    public mutating func setWeighOffered(tripId: String) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }) else { return false }
        trips[n].extra[DAY_WEIGH_OFFERED_KEY] = .bool(true)
        trips[n].updatedAt = nowISO()
        return true
    }
}
