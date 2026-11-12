import Foundation
import PackingCore

// 0.121 — the four inventory pieces left over from his plan (docs/inventory/plan.md, answers 15, 20,
// "Manuals: link first, a stored PDF when wanted" and the totals' "N in another currency"), asked for
// in one go on 12 Nov 2026:
//   1. the serial number scanned with the camera (iPhone) — `cleanSerial` tidies what was read;
//   2. a thing marked Gone, with the day, how it went and what it sold for;
//   3. prices in other currencies counted in the totals, at today's rates;
//   4. a manual kept as a PDF on the thing (until now only a link).
// Everything new is kept in the thing's `extra` or the photo store, as before: no new record type,
// no new iCloud field, and a backup or the web app carries it through untouched.

// MARK: - 1. Serial scan

extension Library {
    /// What the camera read, as a serial: a label in front ("S/N:", "SN", "Serial No.", "Serial number",
    /// "Ser. Nr", "Seriennummer", "Serienummer") is dropped, as are spaces at the ends and a stray colon
    /// or dash; the number itself is kept as printed (inner spaces too, "4512 0877").
    public static func cleanSerial(_ scanned: String) -> String {
        var s = jsTrim(scanned.replacingOccurrences(of: "\n", with: " "))
        let labels = ["serial number", "serial no.", "serial no", "serial nr.", "serial nr", "serial #", "serial",
                      "seriennummer", "serienummer", "serienr.", "serienr", "ser. nr.", "ser. nr", "ser.no.", "ser.no",
                      "s/n", "s / n", "s.n.", "sn", "no."]
        let lower = s.lowercased()
        for l in labels where lower.hasPrefix(l) {
            let rest = s.dropFirst(l.count)
            // "SN" only as a label when something that is not a letter follows ("SN:", "SN 12") — never "SNOW1".
            if l == "sn" || l == "no.", let c = rest.first, c.isLetter { continue }
            s = String(rest)
            break
        }
        s = jsTrim(s)
        while let c = s.first, c == ":" || c == "-" || c == "#" || c == "." { s = jsTrim(String(s.dropFirst())) }
        return s
    }
}

// MARK: - 2. Gone

public let GONE_KEY = "gone"

/// How a thing went. The raw value is what is stored.
public enum GoneHow: String, CaseIterable, Sendable {
    case sold, givenAway, broken, lost, stolen

    public var label: String {
        switch self {
        case .sold: return "Sold"
        case .givenAway: return "Given away"
        case .broken: return "Broken"
        case .lost: return "Lost"
        case .stolen: return "Stolen"
        }
    }
}

/// A thing that is gone: the day, how, and (sold) what it fetched, in kronor unless `currency` says.
public struct GoneMark: Equatable, Sendable {
    public var on: String
    public var how: GoneHow
    public var soldFor: Double?
    public var currency: String
    public init(on: String, how: GoneHow, soldFor: Double? = nil, currency: String = "") {
        self.on = on; self.how = how; self.soldFor = soldFor; self.currency = currency
    }

    var json: JSONValue {
        var o: [String: JSONValue] = ["on": .string(on), "how": .string(how.rawValue)]
        if how == .sold, let v = soldFor, v > 0 { o["soldFor"] = .number(v) }
        let c = jsTrim(currency)
        if how == .sold, !c.isEmpty { o["currency"] = .string(c) }
        return .object(o)
    }
}

/// The Gone view's numbers.
public struct GoneTotals: Equatable, Sendable {
    public var things = 0
    public var sold = 0
    /// What the sold ones fetched, in kronor (other currencies at today's rates).
    public var soldFor = 0.0
    public init() {}
}

extension Library {
    /// The Gone mark of a thing, or nil while he still has it.
    public static func gone(_ it: Item) -> GoneMark? {
        guard case .object(let o)? = it.extra[GONE_KEY] else { return nil }
        let how = GoneHow(rawValue: jsStringOr(o["how"])) ?? .givenAway
        var sold: Double?
        if case .number(let v)? = o["soldFor"] { sold = v }
        return GoneMark(on: jsStringOr(o["on"]), how: how, soldFor: how == .sold ? sold : nil,
                        currency: jsStringOr(o["currency"]))
    }

