import Foundation
import PackingCore

// Batteries and To charge (spec 07 part 15) — his ask of 13 Oct 2026: "Add a tick box for
// each item: Contains battery. And maybe implement a view where I can check all items that
// need charging."
//
// "Has a battery" belongs to the THING, as Liquid does, and every trip reads it from the
// thing as it is now (`thingNow`). It is NOT the web model's `charging` flag: that one means
// "needs charging OR a charging cable" (a USB-C cable carries it, with its connector), and
// a cable has no battery to charge. So it is a key of its own, and the web model — and the
// parity check — see nothing new.
//
// WHERE IT IS KEPT, in extra keys, so it is stored, synced, backed up and restored with its
// record as every extra key is:
//   battery     true   on a THING: it has a battery (absent = no; never written false)
//   charged     true   on a trip LINE: its thing is charged for this trip
//   kitCharged  [ids]  on a trip's KIT line: the things inside it charged for this trip
// The charge ticks are the trip's, one line record each (the iPhone and the Mac can tick two
// things at once), and apart from packing: a charge tick never ticks the line, and a tick on
// the line never marks it charged.

/// On a thing: it has a battery — charge it before a trip.
public let BATTERY_KEY = "battery"
/// On a trip line: its thing is charged for this trip.
public let CHARGED_KEY = "charged"
/// On a trip's kit line: the things inside the kit charged for this trip.
public let KIT_CHARGED_KEY = "kitCharged"

/// One thing to charge on a trip, as the To charge card shows it.
public struct ChargeRow: Equatable, Sendable {
    /// The trip line it is on — the kit's line for a thing inside a kit.
    public var lineId: String
    /// A thing inside the line's kit (nil: the line's own thing).
    public var contentId: String?
    /// The thing's name, as it is now.
    public var name: String
    /// The kit it is inside on this trip ("" for the line's own thing).
    public var kit: String
    /// Charged for this trip.
    public var charged: Bool

    public init(lineId: String, contentId: String? = nil, name: String, kit: String = "", charged: Bool) {
        self.lineId = lineId; self.contentId = contentId; self.name = name; self.kit = kit; self.charged = charged
    }

    /// One id per row: the line's, or "<line>|<content>".
    public var id: String { contentId.map { "\(lineId)|\($0)" } ?? lineId }
}

extension Item {
    /// Has a battery, read and written as a field — the things table's Battery column, its
    /// filter, its sort and Change all (0.86, his "Battery column: yes", 15 Oct 2026) go through
    /// the same key paths as Liquid's. Writing it is `Library.setBattery`: the key only when on.
    public var hasBattery: Bool {
        get { Library.hasBattery(self) }
        set { Library.setBattery(&self, newValue) }
    }
}

extension Library {
    // MARK: - The thing

    /// Does this thing have a battery?
    public static func hasBattery(_ thing: Item) -> Bool { thing.extra[BATTERY_KEY]?.boolValue == true }

    /// Say whether a thing has a battery — on a draft (a thing's page); the key only when it does.
    public static func setBattery(_ thing: inout Item, _ on: Bool) {
        thing.extra[BATTERY_KEY] = on ? JSONValue.bool(true) : JSONValue?.none
    }

    /// Say whether a thing in the library has a battery. False when there is no such thing.
    @discardableResult
    public mutating func setThingBattery(id: String, _ on: Bool) -> Bool {
        updateThing(id: id) { Library.setBattery(&$0, on) }
    }

    /// His things with a battery (the reminders on a template are never his things), A–Z as
    /// Your things lists them.
    public func batteryThings() -> [Item] {
        thingRows().map(\.item).filter(Library.hasBattery)
    }

    // MARK: - On a trip

