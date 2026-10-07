import Foundation
import PackingCore

// "Tap the garage, see the garage" — stop A of his idea plan (7 Oct 2026: "Yes ·
// fantastic"), built without stickers (his call the same day: "let's skip the NFC").
// Each place in Your choices has a small square code, printed on a 12 mm label (his
// Brother P-touch CUBE) and stuck where the things are kept. The iPhone's Camera, pointed at the one on the
// garage shelf, opens the app on that place:
//  · a trip being packed → that trip, its lines from that place only;
//  · back from a trip → what goes back to that place;
//  · no trip → everything kept there.
//
// The code carries a LINK: AMSPACKING://P/<the place's code>. Short and in capitals on
// purpose — the square code then holds it in its smallest size (21 × 21 squares), which
// is what a 12 mm tape has room for (`PlaceLabel`). The place's code is two to four
// letters and digits, given once and kept with the library (`placeCodeKey`), so it is
// the same on both devices, survives a backup and restore, follows a rename, and is
// never given to another place — a label once stuck on a shelf keeps meaning that shelf.

/// The link a place's printed code carries.
public enum PlaceLink {
    /// Registered in lower case; a link's scheme does not care (RFC 3986), and the
    /// printed one is in capitals for the code's sake.
    public static let scheme = "amspacking"

    /// "AMSPACKING://P/G4R" — exactly what the square code holds: every character is
    /// one the code's compact letters-and-digits mode takes (capitals, digits, ":" and
    /// "/"). 18 characters for a 3-character code; that mode holds 20 at the smallest
    /// size with medium error correction (`PlaceLabel.correction`).
    public static func text(code: String) -> String { "AMSPACKING://P/\(code.uppercased())" }

    public static func url(code: String) -> URL? { URL(string: text(code: code)) }

    /// The place code a link carries — any case — or nil when it is not a place's link.
    public static func code(in url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme, let host = url.host, host.lowercased() == "p" else { return nil }
        let parts = url.path.split(separator: "/")
        guard parts.count == 1, let code = parts.first.map({ String($0).uppercased() }),
              Library.isPlaceCode(code) else { return nil }
        return code
    }
}

/// A place's code is kept in the library's facts, one per code: `placeCode:G4R` → the
/// place's name. One record each, so two devices giving codes to two places at once
/// cannot overwrite each other; a code stays when its place is removed, so it is never
/// given to another.
public let PLACE_CODE_META = "placeCode:"

extension Library {
    /// What a place's link opens, by the day.
    public enum PlaceVisit: Equatable, Sendable {
        /// A trip is being packed: its lines from this place.
        case packing(tripId: String)
        /// Back from a trip (or on it): what goes back to this place.
        case goingBack(tripId: String)
        /// No trip going on: everything kept there.
        case keptThere
    }

    /// The place `name` is, as his list spells it today: by the key the store uses, so
    /// "garage" is the Garage. A name that is on no list but that things still say is
    /// that name (a library from the web app, a place typed on a trip). nil when nothing
    /// knows it — a place removed from the list (only a place no thing uses can be).
    public func placeNamed(_ name: String) -> String? {
        let wanted = Library.choiceKey(name)
        guard !wanted.isEmpty else { return nil }
        if let have = storagePlaces().first(where: { Library.choiceKey($0) == wanted }) { return have }
        return items.first { Library.choiceKey($0.storage) == wanted }.map { jsTrim($0.storage) }
    }

    // MARK: - Place codes

    public static func placeCodeKey(_ code: String) -> String { PLACE_CODE_META + code.uppercased() }

    /// Two to four capitals or digits.
    public static func isPlaceCode(_ code: String) -> Bool {
        (2...4).contains(code.count) && code.allSatisfy { ($0.isASCII && $0.isUppercase && $0.isLetter) || ("0"..."9").contains($0) }
    }

    /// Every place code given, code → the place's name as it was given (or renamed to).
    public func placeCodes() -> [String: String] {
        var out: [String: String] = [:]
        for (key, value) in meta where key.hasPrefix(PLACE_CODE_META) {
            let code = String(key.dropFirst(PLACE_CODE_META.count))
            if Library.isPlaceCode(code), let name = value.stringValue { out[code] = name }
        }
        return out
    }

    /// The place a code was given to, as his list spells it today — nil for a code never
    /// given, or one whose place is gone.
    public func place(forCode code: String) -> String? {
        placeCodes()[code.uppercased()].flatMap(placeNamed)
    }

