import Foundation
import PackingCore

// Lost luggage, part C — the Lost bag page (0.80, his yes of 13 Oct 2026; spec 07 part 18 C).
//
// When a bag does not come off the belt, the baggage desk asks the same things every time: who
// he is and how to reach him, where he is going, where he stays and until when, the flight, the
// number on the bag tag, what the bag looks like, whether it has an AirTag, a photo, and a few
// things inside it. Part A keeps the bag's own details (BagDetails.swift), part B the trip's
// flights, stay and bag-tag numbers (TripTravel.swift); this part keeps who HE is for the desk —
// once, for the library — and gathers everything into ONE page per bag of a trip, which the
// screen shows, copies as text and draws as a PDF.
//
// The page is a pure reading: `Library.lostBag(tripId:bag:)` builds it from what the library
// already holds, and nothing on it is stored. What is not known is an empty row, which the
// screen shows as "not filled in" and opens where it is filled in (`LostBagFill`).
//
// His details are kept in `meta` under "lostDesk" (one record, synced) and ride in a backup's
// `prefs.lostDesk`. The web app's model (PackingCore) sees nothing new: parity 211/211.

/// The `meta` key (and the backup's `prefs` key) his details for the desk are kept under.
public let LOST_DESK_KEY = "lostDesk"
/// How many of the bag's things the page names before "and N more".
public let LOST_INSIDE_SHOWN = 8
/// What the page says under an AirTag's "Yes".
public let LOST_AIRTAG_HINT = "In Find My, Share Item Location gives the airline a link to where it is."
/// What a row with nothing in it says.
public let LOST_NOT_FILLED = "not filled in"
/// The line a trip that is not by plane shows in place of flights, stay and bag tag.
public let LOST_NOT_PLANE = "Flights, where you stay and the bag-tag number are asked on a plane trip \u{2014} Travelling by, in Trip settings."

/// Who he is, for a baggage desk: kept once for the whole library. Text is trimmed; "" = not said.
public struct DeskDetails: Equatable, Sendable {
    /// His full name, as on his passport. "" = the owner marked "This is me" is used (`deskName`).
    public var name: String
    public var phone: String
    public var email: String
    /// His home address, one line per line ("Exempelgatan 1\n123 45 Exempelstad").
    public var address: String

    public init(name: String = "", phone: String = "", email: String = "", address: String = "") {
        self.name = name; self.phone = phone; self.email = email; self.address = address
    }

    /// Nothing said at all.
    public var isEmpty: Bool { [name, phone, email, address].allSatisfy { jsTrim($0).isEmpty } }

    /// As kept: each line trimmed with single spaces inside it; the address line by line, blank
    /// lines gone; the e-mail without any space at all.
    public var cleaned: DeskDetails {
        func words(_ s: String) -> String {
            jsTrim(s).split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        }
        let lines = address.split(whereSeparator: \.isNewline).map { words(String($0)) }.filter { !$0.isEmpty }
        return DeskDetails(name: words(name.split(whereSeparator: \.isNewline).joined(separator: " ")),
                           phone: words(phone.split(whereSeparator: \.isNewline).joined(separator: " ")),
                           email: jsTrim(email).filter { !$0.isWhitespace },
                           address: lines.joined(separator: "\n"))
    }
}

/// Where a row that is not filled in is filled in — what a tap on it opens.
public enum LostBagFill: String, Sendable {
    /// For the lost-luggage desk (his details) — Settings.
    case me
    /// Trip settings (part B's Flights and stay).
    case trip
    /// The bag-tag number, typed on the page itself.
    case tag
    /// The bag's own page (part A's details, Has an AirTag).
    case bag
}

/// One row of the page: its label and its lines; no lines = not filled in.
public struct LostBagRow: Equatable, Sendable, Identifiable {
    /// "you-name", "trip-flights", "bag-colour" … — the screen's id is "lost-<key>".
    public var key: String
    public var label: String
    public var lines: [String]
    public var fill: LostBagFill
    /// False for a row that is always known (AirTag): never counted as not filled in.
    public var canBeMissing: Bool

