import Foundation
import PackingCore

// Filters for the things table — his ask, 4 Oct 2026: "I would like all existing
// columns to be able to be used as filter criteria" (Travel section, owner, packed
// by, and so on). Every column the table can show is a filter here, with the same
// id. A filter keeps the answers ticked for it; ticks in one column mean "any of
// these", and two filtered columns must both hold.
//
// The answers offered are the ones his things actually have, each with how many
// things have it, so a filter never leads to an empty table by surprise.

/// One answer a column can be filtered by: what is compared, what he reads, and how
/// many of the things in view give it.
public struct FilterAnswer: Equatable, Sendable {
    public let value: String
    public let label: String
    public let count: Int
    public init(value: String, label: String, count: Int) { self.value = value; self.label = label; self.count = count }
}

/// Column id → the answers kept. An empty set filters nothing.
public typealias ThingFilters = [String: Set<String>]

/// The template columns' answers. A thing on the template gives "on" and the
/// section it sits in there; a thing not on it gives "off".
public let FILTER_ON = "on"
public let FILTER_OFF = "off"
public let FILTER_SECTION = "section:"
/// The per-list columns' answers for a thing on no template, or on several.
public let FILTER_NO_TEMPLATE = "none"
public let FILTER_SEVERAL = "several"

/// What a thing with no owner is called: each of them has one (his words, 4 Oct 2026).
public let OWNER_BOTH = "Both have one"

/// The weight column groups weights instead of listing every gram.
public let FILTER_WEIGHTS: [(value: String, label: String, below: Double)] = [
    ("", "No weight", 0), ("w1", "Under 100 g", 100), ("w2", "100 – 500 g", 500),
    ("w3", "500 g – 1 kg", 1000), ("w4", "Over 1 kg", .infinity),
]

extension Library {
    /// The fields of the thing itself, by the table's column ids.
    static let textFields: [String: KeyPath<Item, String>] = [
        "storage": \.storage, "container": \.container, "ownedBy": \.ownedBy, "packer": \.packer,
        "condition": \.condition, "color": \.color, "size": \.size, "manufacturer": \.manufacturer,
        "model": \.model, "serial": \.serial, "note": \.note,
    ]
    static let flagFields: [String: KeyPath<Item, Bool>] = [
        "liquid": \.liquid, "charging": \.charging, "restricted": \.restricted,
        "consumable": \.consumable, "perNight": \.perNight,
    ]

    /// What one thing answers to one column. Usually one answer; a template column
    /// can give two ("on" and its section there).
    public func filterValues(_ thing: Item, column: String, memberships byThing: [String: [Membership]]? = nil) -> [String] {
        let mine = byThing?[thing.id] ?? memberships.filter { $0.itemId == thing.id }
        if let path = Library.textFields[column] { return [normName(jsTrim(thing[keyPath: path]))] }
        if let path = Library.flagFields[column] { return [thing[keyPath: path] ? "yes" : "no"] }
        switch column {
        case "weight":
            let grams = packedWeight(thing)      // a kit with what is inside it (ThingKits)
            if grams <= 0 { return [""] }
            return [FILTER_WEIGHTS.dropFirst().first { grams < $0.below }?.value ?? "w4"]
        case "listQty", "listSection":
            if mine.isEmpty { return [FILTER_NO_TEMPLATE] }
            if mine.count > 1 { return [FILTER_SEVERAL] }
            return [column == "listQty" ? jsTrim(mine[0].qty) : mine[0].section]
        default:
            guard column.hasPrefix("list:") else { return [] }
            let listId = String(column.dropFirst(5))
            let here = mine.filter { $0.templateId == listId }
            if here.isEmpty { return [FILTER_OFF] }
            return [FILTER_ON] + here.map { FILTER_SECTION + $0.section }
        }
    }

    /// Does the thing hold to every filter?
    public func passes(_ thing: Item, _ filters: ThingFilters, memberships byThing: [String: [Membership]]? = nil) -> Bool {
        for (column, kept) in filters where !kept.isEmpty {
            if Set(filterValues(thing, column: column, memberships: byThing)).isDisjoint(with: kept) { return false }
        }
        return true
    }

