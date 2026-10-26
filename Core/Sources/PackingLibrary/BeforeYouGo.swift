import Foundation
import PackingCore

// "Before you go" — ONE card at the top of a trip (0.77, his yes of 13 Oct 2026, a picture
// approved): until then two cards stood there, "Check before you go" and "To charge". Now
// they are one, in three parts, each shown only when it has something:
//   1. the flags — what the airport stops (`cabinCheck`) and what runs out before he is
//      home (`dateCheck`), red or orange, as before;
//   2. "To do" — his reminders whose step has come and that are not ticked (`dueReminders`);
//   3. "To charge · n of m" — the things with a battery, from the day before the trip
//      through its last day (`chargeCard`).
// Each part keeps its own rules exactly as they were; this only puts them together and
// says, in one number, what is left.

/// What the trip's Before you go card holds today.
public struct BeforeYouGo: Equatable, Sendable {
    /// What a cabin bag must not hold, a battery in the hold, a liquid (in that order).
    public var cabin: [CabinFlag]
    /// What runs out before he is home, a document within six months of it — soonest first.
    public var dates: [DateFlag]
    /// The reminders due and not ticked.
    public var due: [Item]
    /// The reminders on his THINGS due and not ticked (0.101, "Camera: Empty the SD card") — in To do with them.
    public var thingDue: [ThingReminderOnTrip]
    /// The things to charge (charged or not) — [] outside its days.
    public var charge: [ChargeRow]

    public init(cabin: [CabinFlag] = [], dates: [DateFlag] = [], due: [Item] = [], charge: [ChargeRow] = [],
                thingDue: [ThingReminderOnTrip] = []) {
        self.cabin = cabin; self.dates = dates; self.due = due; self.charge = charge; self.thingDue = thingDue
    }

    /// How the card's colour reads: red will stop him, orange is still to do, green is all set.
    public enum Tone: String, Sendable { case red, orange, green }

    /// Nothing in any part: the card is not there.
    public var isEmpty: Bool { cabin.isEmpty && dates.isEmpty && due.isEmpty && thingDue.isEmpty && charge.isEmpty }

    /// Anything in To do: a reminder due — a template's, the trip's own or a thing's.
    public var hasToDo: Bool { !due.isEmpty || !thingDue.isEmpty }

    /// Everything left: every flag (each stays until it is put right), every reminder due
    /// (a ticked one leaves the card), every thing not charged yet.
    public var left: Int { cabin.count + dates.count + due.count + thingDue.count + charge.filter { !$0.charged }.count }

    /// Shown, and nothing left — only possible when every thing on To charge is charged.
    public var allSet: Bool { !isEmpty && left == 0 }

    /// Any flag that will stop him: not allowed on board, a battery in the hold, out of date
    /// already, running out before he is home.
    public var red: Bool { cabin.contains(where: \.isRed) || dates.contains(where: \.isRed) }

    /// Red if anything will stop him, else orange while anything is left, else green.
    public var tone: Tone { red ? .red : (left > 0 ? .orange : .green) }

    /// The count capsule's words: the number left, or "All set".
    public var countWords: String { allSet ? "All set" : "\(left)" }
}

extension CabinFlag {
    /// Red: the airport stops it (not allowed on board, a battery in the hold). A liquid only wants a look.
    public var isRed: Bool { why != .liquid }
}

extension DateFlag {
    /// Red: out of date already, or before he is home. A document short of six months only wants a look.
    public var isRed: Bool { alreadyOut || beforeHome }
}

extension Library {
    /// The trip's Before you go card today (`today` a YYYY-MM-DD in his time zone): the three
    /// parts, each by its own rules — the flags (`cabinCheck`, `dateCheck`), the reminders due
    /// (`dueReminders`), what to charge (`chargeCard`).
    public func beforeYouGo(tripId: String, today: String) -> BeforeYouGo {
        BeforeYouGo(cabin: cabinCheck(tripId: tripId),
                    dates: dateCheck(tripId: tripId, todayISO: today),
                    due: dueReminders(tripId: tripId, today: today),
                    charge: chargeCard(tripId: tripId, today: today),
                    thingDue: dueThingReminders(tripId: tripId, today: today))
    }
}
