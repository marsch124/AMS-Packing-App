import Foundation
import PackingCore

// Packing Stations (0.81) — his decisions of 14 Oct 2026 on 0.79's Packing day, from the
// screenshots of a Mac trip: the day is renamed "Packing Stations"; Tags gets a "Remind me" per
// bag and Ready an "Add a reminder", each adding a To do line to the trip; Bags out gets
// "+ Add a bag" (one of his bags, or a new one); and the trip header's Review and Take a break
// wear colours of their own. (Spec 07, part 17, "0.81".) Here is the model of it; the screens
// only show it.
//
// As with the rest of the day, everything is kept in extra keys — on the trip, or on a line — so
// it is synced, backed up and restored with its record, and the web app's model is untouched
// (parity 211/211). A To do written on the trip is the web app's own reminder line (`itemType`
// "reminder", `custom`): the web app reads it as one of its own.

/// A trip's extra key: the bags put on the trip by "+ Add a bag" in Bags out, `[bag name]` — on
/// the trip whether or not a line is packed in them. Kept by the bag's NAME, as the day's other
/// ticks are, and follows a rename the same way (`DAY_BAG_KEYS`). Removed when empty.
public let DAY_ADDED_BAGS_KEY = "dayAddedBags"

/// A trip line's extra key: true = a To do written on the trip itself — Tags' "Remind me" and
/// Ready's "Add a reminder" (0.81). It is due at once, whatever its When or the trip's dates, so
/// it shows in Before you go straight away. Never written false.
public let TRIP_TODO_KEY = "tripTodo"

extension Library {
    // MARK: - A To do written on the trip

    /// Is this line a To do written on the trip (Remind me, Add a reminder)?
    public static func isTripTodo(_ line: Item) -> Bool { line.extra[TRIP_TODO_KEY]?.boolValue == true }

    /// Why a To do cannot be written on a trip.
    public enum TripTodoProblem: Equatable, Sendable {
        /// Nothing written.
        case blank
        /// The trip has a To do of that name not yet done — one is enough.
        case alreadyThere
    }

    public func tripTodoProblem(tripId: String, name: String) -> TripTodoProblem? {
        let clean = jsTrim(name)
        if clean.isEmpty { return .blank }
        guard let trip = trips.first(where: { $0.id == tripId }) else { return nil }
        let open = trip.entries.contains {
            Library.isReminder($0) && !$0.checked && !isSetAside($0) && normName($0.name) == normName(clean)
        }
        return open ? .alreadyThere : nil
    }

    /// The When a To do written on the trip gets — only so that it sorts somewhere sensible on the
    /// list (it is due at once anyway): of the steps before leaving (lead days 0 or more), the latest
    /// one already due by the trip's dates — what is being done now; with none due yet (or no
    /// dates), the earliest step of all. No step before leaving at all: a new thing's step.
    public func todoWhen(tripId: String, today: String) -> String {
        let before = PHASES.filter { $0.leadDays >= 0 }
        guard !before.isEmpty else { return defaultPhaseId() }
        // Latest first: the fewest lead days; equal lead days keep the timeline's order.
        let latestFirst = before.enumerated().sorted { a, b in
            a.element.leadDays != b.element.leadDays ? a.element.leadDays < b.element.leadDays : a.offset < b.offset
        }.map(\.element)
        if let trip = trips.first(where: { $0.id == tripId }), isYMD(trip.startDate),
           let due = latestFirst.first(where: { !jsStringLess(today, Library.ymd(trip.startDate, plusDays: -$0.leadDays)) }) {
            return due.id
        }
        return latestFirst.last?.id ?? defaultPhaseId()
    }

