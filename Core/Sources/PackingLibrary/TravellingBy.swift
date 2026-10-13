import Foundation
import PackingCore

// "Travelling by" and the season a trip's dates say — Create new trip and Trip settings (0.76).
//
// His decision (13 Oct 2026), after he deleted his Car transport template — "the car is just
// go and drive"; he travels mostly by car, every weekend by RV, by plane a couple of times a
// year: Transport's three pills Car / Plane / RV became "Travelling by" with two, Plane and
// RV, both off for an ordinary trip. The STORED word does not change: neither on is "Car",
// exactly what an ordinary trip stored before — so the transport templates, every "Only on
// some trips → Transport" rule, old trips, backups, sync and the web app read it as before.
//
// And the season (his ask, the same day; he lives in Sweden): Create new trip sets it from
// the trip's first day — Winter from November to March — until he picks one himself.

extension Library {
    /// The word stored when neither Plane nor RV is on: an ordinary trip.
    public static let ordinaryTransport = "Car"

    /// The two pills of Travelling by, in their order, as the words they store.
    public static let travelPills = ["Plane", "RV"]

    /// What a tap on a pill leaves: an off pill lights (the other goes off — at most one is on);
    /// the LIT pill goes off, back to neither ("Car").
    public static func travelling(_ current: String, tapped: String) -> String {
        current == tapped ? ordinaryTransport : tapped
    }

    /// Whether a pill is lit for a stored transport: only its own word. "Car", "" or a word the
    /// app does not know light neither.
    public static func travelLit(_ transport: String, _ pill: String) -> Bool {
        travelPills.contains(pill) && transport == pill
    }

    /// The names of the transport templates a trip by `transport` brings — every template with
    /// role "transport" and that transport (as `listsForEvent` takes them), in template order;
    /// an unnamed one "Untitled template"; joined "A", "A and B", "A, B and C". "" when none.
    /// Read from the library each time: the names are his, never the app's.
    public func transportTemplateNames(_ transport: String) -> String {
        let names = templates.map { coerceList($0) }
            .filter { $0.role == "transport" && $0.transport == transport }
            .map { jsTrim($0.name).isEmpty ? "Untitled template" : jsTrim($0.name) }
        return Library.spoken(names)
    }

    /// The quiet line under Travelling by's pills:
    /// "Leave both off for an ordinary trip. Plane adds the airport checks · RV adds <name>."
    ///  - a Plane template: "Plane adds <name> and the airport checks";
    ///  - no RV template: the RV part is left out — "RV adds your RV template" would promise one
    ///    that is not there (decided 13 Oct 2026);
    ///  - a Car template (an old backup can hold one): "Leave both off for an ordinary trip — it
    ///    adds <name>." — it comes on every ordinary Full trip, so the line says so;
    ///  - Quick: no template names at all — Quick packs no transport template — while the
    ///    airport checks still count (the cabin check runs on a Quick plane trip too).
    public func travelNote(quick: Bool) -> String {
        let car = quick ? "" : transportTemplateNames(Library.ordinaryTransport)
        let plane = quick ? "" : transportTemplateNames("Plane")
        let rv = quick ? "" : transportTemplateNames("RV")
        var line = "Leave both off for an ordinary trip"
        if !car.isEmpty { line += " \u{2014} it adds \(car)" }
        line += ". Plane adds " + (plane.isEmpty ? "" : "\(plane) and ") + "the airport checks"
        if !rv.isEmpty { line += " \u{00B7} RV adds \(rv)" }
        return line + "."
    }

    /// "A", "A and B", "A, B and C" — "" for none.
    static func spoken(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        default: return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        }
    }

    /// The season a trip's first day says (0.76; he lives in Sweden): November, December,
    /// January, February or March → "Winter"; any other month → "Summer". No first day ("") or
    /// one that cannot be read ("YYYY-MM-DD" expected) → "Summer", the default.
    public static func seasonFor(firstDay: String) -> String {
        let parts = jsTrim(firstDay).split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, let month = Int(parts[1]), (1...12).contains(month) else {
            return "Summer"
        }
        return [11, 12, 1, 2, 3].contains(month) ? "Winter" : "Summer"
    }
}
