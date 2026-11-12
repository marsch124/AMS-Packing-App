import Foundation
import PackingCore

// 0.122 — his ask of 12 Nov 2026 ("implement your two ideas", + five sample things):
//   1. Gone, year by year — what was lost, stolen or sold each year, for an insurance claim.
//   2. The room walk reads a serial number from the photo (Apple's text recognition, on the device).
//   3. Five sample things kept at home, added once, removable in one go.

// MARK: - 1. Gone, year by year

/// One year's line on the Gone view: "2026 · 3 gone · 1 sold for 1 200 kr · lost or stolen worth 5 100 kr".
public struct GoneYear: Equatable, Sendable {
    public var year: String
    public var things = 0
    public var sold = 0
    /// What the sold ones fetched, in kronor.
    public var soldFor = 0.0
    public var lostOrStolen = 0
    /// What the lost and stolen ones were worth on the day they went (pieces × count), in kronor.
    public var lostWorth = 0.0
    public init(year: String) { self.year = year }

    public var words: String {
        var parts = ["\(year)", "\(things) gone"]
        if sold > 0 { parts.append("\(sold) sold" + (soldFor > 0 ? " for \(Library.moneyWords(soldFor))" : "")) }
        if lostOrStolen > 0 {
            parts.append("\(lostOrStolen) lost or stolen" + (lostWorth > 0 ? " worth \(Library.moneyWords(lostWorth))" : ""))
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}

extension Library {
    /// Gone things per year (the year of the day each went; one without a day counts as "No date"),
    /// newest first. Lost and stolen ones count at their value ON THE DAY THEY WENT — his own figure
    /// when set, else the price less 15 % a year — in kronor; one in an unknown currency counts 0.
    public static func goneByYear(_ things: [Item], rates: CurrencyRates = .current) -> [GoneYear] {
        var years: [String: GoneYear] = [:]
        for it in things {
            guard let g = gone(it) else { continue }
            let y = isYMD(g.on) ? String(g.on.prefix(4)) : "No date"
            var row = years[y] ?? GoneYear(year: y)
            row.things += 1
            switch g.how {
            case .sold:
                row.sold += 1
                if let v = g.soldFor, v > 0, let sek = rates.inKronor(v, g.currency) { row.soldFor += sek }
            case .lost, .stolen:
                row.lostOrStolen += 1
                if let v = valueToday(it, today: isYMD(g.on) ? g.on : it.acquired), let one = rates.inKronor(1, it.currency) {
                    row.lostWorth += v * one * Double(max(1, it.qtyOwned))
                }
            default: break
            }
            years[y] = row
        }
        return years.values.sorted { a, b in
            if a.year == "No date" { return false }
            if b.year == "No date" { return true }
            return a.year > b.year
        }
    }
}

// MARK: - 2. A serial read from a photo

extension Library {
    /// The serial among the lines of text read off a photo — only one that is LABELLED ("S/N:", "Serial
    /// No.", "SN 12…", "Seriennummer"), so a price or a model name is never taken for one. A label alone
    /// on its line takes the next line. Nil when there is none (at least 4 characters, one a digit).
    public static func serialGuess(_ lines: [String]) -> String? {
        let labels = ["serial", "s/n", "s / n", "s.n.", "sn ", "sn:", "sn.", "seriennummer", "serienummer",
                      "serienr", "ser. nr", "ser.no"]
        func ok(_ s: String) -> Bool { s.count >= 4 && s.contains(where: \.isNumber) }
        for (n, raw) in lines.enumerated() {
            let line = jsTrim(raw)
            let lower = line.lowercased()
            guard let at = labels.compactMap({ l in lower.range(of: l).map { ($0, l) } }).min(by: { $0.0.lowerBound < $1.0.lowerBound })
            else { continue }
            // "SN" only at the start of a word.
            if at.1.hasPrefix("sn"), at.0.lowerBound > lower.startIndex,
               lower[lower.index(before: at.0.lowerBound)].isLetter { continue }
            let from = String(line[at.0.lowerBound...])
            let s = cleanSerial(from)
            if ok(s) { return s }
            if n + 1 < lines.count {
                let next = cleanSerial(lines[n + 1])
                if ok(next) { return next }
            }
        }
        return nil
    }
}

// MARK: - 3. Sample things

public let SAMPLE_KEY = "sample"

/// One sample thing, as the iPhone adds it once (0.122). `picture` names the drawn photo the app gives it.
public struct SampleThing: Sendable {
    public let name, brand, model, serial, room, spot, bought, shop, currency, warranty, picture: String
    public let price: Double
}

public let SAMPLE_THINGS: [SampleThing] = [
    SampleThing(name: "Sofa", brand: "IKEA", model: "Söderhamn 3-seat", serial: "", room: "Living room",
                spot: "By the window", bought: "2023-04-15", shop: "IKEA Linköping", currency: "",
                warranty: "2033-04-15", picture: "sofa", price: 8995),
    SampleThing(name: "Fridge", brand: "Bosch", model: "KGN39VLEB", serial: "KGN39-2209-48817", room: "Kitchen",
                spot: "Left of the stove", bought: "2022-09-03", shop: "Elgiganten", currency: "",
                warranty: "2024-09-03", picture: "fridge", price: 10990),
    SampleThing(name: "Cordless drill", brand: "Makita", model: "DDF484", serial: "0841-77352", room: "Storage",
                spot: "Shelf 2", bought: "2024-06-10", shop: "Bauhaus", currency: "",
                warranty: "2027-06-10", picture: "drill", price: 2495),
    SampleThing(name: "Robot vacuum", brand: "Roborock", model: "S8", serial: "R8S-24-00913", room: "Living room",
                spot: "Under the bookshelf", bought: "2024-12-20", shop: "Kjell & Company", currency: "",
                warranty: "2026-12-20", picture: "vacuum", price: 5990),
    SampleThing(name: "Espresso machine", brand: "Sage", model: "Barista Express", serial: "BES875-1121-6604",
                room: "Kitchen", spot: "Counter by the window", bought: "2021-11-26", shop: "Media Markt Wien",
                currency: "EUR", warranty: "2023-11-26", picture: "espresso", price: 549),
]

extension Library {
    public static func isSample(_ it: Item) -> Bool { it.extra[SAMPLE_KEY]?.boolValue == true }

    /// The sample things he still has.
    public func sampleThings() -> [Item] { items.filter(Library.isSample) }

    /// Add the five sample things, each kept at home in its room and spot, with its details and its
    /// drawn picture (`pictures[picture]`, JPEG). One whose name he already has is skipped. Returns
    /// how many were added.
    @discardableResult
    public mutating func addSampleThings(pictures: [String: Data] = [:]) -> Int {
        var added = 0
        for s in SAMPLE_THINGS {
            guard let made = walkAdd(name: s.name, room: s.room, staysHome: true),
                  let n = items.firstIndex(where: { $0.id == made.id }) else { continue }
            items[n].manufacturer = s.brand
            items[n].model = s.model
            items[n].serial = s.serial
            items[n].acquired = s.bought
            items[n].price = s.price
            items[n].currency = s.currency
            items[n].warranty = s.warranty
            Library.setSpot(&items[n], s.spot)
            Library.setShop(&items[n], s.shop)
            items[n].extra[SAMPLE_KEY] = .bool(true)
            if let jpeg = pictures[s.picture] { _ = addThingPhoto(id: made.id, jpeg: jpeg) }
            added += 1
        }
        return added
    }

    /// Take every sample thing away again (and their pictures). Returns how many went.
    @discardableResult
    public mutating func removeSampleThings() -> Int {
        let ids = sampleThings().map(\.id)
        for id in ids { _ = deleteThing(id: id, evenABag: true) }
        return ids.count
    }
}