    /// Write a To do on THIS trip — "Name tag for the Day pack", "Buy euros": a reminder line of
    /// the trip's own (no template behind it, so a rebuild keeps it), not ticked, in no bag, kind
    /// "Reminders", marked as written on the trip (`TRIP_TODO_KEY`): due at once, so it shows in
    /// Before you go's To do now; ticked there or on the list, it is done. It counts on the list as
    /// any reminder does — the trip's count, and Pack, wait for it. Refused (nil) for any
    /// `tripTodoProblem`, or a trip that does not exist.
    @discardableResult
    public mutating func addTripTodo(tripId: String, name: String, today: String) -> Item? {
        guard tripTodoProblem(tripId: tripId, name: name) == nil,
              let t = trips.firstIndex(where: { $0.id == tripId }) else { return nil }
        var line = newItem(name: jsTrim(name), category: REMINDERS_CATEGORY, container: "",
                           phase: todoWhen(tripId: tripId, today: today), itemType: REMINDER_TYPE)
        line.custom = true
        line.checked = false
        line.extra[TRIP_TODO_KEY] = .bool(true)
        trips[t].entries.append(line)
        trips[t].updatedAt = nowISO()
        return line
    }

    // MARK: - "+ Add a bag"

    /// The bags "+ Add a bag" put on a trip, as stored (blank ones left out).
    public static func addedBags(_ trip: TripEvent) -> [String] { dayNames(trip, DAY_ADDED_BAGS_KEY) }

    /// Is this bag on the trip by "+ Add a bag"?
    public func isAddedBag(tripId: String, bag: String) -> Bool {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return false }
        return Library.addedBags(trip).contains { normName($0) == normName(bag) }
    }

    /// His bags (Care → Bags, in that list's order) that are NOT on the trip yet — what "+ Add a
    /// bag" offers to pick.
    public func bagsToAdd(tripId: String) -> [Item] {
        let on = Set(dayBags(tripId: tripId).map { normName($0) })
        return bags().filter { Library.isRealBag(jsTrim($0.name)) && !on.contains(normName($0.name)) }
    }

    /// Put a bag on the trip with nothing in it yet: it joins the trip's bags — Bags out, Weigh,
    /// Tags, Photos and the Bags card ask about it — last, in the order added. False for a bag
    /// already on the trip (by its lines or added before), "Other" or a blank name, or no such trip.
    @discardableResult
    public mutating func addBagToTrip(tripId: String, bag: String) -> Bool {
        let name = jsTrim(bag)
        guard Library.isRealBag(name), trips.contains(where: { $0.id == tripId }),
              !dayBags(tripId: tripId).contains(where: { normName($0) == normName(name) }) else { return false }
        return setDayTick(true, key: DAY_ADDED_BAGS_KEY, tripId: tripId, bag: name)
    }

    /// Take a bag added by "+ Add a bag" off the trip again. What the day kept for it (out, tags,
    /// a reading, photos) stays stored, ignored, as for any bag no longer on the trip; a line
    /// packed in it keeps it on the trip regardless. False when it was not added.
    @discardableResult
    public mutating func removeAddedBag(tripId: String, bag: String) -> Bool {
        guard isAddedBag(tripId: tripId, bag: bag) else { return false }
        return setDayTick(false, key: DAY_ADDED_BAGS_KEY, tripId: tripId, bag: bag)
    }

    /// Why a NEW bag cannot be made from "+ Add a bag".
    public enum NewTripBagProblem: Equatable, Sendable {
        /// Nothing typed.
        case blank
        /// "Other" — the Bags card's word for things in no bag — is no bag's name.
        case notABag
        /// One of his bags has that name: pick it from the list instead (its name as he has it).
        case yours(String)
        /// The trip already packs into a bag of that name (a name on its lines).
        case onTheTrip(String)
    }

    public func newTripBagProblem(tripId: String, name: String) -> NewTripBagProblem? {
        let clean = jsTrim(name)
        if clean.isEmpty { return .blank }
        if !Library.isRealBag(clean) || normName(clean) == normName("Other") { return .notABag }
        if let had = dayBags(tripId: tripId).first(where: { normName($0) == normName(clean) }) { return .onTheTrip(had) }
        if let mine = bags().first(where: { normName($0.name) == normName(clean) }) { return .yours(mine.name) }
        return nil
    }

    /// Make a NEW bag of his and put it on the trip: it joins Care → Bags (as a bag made there
    /// does), goes in the cabin or not as he says (`cabin` nil = by its name, the airport checks'
    /// own rule), with its max weight when he gives one (> 0), and is added to the trip. Nil for any
    /// `newTripBagProblem`, or no such trip.
    @discardableResult
    public mutating func addNewBagToTrip(tripId: String, name: String, cabin: Bool?, maxKg: Double?) -> Item? {
        guard trips.contains(where: { $0.id == tripId }), newTripBagProblem(tripId: tripId, name: name) == nil,
              let bag = addBag(name: jsTrim(name)) else { return nil }
        if let cabin { setBagCabin(id: bag.id, cabin) }
        if let maxKg, maxKg.isFinite, maxKg > 0 { setBag(id: bag.id, maxKg: maxKg) }
        addBagToTrip(tripId: tripId, bag: bag.name)
        return items.first { $0.id == bag.id }
    }

    /// Does a bag of this name go in the cabin by its name alone ("Cabin bag", "Carry-on")? What
    /// "+ Add a bag" shows for a new bag until he says otherwise.
    public static func cabinByItsName(_ name: String) -> Bool { cabinByName(name) }
}