    public init(key: String, label: String, lines: [String], fill: LostBagFill, canBeMissing: Bool = true) {
        self.key = key; self.label = label
        self.lines = lines.map(jsTrim).filter { !$0.isEmpty }
        self.fill = fill; self.canBeMissing = canBeMissing
    }

    public var id: String { key }
    public var missing: Bool { canBeMissing && lines.isEmpty }
    /// The row on one line: its lines joined with ", ", or "not filled in".
    public var words: String { lines.isEmpty ? LOST_NOT_FILLED : lines.joined(separator: ", ") }
}

/// Everything a baggage desk asks about one bag of a trip.
public struct LostBagPage: Equatable, Sendable {
    /// The bag, as the trip's lines name it.
    public var bag: String
    /// The id of the bag's thing when it is one of his bags; nil = only a name on the lines.
    public var bagId: String?
    public var tripId: String
    /// "Weekend in the hills · 14 Nov 2026 – 16 Nov 2026" (the name alone when undated).
    public var tripLine: String
    /// Travelling by Plane: flights, stay and the bag-tag number are asked.
    public var planeTrip: Bool
    public var you: [LostBagRow]
    public var travel: [LostBagRow]
    public var bagRows: [LostBagRow]
    public var airTag: Bool
    /// The photos of the bag itself — how it looks, from its page (part A) — as stored.
    public var lookIds: [String]
    /// This trip's photos of it packed (the Bags card's), as stored (one still syncing in counts).
    public var photoIds: [String]
    /// The photo of all the trip's bags together; "" = none.
    public var groupPhotoId: String
    /// The first eight things in it: "Hiking boots", "Socks ×3".
    public var inside: [String]
    /// How many more there are.
    public var moreInside: Int

    /// No photo of the bag at all — neither how it looks nor packed on this trip.
    public var noPhoto: Bool { lookIds.isEmpty && photoIds.isEmpty }

    /// The rows not filled in, and a photo of the bag when it has none.
    public var missing: Int {
        (you + travel + bagRows).filter(\.missing).count + (noPhoto ? 1 : 0)
    }

    /// "3 not filled in — tap one to fill it in." — "" when nothing is missing.
    public var missingWords: String {
        switch missing {
        case 0: return ""
        case 1: return "1 not filled in \u{2014} tap it to fill it in."
        default: return "\(missing) not filled in \u{2014} tap one to fill it in."
        }
    }

    /// "all filled in" / "3 not filled in" — the Ready station's row.
    public var shortWords: String { missing == 0 ? "all filled in" : "\(missing) not filled in" }

    /// The AirTag row's words: "Yes" / "No".
    public var airTagWords: String { airTag ? "Yes" : "No" }

    /// "Lost bag – Day pack.pdf": what the shared PDF is called. Characters a file name cannot
    /// hold become "-".
    public var pdfName: String {
        let safe = bag.map { "/\\:?*\"<>|".contains($0) ? "-" : $0 }
        return "Lost bag \u{2013} \(String(safe)).pdf"
    }

    /// The page as plain text — what Copy as text puts on the clipboard (spec 07 part 18 C rule 10).
    public var text: String {
        func block(_ title: String, _ rows: [LostBagRow]) -> [String] {
            [title] + rows.map { row in
                let sep = row.key == "trip-flights" ? "; " : ", "
                return "\(row.label): \(row.lines.isEmpty ? LOST_NOT_FILLED : row.lines.joined(separator: sep))"
            }
        }
        var out = ["LOST BAG: \(bag)", "Trip: \(tripLine)", ""]
        out += block("ABOUT ME", you) + [""]
        out += block("THE TRIP", travel)
        if !planeTrip { out.append(LOST_NOT_PLANE) }
        out.append("")
        out += block("THE BAG", bagRows)
        out.append("AirTag: \(airTag ? "Yes. \(LOST_AIRTAG_HINT)" : "No")")
        let shots = lookIds.count + photoIds.count + (groupPhotoId.isEmpty ? 0 : 1)
        out.append("Photos: \(shots == 0 ? "none" : "\(shots) (in the PDF)")")
        out += ["", "A FEW THINGS IN IT"]
        out += inside.isEmpty ? [Library.lostNothingInside] : inside
        if moreInside > 0 { out.append("and \(moreInside) more") }
        return out.joined(separator: "\n")
    }
}