    /// The code `place` has — or the one it WILL get (`givePlaceCode`), so a label can be
    /// drawn before anything is stored. When two codes name one place (a place renamed
    /// onto the name of one removed earlier), the first A–Z.
    public func placeCode(for place: String) -> String? {
        let key = Library.choiceKey(place)
        guard !key.isEmpty else { return nil }
        let codes = placeCodes()
        if let have = codes.keys.sorted().first(where: { Library.choiceKey(codes[$0] ?? "") == key }) { return have }
        // Three base-36 characters from the name — the same on both devices, so two that
        // give the Garage its code at the same moment give it the SAME code — moved on
        // past any code already given (to any place, removed ones included).
        var n = Int(Library.fnv1a(key) % 46_656)
        for _ in 0..<46_656 {
            let code = Library.base36(n, width: 3)
            if codes[code] == nil { return code }
            n = (n + 1) % 46_656
        }
        return nil
    }

    /// Gives `place` its code, kept with the library, and returns it. Nothing changes
    /// for a place that has one.
    @discardableResult
    public mutating func givePlaceCode(_ place: String) -> String? {
        let name = placeNamed(place) ?? jsTrim(place)
        guard !name.isEmpty, let code = placeCode(for: name) else { return nil }
        if placeCodes()[code] == nil { meta[Library.placeCodeKey(code)] = .string(name) }
        return code
    }

    /// A place renamed in Your choices: its codes name the new name, so a label printed
    /// before the rename opens the renamed place.
    mutating func notePlaceRenamed(from old: String, to new: String) {
        let from = Library.choiceKey(old)
        guard !from.isEmpty else { return }
        for (code, name) in placeCodes() where Library.choiceKey(name) == from {
            meta[Library.placeCodeKey(code)] = .string(jsTrim(new))
        }
    }

    /// FNV-1a over the UTF-8 bytes: a small, fixed hash — Swift's own changes from run to
    /// run, and a code must come out the same on every device for ever.
    static func fnv1a(_ s: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for b in s.utf8 { h = (h ^ UInt32(b)) &* 16_777_619 }
        return h
    }

    static func base36(_ n: Int, width: Int) -> String {
        let digits = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var v = n, out = ""
        repeat { out = String(digits[v % 36]) + out; v /= 36 } while v > 0
        return String(repeating: "0", count: max(0, width - out.count)) + out
    }

    /// How many days before a trip its packing starts: the earliest of his packing
    /// "When" steps (Preparations are things to DO, not to fetch, and do not count).
    /// With the factory steps: 7 — "≥1 week ahead". Never less than 1: the day before.
    public func packingWindowDays() -> Int {
        max(1, timeline().filter { !$0.task }.map(\.leadDays).max() ?? 1)
    }

    /// What a place's link opens today. In this order:
    ///  1. Back from a trip: one that began before today and ended no longer ago than
    ///     yesterday, with lines that came along (`homeLines`) — he is unpacking. The
    ///     latest such trip.
    ///  2. A trip being packed: one starting today or within the packing window
    ///     (`packingWindowDays`). The soonest such trip.
    ///  3. Otherwise everything kept there.
    /// Reviewed trips and trips without dates never count.
    public func placeVisit(today: String) -> PlaceVisit {
        let open = trips.filter { !Library.isReviewed($0) && isYMD($0.startDate) }
        let back = open.filter { t in
            let end = isYMD(t.endDate) ? t.endDate : t.startDate
            return jsStringLess(t.startDate, today)
                && !jsStringLess(Library.ymd(end, plusDays: 1), today)
                && !homeLines(tripId: t.id).isEmpty
        }
        if let latest = back.stableSorted(by: { a, b in jsStringLess(b.startDate, a.startDate) }).first {
            return .goingBack(tripId: latest.id)
        }
        let lastDay = Library.ymd(today, plusDays: packingWindowDays())
        let packing = open.filter { !jsStringLess($0.startDate, today) && !jsStringLess(lastDay, $0.startDate) }
        if let soonest = packing.stableSorted(by: { a, b in jsStringLess(a.startDate, b.startDate) }).first {
            return .packing(tripId: soonest.id)
        }
        return .keptThere
    }

    /// Is this line or thing kept at `place`? By the key the store uses, so "garage"
    /// and "Garage" are one place.
    public static func isKept(_ storage: String, at place: String) -> Bool {
        let key = Library.choiceKey(place)
        return !key.isEmpty && Library.choiceKey(storage) == key
    }

    /// A trip's lines kept at `place`, in the trip's order.
    public func tripLines(tripId: String, at place: String) -> [Item] {
        (trips.first { $0.id == tripId }?.entries ?? []).filter { Library.isKept($0.storage, at: place) }
    }

    /// What goes back to `place` from a trip: the lines that came home (`homeLines`),
    /// less what was used up or left on site, in the trip's order.
    public func goingBack(tripId: String, to place: String) -> [Item] {
        homeLines(tripId: tripId).filter { !Library.isUsedUp($0) && Library.isKept($0.storage, at: place) }
    }

    /// Every thing kept at `place`, A–Z.
    public func thingsKept(at place: String) -> [Item] {
        items.filter { Library.isKept($0.storage, at: place) }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
    }
}
