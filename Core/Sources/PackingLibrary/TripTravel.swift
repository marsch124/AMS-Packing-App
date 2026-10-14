import Foundation
import PackingCore

// Flights and stay — the lost-luggage information, part B (0.80, his yes of 13 Oct 2026).
//
// When a bag does not come off the belt, the airline's desk asks for the same few things every
// time: the flight it came on, where he is going, where he stays and until when, a phone number
// there, and the number on the bag tag he was given at check-in. On a plane trip (Travelling by
// = Plane) Create new trip and Trip settings keep the first four in a framed block "Flights and
// stay"; the Packing day's Tags station keeps the bag-tag number per bag. The Lost bag page (and
// its PDF) reads all of it from here — `Library.travel(_:)` — so the desk gets one page.
//
// All of it is optional and lives in the trip's extra keys, so the web app's model (PackingCore)
// and the parity checker are untouched:
//   "travel"  → { "flights": [{ "number", "date", "from", "to" }], "destination",
//                 "stay": { "name", "address", "phone", "until" } }
//   "bagTags" → { "<bag name>": "<tag number>" }   (keyed like the scale's readings, by bag name)
// Nothing typed = no key at all: a trip without flights reads and writes as before.
//
// Shown only while Plane is on. Plane switched off keeps what was typed (switched on again, it is
// all there) — but nothing shows it, and `planeTravel` says nil, so no screen uses it.
//
// Where it goes:
//  - Start a new trip from this one: NOTHING of it (other flights, another stay, new bag tags) —
//    `startAgain` copies no trip key but the laundry nights.
//  - A shared trip (link or file): the flights, the destination and the stay go along — the
//    people he shares a trip with travel with him, on the same flights to the same place — but
//    the bag-tag numbers stay with him: they are HIS bags' tags (`justTheList`).
//  - A bag renamed: its tag number goes along to the new name; two bags made one keep the kept
//    bag's own number (or none) — as the scale's reading does (`moveBagNotes`).

/// A trip's extra key: its flights, destination and stay.
public let TRIP_TRAVEL_KEY = "travel"
/// A trip's extra key: the bag-tag number of each bag, by bag name.
public let BAG_TAGS_KEY = "bagTags"
/// The fewest flight legs the block shows: out and home.
public let FLIGHT_LEGS_SHOWN = 2

/// One flight: its number ("ZZ 1234"), its day ("2026-10-14", "" = not said) and from → to
/// (an airport code or a city, as he types it).
public struct FlightLeg: Equatable, Hashable, Sendable {
    public var number: String
    public var date: String
    public var from: String
    public var to: String

    public init(number: String = "", date: String = "", from: String = "", to: String = "") {
        self.number = number; self.date = date; self.from = from; self.to = to
    }

    /// Nothing typed but (maybe) a date: a leg he did not fill in.
    public var isEmpty: Bool { [number, from, to].allSatisfy { jsTrim($0).isEmpty } }
}

/// Where he stays: the hotel's (or flat's) name, its address and phone, and the last day there
/// ("2026-10-20", "" = not said).
public struct TripStay: Equatable, Hashable, Sendable {
    public var name: String
    public var address: String
    public var phone: String
    public var until: String

    public init(name: String = "", address: String = "", phone: String = "", until: String = "") {
        self.name = name; self.address = address; self.phone = phone; self.until = until
    }

    /// Nothing typed but (maybe) the day.
    public var isEmpty: Bool { [name, address, phone].allSatisfy { jsTrim($0).isEmpty } }
}

/// A trip's flights and stay, and its bags' tag numbers.
public struct TripTravel: Equatable, Sendable {
    /// In his order: out first, home last, any change of plane between.
    public var flights: [FlightLeg]
    /// The city he flies to. "" = not said — `Library.travelDestination` then falls back to the
    /// trip's Place.
    public var destination: String
    public var stay: TripStay
    /// Bag name (as the trip's Bags card names it) → the number on its bag tag.
    public var bagTags: [String: String]

    public init(flights: [FlightLeg] = [], destination: String = "", stay: TripStay = TripStay(),
                bagTags: [String: String] = [:]) {
        self.flights = flights; self.destination = destination; self.stay = stay; self.bagTags = bagTags
    }

    /// Nothing at all typed.
    public var isEmpty: Bool {
        flights.allSatisfy(\.isEmpty) && jsTrim(destination).isEmpty && stay.isEmpty && bagTags.isEmpty
    }

    /// The flights as the block shows them: his legs, then empty ones up to two (out and home).
    public var legsForEditing: [FlightLeg] {
        flights + Array(repeating: FlightLeg(), count: max(0, FLIGHT_LEGS_SHOWN - flights.count))
    }

    /// The tag number of a bag, by name as `normName` sees it. "" = none.
    public func bagTag(_ bag: String) -> String {
        bagTags.first { normName($0.key) == normName(bag) }?.value ?? ""
    }
}