extension Library {
    /// What "A few things in it" says when nothing of the trip goes in the bag.
    public static let lostNothingInside = "Nothing on this trip\u{2019}s list goes in this bag."

    // MARK: - His details for the desk

    /// His details as kept ("" for what is not said).
    public func deskDetails() -> DeskDetails {
        let o = meta[LOST_DESK_KEY]?.objectValue ?? [:]
        func text(_ k: String) -> String { o[k]?.stringValue ?? "" }
        return DeskDetails(name: text("name"), phone: text("phone"), email: text("email"), address: text("address"))
    }

    /// Keep his details, cleaned (`DeskDetails.cleaned`); only what is said is written, and with
    /// nothing said the key goes. False when nothing changed.
    @discardableResult
    public mutating func setDeskDetails(_ details: DeskDetails) -> Bool {
        let d = details.cleaned
        var o: [String: JSONValue] = [:]
        for (k, v) in [("name", d.name), ("phone", d.phone), ("email", d.email), ("address", d.address)] where !v.isEmpty {
            o[k] = .string(v)
        }
        let new: JSONValue? = o.isEmpty ? nil : .object(o)
        guard meta[LOST_DESK_KEY] != new else { return false }
        meta[LOST_DESK_KEY] = new
        return true
    }

    /// The name the desk gets: the full name he typed; else the owner marked "This is me";
    /// else "".
    public func deskName() -> String {
        let typed = jsTrim(deskDetails().name)
        return typed.isEmpty ? (me() ?? "") : typed
    }

    // MARK: - The page

    /// "14 Nov 2026 – 16 Nov 2026", one day, or "" for a trip without dates.
    static func lostTripDays(_ trip: TripEvent) -> String {
        guard isYMD(trip.startDate) else { return "" }
        let end = isYMD(trip.endDate) ? trip.endDate : trip.startDate
        return end == trip.startDate ? Library.vaultDate(trip.startDate) : "\(Library.vaultDate(trip.startDate)) \u{2013} \(Library.vaultDate(end))"
    }

    /// One flight on one line: "SK 1234 · 14 Nov 2026 · ARN → AGP" — what is not said left out.
    static func lostFlightLine(_ leg: FlightLeg) -> String {
        let from = jsTrim(leg.from), to = jsTrim(leg.to)
        let route = !from.isEmpty && !to.isEmpty ? "\(from) \u{2192} \(to)" : !from.isEmpty ? "from \(from)" : !to.isEmpty ? "to \(to)" : ""
        return [jsTrim(leg.number), isYMD(leg.date) ? Library.vaultDate(leg.date) : "", route]
            .filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }

    /// The things the page names for a bag: the trip's lines in it (by `normName`), set aside
    /// and reminders left out, in the trip's order — only the ticked ones when any is ticked
    /// (what went in), else all (what is meant to). "Name ×3" for a count above one.
    func lostInside(_ trip: TripEvent, bag: String) -> [String] {
        let key = normName(bag)
        let lines = packable(trip.entries).filter { $0.itemType != "reminder" && normName($0.container) == key }
        let went = lines.filter(\.checked)
        let nights = qtyNights(trip)
        return (went.isEmpty ? lines : went).map { line in
            let name = jsTrim(line.name)
            let qty = effectiveQty(line, nights)
            guard qty > 1 else { return name }
            return "\(name) \u{00D7}\(qty.rounded() == qty ? String(Int(qty)) : String(qty))"
        }
    }

