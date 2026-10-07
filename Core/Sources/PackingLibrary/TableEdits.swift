import Foundation
import PackingCore

// The rules behind editing things in bulk and by hand: reading an amount he typed,
// putting back exactly what one Change all changed, and forgetting what the table
// remembers about templates that are gone.

/// An amount as he types it — grams, kilos, litres: "250", "12.5", or "12,5" (the
/// Swedish comma). nil for anything that is not a number of zero or more, so a
/// screen can SAY so instead of quietly storing 0 (Change all wrote 0 for "abc",
/// and the thing's page turned "1,5" into an empty field — the spec pass, 5 Oct
/// 2026). Empty means "not known": 0.
public func readAmount(_ typed: String) -> Double? {
    let clean = jsTrim(typed).replacingOccurrences(of: ",", with: ".")
    if clean.isEmpty { return 0 }
    // Digits with at most one point, nothing else: Double("1e3"), "inf" and "nan"
    // are numbers to Swift but not to him.
    guard clean.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
          clean.filter({ $0 == "." }).count <= 1, clean != ".",
          let value = Double(clean), value.isFinite, value >= 0 else { return nil }
    return value
}

/// A weight typed on the Mac's keys (0.68, his keyboard page for a thing): grams as
/// before — "1200", "12,5" — or with a unit, "1,2 kg", "1.2kg", "250 g", always
/// answered in GRAMS (the field's unit). Spaces anywhere are ignored ("1 200"). nil for
/// what is not a weight ("abc", "kg", "-1"), so the page can say so; empty is 0.
public func readGrams(_ typed: String) -> Double? {
    var clean = jsTrim(typed).lowercased().replacingOccurrences(of: " ", with: "")
    var factor = 1.0
    for (unit, times) in [("kilos", 1000.0), ("kilo", 1000.0), ("kg", 1000.0), ("grams", 1.0), ("gram", 1.0), ("g", 1.0)]
    where clean.hasSuffix(unit) {
        clean.removeLast(unit.count)
        guard !clean.isEmpty else { return nil }          // a unit and no number
        factor = times
        break
    }
    guard let value = readAmount(clean) else { return nil }
    // 1.2 × 1000 must be 1200, not 1199.9999…: kept to the two decimals a weight shows.
    return (value * factor * 100).rounded() / 100
}

/// An amount written back for him to read: whole numbers without a point, the rest
/// with as many decimals as they need (up to two) — 88.7 stays 88.7, never 88.
public func amountText(_ value: Double) -> String {
    guard value.isFinite, value > 0 else { return "" }
    if value == value.rounded() { return String(Int(value)) }
    var s = String(format: "%.2f", value)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}

extension Library {
    /// Undo ONE Change all: `before` are the things as they were, `after` as that
    /// change left them. Only what the change altered goes back, and only where it
    /// still holds what the change wrote — a cell edited on those things since is
    /// his later word and stays (Undo used to write each thing back WHOLE, undoing
    /// his later edits too; the spec pass, 5 Oct 2026). Returns how many things
    /// were put back.
    @discardableResult
    public mutating func undoChange(before: [Item], after: [Item]) -> Int {
        var n = 0
        for old in before {
            guard let made = after.first(where: { $0.id == old.id }),
                  let now = items.first(where: { $0.id == old.id }),
                  case .object(let was) = old.json, case .object(let wrote) = made.json,
                  case .object(var current) = now.json else { continue }
            var touched = false
            for (key, value) in wrote where was[key] != value && current[key] == value {
                current[key] = was[key] ?? .null
                touched = true
            }
            guard touched else { continue }
            let back = Item(json: .object(current))
            if updateThing(id: old.id, { $0 = back }) { n += 1 }
        }
        return n
    }

    /// Does the table still have this column, filter or sort key? A key naming a
    /// template ("list:<id>", "section:<id>") lives only as long as that template —
    /// and never his bag list, which is no column (`templatesForThings`). Every other
    /// key belongs to the thing itself and always exists.
    ///
    /// A filter kept for a deleted template went on filtering with no pill to show
    /// it ("Nothing matches these filters." until Clear), and a deleted template's
    /// column kept an invisible place in the Columns order (the spec pass, 5 Oct 2026).
    public func tableKnows(_ key: String) -> Bool {
        for prefix in ["list:", "section:"] where key.hasPrefix(prefix) {
            let id = String(key.dropFirst(prefix.count))
            return templatesForThings().contains { $0.id == id }
        }
        return true
    }

    /// The filters that still mean something.
    public func liveFilters(_ filters: ThingFilters) -> ThingFilters {
        filters.filter { tableKnows($0.key) && !$0.value.isEmpty }
    }
}