extension Library {
    // MARK: - Cleaning what he types

    /// A flight number or a bag-tag number as kept: trimmed, capitals, single spaces —
    /// "zz  1234 " → "ZZ 1234".
    public static func cleanCode(_ s: String) -> String {
        jsTrim(s).uppercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// A place, a name, an address or a phone as kept: trimmed, single spaces.
    static func cleanWords(_ s: String) -> String {
        jsTrim(s).split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
    }

    /// An address as kept: each line trimmed, blank lines gone (it may be pasted in three lines).
    static func cleanAddress(_ s: String) -> String {
        s.split(whereSeparator: \.isNewline).map { cleanWords(String($0)) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// The day a leg is taken to be on when he gave none: the first leg on the trip's first day,
    /// the last (of two or more) on its last day, any between on the first. "" when the trip has
    /// no dates.
    public static func legDay(index: Int, of count: Int, firstDay: String, lastDay: String) -> String {
        let first = isYMD(firstDay) ? firstDay : ""
        let last = isYMD(lastDay) ? lastDay : first
        return count > 1 && index == count - 1 ? last : first
    }

    /// The day a leg shows and is kept with: its own, else `legDay` by its place among ALL the
    /// legs as the block shows them (so an empty Out does not make Home the first leg).
    public static func shownDay(_ legs: [FlightLeg], _ n: Int, firstDay: String, lastDay: String) -> String {
        guard legs.indices.contains(n) else { return "" }
        let own = jsTrim(legs[n].date)
        return isYMD(own) ? own : legDay(index: n, of: legs.count, firstDay: firstDay, lastDay: lastDay)
    }

    /// What he typed, as kept: legs with nothing typed go (wherever they are); a kept leg without
    /// a day gets the one `shownDay` gives; the stay without a last day gets the trip's last day.
    /// Bag-tag numbers: cleaned, blank ones gone, one per bag (by `normName`, the last wins).
    public static func cleaned(_ travel: TripTravel, firstDay: String = "", lastDay: String = "") -> TripTravel {
        let all = travel.flights
        let flights = all.indices.filter { !all[$0].isEmpty }.map { n in
            FlightLeg(number: cleanCode(all[n].number), date: shownDay(all, n, firstDay: firstDay, lastDay: lastDay),
                      from: cleanWords(all[n].from), to: cleanWords(all[n].to))
        }
        var stay = TripStay(name: cleanWords(travel.stay.name), address: cleanAddress(travel.stay.address),
                            phone: cleanWords(travel.stay.phone), until: isYMD(jsTrim(travel.stay.until)) ? jsTrim(travel.stay.until) : "")
        if stay.isEmpty { stay.until = "" } else if stay.until.isEmpty, isYMD(lastDay) { stay.until = lastDay }
        var tags: [String: String] = [:]
        for (bag, number) in travel.bagTags.sorted(by: { $0.key < $1.key }) {
            let name = jsTrim(bag), code = cleanCode(number)
            guard isRealBag(name) else { continue }
            if let same = tags.keys.first(where: { normName($0) == normName(name) }) { tags[same] = nil }
            if !code.isEmpty { tags[name] = code }
        }
        return TripTravel(flights: flights, destination: cleanWords(travel.destination), stay: stay, bagTags: tags)
    }

    // MARK: - Reading

    /// A trip's flights, stay and bag-tag numbers, as stored (blank = not said).
    public static func travel(_ trip: TripEvent) -> TripTravel {
        let o = trip.extra[TRIP_TRAVEL_KEY]?.objectValue ?? [:]
        func text(_ v: JSONValue?) -> String { v?.stringValue ?? "" }
        let flights: [FlightLeg] = (o["flights"]?.arrayValue ?? []).compactMap { v in
            guard let f = v.objectValue else { return nil }
            return FlightLeg(number: text(f["number"]), date: text(f["date"]), from: text(f["from"]), to: text(f["to"]))
        }
        let s = o["stay"]?.objectValue ?? [:]
        let stay = TripStay(name: text(s["name"]), address: text(s["address"]), phone: text(s["phone"]), until: text(s["until"]))
        var tags: [String: String] = [:]
        for (bag, v) in trip.extra[BAG_TAGS_KEY]?.objectValue ?? [:] {
            if let number = v.stringValue, !jsTrim(number).isEmpty { tags[bag] = number }
        }
        return TripTravel(flights: flights, destination: text(o["destination"]), stay: stay, bagTags: tags)
    }

    /// The same, by trip id. Nil for no such trip.
    public func travel(tripId: String) -> TripTravel? {
        trips.first { $0.id == tripId }.map(Library.travel)
    }

    /// Is the trip one by plane — the only kind that shows Flights and stay?
    public static func isPlaneTrip(_ trip: TripEvent) -> Bool { trip.transport == "Plane" }

    /// A plane trip's travel, nil for any other trip (Plane switched off keeps it, unused).
    public static func planeTravel(_ trip: TripEvent) -> TripTravel? {
        isPlaneTrip(trip) ? travel(trip) : nil
    }

    /// Where he is going, for the desk: the city he typed in Flights and stay, else the trip's
    /// Place, else "".
    public static func travelDestination(_ trip: TripEvent) -> String {
        let own = jsTrim(travel(trip).destination)
        return own.isEmpty ? jsTrim(trip.destination) : own
    }

    /// The tag number of one bag on a trip. "" = none.
    public static func bagTag(_ trip: TripEvent, bag: String) -> String { travel(trip).bagTag(bag) }

    /// Is a bag on a trip asked for its tag number? Only on a plane trip, only a real bag (not
    /// "Other", loose things), and only a CHECKED one: a bag that goes in the cabin gets no tag at
    /// the desk — his word on the bag's page, else its name (`isCabin`, the airport checks' rule).
    /// A number kept before the bag went into the cabin stays kept, unasked.
    public func asksBagTag(tripId: String, bag: String) -> Bool {
        guard let trip = trips.first(where: { $0.id == tripId }), Library.isPlaneTrip(trip) else { return false }
        return Library.isRealBag(jsTrim(bag)) && !isCabin(container: bag)
    }

    // MARK: - Writing

    /// Keep a trip's flights, destination and stay (`travel.bagTags` too). Cleaned first
    /// (`cleaned`, with the trip's own dates); nothing left = the key goes.
    public static func setTravel(_ trip: inout TripEvent, _ travel: TripTravel) {
        let t = cleaned(travel, firstDay: trip.startDate, lastDay: trip.endDate.isEmpty ? trip.startDate : trip.endDate)
        var o: [String: JSONValue] = [:]
        if !t.flights.isEmpty {
            o["flights"] = .array(t.flights.map { leg in
                .object(["number": .string(leg.number), "date": .string(leg.date), "from": .string(leg.from), "to": .string(leg.to)])
            })
        }
        if !t.destination.isEmpty { o["destination"] = .string(t.destination) }
        if !t.stay.isEmpty {
            o["stay"] = .object(["name": .string(t.stay.name), "address": .string(t.stay.address),
                                 "phone": .string(t.stay.phone), "until": .string(t.stay.until)])
        }
        trip.extra[TRIP_TRAVEL_KEY] = o.isEmpty ? nil : .object(o)
        trip.extra[BAG_TAGS_KEY] = t.bagTags.isEmpty ? nil : .object(t.bagTags.mapValues(JSONValue.string))
    }

    /// Keep a trip's flights, destination and stay, leaving its bag-tag numbers as they are —
    /// what Create new trip and Trip settings save (their block has no bag tags).
    public static func setFlightsAndStay(_ trip: inout TripEvent, _ travel: TripTravel) {
        var all = travel
        all.bagTags = Library.travel(trip).bagTags
        setTravel(&trip, all)
    }

    @discardableResult
    public mutating func setTravel(_ travel: TripTravel, tripId: String) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }) else { return false }
        Library.setTravel(&trips[n], travel)
        trips[n].updatedAt = nowISO()
        return true
    }