    /// Everything a baggage desk asks about one bag of a trip (spec 07 part 18 C). Nil for no
    /// such trip, and for no bag ("" or "Other": "Not in a bag").
    public func lostBag(tripId: String, bag: String) -> LostBagPage? {
        let name = jsTrim(bag)
        guard let trip = trips.first(where: { $0.id == tripId }), Library.isRealBag(name) else { return nil }
        let desk = deskDetails()
        let you = [
            LostBagRow(key: "you-name", label: "Name", lines: [deskName()], fill: .me),
            LostBagRow(key: "you-phone", label: "Phone", lines: [desk.phone], fill: .me),
            LostBagRow(key: "you-email", label: "E-mail", lines: [desk.email], fill: .me),
            LostBagRow(key: "you-address", label: "Home address",
                       lines: desk.address.split(whereSeparator: \.isNewline).map(String.init), fill: .me),
        ]
        let days = Library.lostTripDays(trip)
        let tripName = jsTrim(trip.name)
        let tripLine = [tripName, days].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
        let going = LostBagRow(key: "trip-going", label: "Going to", lines: [Library.travelDestination(trip)], fill: .trip)
        var travel = [going]
        let plane = Library.isPlaneTrip(trip)
        if plane {
            let t = Library.travel(trip)
            let stay = [t.stay.name] + t.stay.address.split(whereSeparator: \.isNewline).map(String.init) + [t.stay.phone]
            let last = isYMD(trip.endDate) ? trip.endDate : trip.startDate
            let until = isYMD(t.stay.until) ? t.stay.until : last
            travel += [
                LostBagRow(key: "trip-stay", label: "Staying at", lines: stay, fill: .trip),
                LostBagRow(key: "trip-until", label: "Until", lines: [isYMD(until) ? Library.vaultDate(until) : ""], fill: .trip),
                LostBagRow(key: "trip-flights", label: "Flights", lines: t.flights.filter { !$0.isEmpty }.map(Library.lostFlightLine), fill: .trip),
            ]
            // The tag number: asked of a CHECKED bag only (part B's rule — a cabin bag gets no tag);
            // one kept before the bag went into the cabin is still shown.
            let tag = t.bagTag(name)
            if asksBagTag(tripId: trip.id, bag: name) || !tag.isEmpty {
                travel.append(LostBagRow(key: "trip-tag", label: "Bag-tag number", lines: [tag], fill: .tag))
            }
        }
        let mine = bags().first { normName($0.name) == normName(name) }
        let details = bagDetails(bag: name)
        let bagRows = [
            LostBagRow(key: "bag-type", label: "Type", lines: [details.type?.name ?? ""], fill: .bag),
            LostBagRow(key: "bag-brand", label: "Brand", lines: [details.brand], fill: .bag),
            LostBagRow(key: "bag-colour", label: "Colour", lines: [details.colour], fill: .bag),
            LostBagRow(key: "bag-size", label: "Size", lines: [details.sizeWords], fill: .bag),
            LostBagRow(key: "bag-marks", label: "Distinctive marks", lines: [details.marks], fill: .bag),
        ]
        let inside = lostInside(trip, bag: name)
        return LostBagPage(bag: name, bagId: mine?.id, tripId: trip.id, tripLine: tripLine, planeTrip: plane,
                           you: you, travel: travel, bagRows: bagRows, airTag: hasAirTag(container: name),
                           lookIds: details.photoIds, photoIds: bagPhotoIds(tripId: trip.id, bag: name), groupPhotoId: Library.groupPhotoId(trip),
                           inside: Array(inside.prefix(LOST_INSIDE_SHOWN)), moreInside: max(0, inside.count - LOST_INSIDE_SHOWN))
    }
}