    public static func isGone(_ it: Item) -> Bool { gone(it) != nil }

    /// Mark a thing Gone (or, with nil, back in use). Gone also makes it Not in use, so no trip,
    /// template, ＋ Add, reminder, total or insurance list offers it — everything else on it (photos,
    /// papers, price) is kept. Back in use clears both.
    public static func setGone(_ it: inout Item, _ mark: GoneMark?) {
        if let mark {
            it.extra[GONE_KEY] = mark.json
            it.retired = true
        } else {
            guard it.extra[GONE_KEY] != nil else { return }
            it.extra[GONE_KEY] = nil
            it.retired = false
        }
    }

    /// "Sold 3 Mar 2027 · 1 200 kr", "Lost 2 Jan 2027".
    public static func goneLine(_ it: Item) -> String {
        guard let g = gone(it) else { return "" }
        var s = g.how.label
        if isYMD(g.on) { s += " " + dayWords(g.on) }
        if g.how == .sold, let v = g.soldFor, v > 0 { s += " \u{00B7} " + moneyWords(v, currency: g.currency) }
        return s
    }

    /// His things that are gone, the latest first.
    public func goneThings() -> [Item] {
        ownThings().filter(Library.isGone).sorted {
            let (a, b) = (Library.gone($0)?.on ?? "", Library.gone($1)?.on ?? "")
            return a != b ? a > b : jsLocaleCompare($0.name, $1.name) < 0
        }
    }

    public static func goneTotals(_ things: [Item], rates: CurrencyRates = .current) -> GoneTotals {
        var t = GoneTotals()
        for it in things {
            guard let g = gone(it) else { continue }
            t.things += 1
            guard g.how == .sold else { continue }
            t.sold += 1
            if let v = g.soldFor, v > 0, let sek = rates.inKronor(v, g.currency) { t.soldFor += sek }
        }
        return t
    }
}

// MARK: - 3. Other currencies

/// Kronor for one unit of each currency, and the day they are from. `current` is what the app uses;
/// it starts with the built-in rates and is replaced by today's (fetched once a day, kept on the device).
public struct CurrencyRates: Equatable, Sendable {
    /// Kronor per one unit, keyed by ISO code ("EUR": 11.0).
    public var sekPer: [String: Double]
    /// The day the rates are from ("" for the built-in ones).
    public var day: String

    public init(sekPer: [String: Double], day: String) { self.sekPer = sekPer; self.day = day }

    /// Rough rates, used until the first fetch (and whenever the phone has been offline since the start).
    public static let builtIn = CurrencyRates(sekPer: [
        "EUR": 11.1, "USD": 9.5, "GBP": 12.6, "NOK": 0.94, "DKK": 1.49, "CHF": 11.9, "ISK": 0.077,
        "PLN": 2.6, "CZK": 0.44, "HUF": 0.028, "JPY": 0.062, "CNY": 1.32, "CAD": 6.8, "AUD": 6.2,
        "NZD": 5.6, "THB": 0.29, "TRY": 0.24, "HKD": 1.22, "SGD": 7.3, "KRW": 0.0068, "INR": 0.11,
        "MXN": 0.52, "BRL": 1.7, "ZAR": 0.53,
    ], day: "")

    nonisolated(unsafe) public static var current: CurrencyRates = .builtIn

    /// A typed currency as its code: "" / "kr" / "sek" → SEK; "€" / "euro" → EUR; "$" → USD; "£" → GBP;
    /// otherwise the letters, in capitals.
    public static func code(_ typed: String) -> String {
        let t = jsTrim(typed).lowercased()
        switch t {
        case "", "kr", "kr.", "sek", ":-", "kronor", "skr": return "SEK"
        case "€", "eur", "euro", "euros": return "EUR"
        case "$", "us$", "usd", "dollar", "dollars": return "USD"
        case "£", "gbp", "pound", "pounds": return "GBP"
        case "nok", "nkr": return "NOK"
        case "dkk", "dkr": return "DKK"
        case "¥", "yen", "jpy": return "JPY"
        case "chf", "fr.", "sfr": return "CHF"
        default: return t.uppercased()
        }
    }