    /// Keep (or, with "", take away) the number on one bag's tag. Not a bag ("" or "Other",
    /// loose things) is refused.
    @discardableResult
    public mutating func setBagTag(_ number: String, tripId: String, bag: String) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }), Library.isRealBag(jsTrim(bag)) else { return false }
        var t = Library.travel(trips[n])
        t.bagTags = t.bagTags.filter { normName($0.key) != normName(bag) }
        t.bagTags[jsTrim(bag)] = number
        Library.setTravel(&trips[n], t)
        trips[n].updatedAt = nowISO()
        return true
    }

    // MARK: - Where it goes

    /// A bag renamed on one trip: its tag number goes along to a plain new name; where two bags
    /// become one (`joinsAnother`), or to "no bag", it is dropped — the bag kept has its own tag.
    mutating func moveBagTag(trip t: Int, from o: String, to new: String, joinsAnother: Bool) {
        guard var tags = trips[t].extra[BAG_TAGS_KEY]?.objectValue else { return }
        let old = tags.keys.filter { normName($0) == o }.sorted()
        guard !old.isEmpty, old != [new] else { return }
        let carried = tags[old[0]]
        for key in old { tags[key] = nil }
        let hasOwn = tags.keys.contains { normName($0) == normName(new) }
        if !new.isEmpty, !joinsAnother, !hasOwn, let carried { tags[new] = carried }
        trips[t].extra[BAG_TAGS_KEY] = tags.isEmpty ? nil : .object(tags)
    }
}