    /// Every thing on a trip that has a battery, in the trip's order: each line not set aside
    /// and not a reminder whose thing — as it is NOW — has one; and for a kit line (the kit as
    /// it is now), its own row first when the kit has one, then each thing inside it, not
    /// taken out, that has one. A thing is listed once: the first place it is met wins.
    public func toCharge(tripId: String) -> [ChargeRow] {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return [] }
        let kits = kitIndex()
        var seen = Set<String>()
        var rows: [ChargeRow] = []
        for line in trip.entries where !isSetAside(line) && !Library.isReminder(line) {
            let thing = thingNow(line)
            let key = line.sourceItemId.flatMap { $0.isEmpty ? nil : $0 } ?? "line:\(line.id)"
            if Library.hasBattery(thing), seen.insert(key).inserted {
                rows.append(ChargeRow(lineId: line.id, name: thing.name.isEmpty ? line.name : thing.name,
                                      charged: line.extra[CHARGED_KEY]?.boolValue == true))
            }
            guard let kit = liveKitOnLine(line, index: kits) else { continue }
            let done = Set(Library.kitIds(line.extra[KIT_CHARGED_KEY]))
            for c in kit.inside where Library.hasBattery(c.thing) && seen.insert(c.thing.id).inserted {
                rows.append(ChargeRow(lineId: line.id, contentId: c.thing.id, name: c.thing.name,
                                      kit: kit.kit.name, charged: done.contains(c.thing.id)))
            }
        }
        return rows
    }

    /// Is the To charge card's time? From the day BEFORE the start through the end (the end =
    /// the start when it is blank) — through the last day, since he may charge again on site.
    /// A trip with no start date: always (there is no day to wait for). Never once reviewed.
    public static func chargeWindow(_ trip: TripEvent, today: String) -> Bool {
        guard !isReviewed(trip) else { return false }
        let start = jsTrim(trip.startDate)
        guard isYMD(start) else { return true }
        let end = isYMD(jsTrim(trip.endDate)) ? jsTrim(trip.endDate) : start
        let from = addDays(start, -1)
        return !jsStringLess(today, from) && !jsStringLess(end, today)
    }

    /// What the trip's To charge card shows today — [] when it is not shown (not its time,
    /// reviewed, or nothing on the trip has a battery).
    public func chargeCard(tripId: String, today: String) -> [ChargeRow] {
        guard let trip = trips.first(where: { $0.id == tripId }), Library.chargeWindow(trip, today: today) else { return [] }
        return toCharge(tripId: tripId)
    }

    /// "1 of 3" — charged of all.
    public static func chargeWords(_ rows: [ChargeRow]) -> String {
        "\(rows.filter(\.charged).count) of \(rows.count)"
    }

    /// Charged for this trip, or not — a line's own thing (`contentId` nil), or a thing inside
    /// the line's kit (as it is now, not taken out). Touches nothing but the mark: the line is
    /// not ticked or unticked. False when there is nothing to mark.
    @discardableResult
    public mutating func setCharged(_ on: Bool, tripId: String, lineId: String, contentId: String? = nil) -> Bool {
        guard let t = trips.firstIndex(where: { $0.id == tripId }),
              let e = trips[t].entries.firstIndex(where: { $0.id == lineId }) else { return false }
        let line = trips[t].entries[e]
        guard let contentId else {
            trips[t].entries[e].extra[CHARGED_KEY] = on ? JSONValue.bool(true) : JSONValue?.none
            return true
        }
        guard let kit = liveKitOnLine(line), kit.inside.contains(where: { $0.thing.id == contentId }) else { return false }
        let inside = kit.inside.map(\.thing.id)
        var done = Set(Library.kitIds(line.extra[KIT_CHARGED_KEY]))
        if on { done.insert(contentId) } else { done.remove(contentId) }
        let keep = inside.filter { done.contains($0) }
        trips[t].entries[e].extra[KIT_CHARGED_KEY] = keep.isEmpty ? JSONValue?.none : JSONValue(keep)
        return true
    }

    /// The charge marks a line carries — what a shared trip and a trip started again leave behind.
    static let chargeKeys = [CHARGED_KEY, KIT_CHARGED_KEY]
}
