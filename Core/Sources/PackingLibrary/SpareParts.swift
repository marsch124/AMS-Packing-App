import Foundation
import PackingCore

// 0.124 — spare parts and refills (his pick of 12 Nov 2026): a fridge's water filter, a vacuum's bags.
// Each part says how often it is needed (0 = when needed) and when it was last bought; a due one goes
// onto To buy by itself ("Water filter for Fridge"), tagged with `extra["part"]` = "<thing id>/<part id>",
// and ticking that line bought moves the part's last-bought day on. Kept in the thing's `extra["parts"]`.

public let PARTS_KEY = "parts"
public let PART_LINE_KEY = "part"
/// How often, in months, offered as chips (0 = when needed).
public let PART_MONTHS: [Int] = [0, 3, 6, 12]

public struct SparePart: Equatable, Sendable {
    public var id: String
    public var name: String
    public var months: Int
    /// Last bought, YYYY-MM-DD ("" = not yet).
    public var last: String
    public init(id: String, name: String, months: Int, last: String = "") {
        self.id = id; self.name = name; self.months = months; self.last = last
    }
    var json: JSONValue {
        .object(["id": .string(id), "name": .string(name), "months": .number(Double(months)), "last": .string(last)])
    }
    /// When the next one is due ("" for one bought when needed, or never bought yet).
    public var nextDue: String { months > 0 && isYMD(last) ? addMonths(last, months) : "" }
    /// "Every 6 months · next 1 May 2027", "When needed · last 3 Mar 2026".
    public var line: String {
        var s = months == 0 ? "When needed" : "Every \(months) months"
        if !nextDue.isEmpty { s += " \u{00B7} next " + Library.dayWords(nextDue) }
        else if isYMD(last) { s += " \u{00B7} last " + Library.dayWords(last) }
        return s
    }
}

extension Library {
    public static func parts(_ it: Item?) -> [SparePart] {
        guard case .array(let rows)? = it?.extra[PARTS_KEY] else { return [] }
        return rows.compactMap { r in
            let id = jsStringOr(r["id"]), name = jsStringOr(r["name"])
            guard !id.isEmpty, !jsTrim(name).isEmpty else { return nil }
            var m = 0
            if case .number(let v)? = r["months"] { m = Int(v) }
            return SparePart(id: id, name: name, months: max(0, m), last: jsStringOr(r["last"]))
        }
    }

    static func setParts(_ it: inout Item, _ list: [SparePart]) {
        it.extra[PARTS_KEY] = list.isEmpty ? nil : .array(list.map(\.json))
    }

    /// Add a part to a thing (a blank name adds nothing). Bought "today" when `boughtToday`.
    @discardableResult
    public mutating func addPart(thingId: String, name: String, months: Int, last: String = "") -> SparePart? {
        let n = jsTrim(name)
        guard !n.isEmpty, items.contains(where: { $0.id == thingId }) else { return nil }
        let part = SparePart(id: PackingEnv.makeId(), name: n, months: max(0, months), last: last)
        _ = updateThing(id: thingId) { t in var l = Library.parts(t); l.append(part); Library.setParts(&t, l) }
        return part
    }

    public mutating func partBought(thingId: String, partId: String, on day: String) {
        _ = updateThing(id: thingId) { t in
            var l = Library.parts(t)
            for k in l.indices where l[k].id == partId { l[k].last = day }
            Library.setParts(&t, l)
        }
    }

    public mutating func removePart(thingId: String, partId: String) {
        _ = updateThing(id: thingId) { t in Library.setParts(&t, Library.parts(t).filter { $0.id != partId }) }
    }

    /// Keep To buy and the parts in step: a ticked part line moves its part's last-bought day on; a part
    /// due today or before that has no open line gets one. Returns whether anything changed.
    @discardableResult
    public mutating func syncPartsToBuy(today: String) -> Bool {
        guard isYMD(today) else { return false }
        var changed = false
        let lines = buyList()
        // 1. Ticked lines → bought on the day they were ticked.
        for line in lines where line.done {
            guard let tag = line.extra[PART_LINE_KEY]?.stringValue else { continue }
            let bits = tag.split(separator: "/").map(String.init)
            guard bits.count == 2, let thing = items.first(where: { $0.id == bits[0] }),
                  let part = Library.parts(thing).first(where: { $0.id == bits[1] }) else { continue }
            let day = isYMD(String(line.doneAt.prefix(10))) ? String(line.doneAt.prefix(10)) : today
            if part.last < day { partBought(thingId: thing.id, partId: part.id, on: day); changed = true }
        }
        // 2. Due parts → a line.
        let open = Set(buyList().filter { !$0.done }.compactMap { $0.extra[PART_LINE_KEY]?.stringValue })
        for it in ownThings() where !it.retired {
            for p in Library.parts(it) where !p.nextDue.isEmpty && p.nextDue <= today {
                let tag = "\(it.id)/\(p.id)"
                guard !open.contains(tag), let line = addToBuyList(text: "\(p.name) for \(it.name)") else { continue }
                if let k = actions.firstIndex(where: { $0.id == line.id }) {
                    actions[k].extra[PART_LINE_KEY] = .string(tag)
                    actions[k].itemId = it.id; actions[k].itemName = it.name
                }
                changed = true
            }
        }
        return changed
    }
}