    /// The answers a column offers among these things, in the order he reads them:
    /// words A–Z with Blank last; Yes before No; weights light to heavy; a
    /// template's "On it", then its sections in order, then "Not on it".
    public func filterAnswers(column: String, among things: [Item]) -> [FilterAnswer] {
        let byThing = Dictionary(grouping: memberships, by: \.itemId)
        var count: [String: Int] = [:]
        var shown: [String: String] = [:]   // value → the text as first written
        for thing in things {
            for value in Set(filterValues(thing, column: column, memberships: byThing)) {
                count[value, default: 0] += 1
                if shown[value] == nil, let path = Library.textFields[column] {
                    shown[value] = jsTrim(thing[keyPath: path])
                }
            }
        }
        func answer(_ value: String, _ label: String) -> FilterAnswer? {
            guard let n = count[value], n > 0 else { return nil }
            return FilterAnswer(value: value, label: label, count: n)
        }
        if Library.textFields[column] != nil {
            let labels = conditionLabels()
            let words = count.keys.filter { !$0.isEmpty }.sorted()
            var out = words.compactMap { value -> FilterAnswer? in
                let written = shown[value] ?? value
                return answer(value, column == "condition" ? (labels[normName(written)] ?? written) : written)
            }
            if let blank = answer("", column == "ownedBy" ? OWNER_BOTH : "Blank") { out.append(blank) }
            return out
        }
        if Library.flagFields[column] != nil {
            return [answer("yes", "Yes"), answer("no", "No")].compactMap { $0 }
        }
        switch column {
        case "weight":
            return FILTER_WEIGHTS.dropFirst().compactMap { answer($0.value, $0.label) } + [answer("", "No weight")].compactMap { $0 }
        case "listQty":
            let numbers = count.keys.filter { ![FILTER_NO_TEMPLATE, FILTER_SEVERAL, ""].contains($0) }
                .sorted { (Double($0) ?? .infinity, $0) < (Double($1) ?? .infinity, $1) }
            return numbers.compactMap { answer($0, $0) }
                + [answer("", "Blank"), answer(FILTER_SEVERAL, "On several templates"),
                   answer(FILTER_NO_TEMPLATE, "On no template")].compactMap { $0 }
        case "listSection":
            var out: [FilterAnswer] = []
            for list in templates { for section in list.sections {
                if let a = answer(section.id, "\(section.name) (\(shownName(list)))") { out.append(a) }
            } }
            return out + [answer("", "No section"), answer(FILTER_SEVERAL, "On several templates"),
                          answer(FILTER_NO_TEMPLATE, "On no template")].compactMap { $0 }
        default:
            guard column.hasPrefix("list:"), let list = templates.first(where: { "list:\($0.id)" == column }) else { return [] }
            var out = [answer(FILTER_ON, "On it")].compactMap { $0 }
            for section in list.sections {
                if let a = answer(FILTER_SECTION + section.id, "Section: \(section.name)") { out.append(a) }
            }
            if !list.sections.isEmpty, let a = answer(FILTER_SECTION, "On it, no section") { out.append(a) }
            if let a = answer(FILTER_OFF, "Not on it") { out.append(a) }
            return out
        }
    }

    /// A condition's key or label → its label ("retire" → "Needs replacing").
    func conditionLabels() -> [String: String] {
        var out: [String: String] = [:]
        for c in conditions() { out[normName(c.id)] = c.label; out[normName(c.label)] = c.label }
        return out
    }

    /// What a pill above the table says for one filtered column: "Kim, Robin".
    public func filterSummary(column: String, kept: Set<String>) -> String {
        let all = filterAnswers(column: column, among: items)
        let labels = all.filter { kept.contains($0.value) }.map(\.label)
        return labels.isEmpty ? "\(kept.count) chosen" : labels.joined(separator: ", ")
    }
}