extension PackingDay {
    /// What Tags' "Remind me" offers to write for a bag, ready to change before it is added: what
    /// is not ticked yet — "Name tag for the Day pack", "AirTag for the Day pack", both — or, with
    /// everything ticked, the name tag.
    public static func reminder(for bag: Bag) -> String {
        let tag = !bag.nameTag, air = bag.hasAirTag && !bag.airTag
        switch (tag, air) {
        case (true, true): return "Name tag and AirTag for \(bag.name)"
        case (false, true): return "AirTag for \(bag.name)"
        default: return "Name tag for \(bag.name)"
        }
    }

    /// Is every tick Tags asks about this bag on — its name tag, and its AirTag when it has one?
    public static func tagsDone(_ bag: Bag) -> Bool { bag.nameTag && (!bag.hasAirTag || bag.airTag) }
}

// MARK: - The trip header's colours

/// The trip header's three buttons wear their own colours (0.81, his pick of variant A, 14 Oct
/// 2026): Review in the Templates (Refine) violet — what a review teaches goes to the templates;
/// Take a break ("Back at 18:00") in a warm coffee amber; Done stays the trip's green. Each is
/// one colour for its ring and fill and one for its WORDS, day and night, the words dark (or light)
/// enough to read at 4.5 : 1 on the button's own 10 % fill — on the page and on a card.
public enum TripHeaderTone: CaseIterable, Sendable {
    case review, takeABreak, done

    /// The ring (and, at 10 %, the fill): day, night.
    public var ring: (day: String, night: String) {
        switch self {
        case .review: return ("#7c5cd6", "#7c5cd6")          // the Templates violet (docs/colours.md)
        case .takeABreak: return ("#a8651a", "#e0a458")      // coffee amber
        case .done: return ("#2f9e63", "#2f9e63")            // the trip's green — a filled button
        }
    }

    /// The words, on an outlined button: day, night. Done is filled, its words white.
    public var words: (day: String, night: String) {
        switch self {
        case .review: return ("#6548c0", "#a58ce6")
        case .takeABreak: return ("#8a5215", "#e0a458")
        case .done: return ("#ffffff", "#ffffff")
        }
    }

    /// Filled (white words on the ring colour) or outlined (its words on a 10 % fill).
    public var filled: Bool { self == .done }
}

/// The WCAG contrast ratio of two colours, 1 … 21.
public func contrastRatio(_ a: String, _ b: String) -> Double {
    let la = relativeLuminance(a) ?? 0, lb = relativeLuminance(b) ?? 0
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

/// `top` laid over `base` at `opacity` (0 … 1), as a hex colour.
public func blendHex(_ top: String, over base: String, opacity: Double) -> String {
    func parts(_ hex: String) -> [Double] {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return [0, 0, 0] }
        return [Double((v >> 16) & 0xff), Double((v >> 8) & 0xff), Double(v & 0xff)]
    }
    let t = parts(top), b = parts(base)
    let mixed = (0..<3).map { max(0, min(255, Int((b[$0] + (t[$0] - b[$0]) * opacity).rounded()))) }
    return String(format: "#%02x%02x%02x", mixed[0], mixed[1], mixed[2])
}