    /// An amount in kronor; nil for a currency these rates do not know.
    public func inKronor(_ amount: Double, _ typed: String) -> Double? {
        let c = CurrencyRates.code(typed)
        if c == "SEK" { return amount }
        guard let r = sekPer[c], r > 0 else { return nil }
        return amount * r
    }

    /// Reads the rates service's answer for `?from=SEK` ({"date": "2026-11-12", "rates": {"EUR": 0.09}} —
    /// units per krona) as kronor per unit. nil when it is not that shape.
    public static func parse(_ data: Data) -> CurrencyRates? {
        guard let v = try? JSONValue.parse(data), case .object(let rates)? = v["rates"] else { return nil }
        var out: [String: Double] = [:]
        for (k, val) in rates { if case .number(let n) = val, n > 0 { out[k.uppercased()] = 1 / n } }
        guard !out.isEmpty else { return nil }
        return CurrencyRates(sekPer: out, day: jsStringOr(v["date"]))
    }

    /// Stored on the device as {"day": …, "sekPer": {…}}.
    public var stored: Data {
        let o: JSONValue = ["day": .string(day), "sekPer": .object(sekPer.mapValues { .number($0) })]
        return Data(o.text().utf8)
    }
    public static func fromStored(_ data: Data) -> CurrencyRates? {
        guard let v = try? JSONValue.parse(data), case .object(let m)? = v["sekPer"] else { return nil }
        var out: [String: Double] = [:]
        for (k, val) in m { if case .number(let n) = val { out[k] = n } }
        return out.isEmpty ? nil : CurrencyRates(sekPer: out, day: jsStringOr(v["day"]))
    }
}

// MARK: - 4. Manual as a PDF

/// A PDF is kept up to 25 MB — a long manual fits; a scanned book does not.
public let PAPER_PDF_MAX_BYTES = 25 * 1_024 * 1_024
public let PDF_MIME = "application/pdf"

extension Library {
    /// Is this paper's picture a PDF (a stored manual) rather than a photo?
    public static func isPDF(_ photo: PhotoRecord?) -> Bool {
        photo?.data.hasPrefix("data:\(PDF_MIME);") == true
    }

    /// The PDF's bytes (nil for a photo, or one still on its way).
    public static func pdfBytes(_ photo: PhotoRecord?) -> Data? {
        guard let p = photo, isPDF(p), let comma = p.data.firstIndex(of: ",") else { return nil }
        return Data(base64Encoded: String(p.data[p.data.index(after: comma)...]))
    }

    /// Keep a PDF on a thing — a Manual, named as the file was. Refused (nil) for no thing, a full list,
    /// bytes that are not a PDF, or one over 25 MB.
    @discardableResult
    public mutating func addPaperPDF(id: String, pdf: Data, name: String, kind: PaperKind = .manual) -> Paper? {
        guard pdf.count <= PAPER_PDF_MAX_BYTES, pdf.starts(with: Array("%PDF".utf8)), takesPaper(id: id) else { return nil }
        let at = nowISO()
        let photo = PhotoRecord(id: PackingEnv.makeId(), data: "data:\(PDF_MIME);base64,\(pdf.base64EncodedString())",
                                createdAt: at)
        photos.append(photo)
        var file = jsTrim(name)
        if file.lowercased().hasSuffix(".pdf") { file = String(file.dropLast(4)) }
        let paper = Paper(id: photo.id, kind: kind, at: at, file: file.isEmpty ? "Manual" : file)
        _ = updateThing(id: id) { thing in
            var list = Library.papers(thing); list.append(paper); Library.setPapers(&thing, list)
        }
        return paper
    }
}
