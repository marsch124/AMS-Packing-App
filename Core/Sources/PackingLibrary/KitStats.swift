import Foundation
import PackingCore

// What his kit adds up to.
//
// Built on what his library ACTUALLY holds, counted from the real file: 514 of
// 431 things carry a weight and 516 a storage place, while conditions, expiry
// dates and consumables are all empty and only two things have care notes. So
// this says what it can say truthfully — what the kit weighs, where it lives,
// what is due — and invites the rest rather than drawing empty charts.

extension Library {
    public struct KitStats: Equatable, Sendable {
        public struct Slice: Equatable, Sendable {
            public var label: String
            public var count: Int
            public var grams: Double
            public init(label: String, count: Int, grams: Double) {
                self.label = label; self.count = count; self.grams = grams
            }
        }
        public struct Heavy: Equatable, Sendable {
            public var name: String
            public var grams: Double
            public var place: String
            public init(name: String, grams: Double, place: String) {
                self.name = name; self.grams = grams; self.place = place
            }
        }

        public var things = 0
        public var weighed = 0
        public var totalGrams: Double = 0
        public var withPlace = 0
        public var withCare = 0
        public var overdue = 0
        public var soon = 0
        /// The heaviest things he owns, heaviest first.
        public var heaviest: [Heavy] = []
        /// Where his things live, most things first.
        public var places: [Slice] = []
        /// What each list weighs, heaviest first.
        public var lists: [Slice] = []
        /// Care due over the next twelve months, this month first.
        public var dueByMonth: [Int] = Array(repeating: 0, count: 12)
        /// Things that have gone along and never been used — the ones worth leaving home.
        public var neverUsed: [String] = []
        /// What is worth telling him, in his words. Only true things.
        public var tips: [String] = []

        /// "2026-10-05" → the month counted from year 0 (year × 12 + month), so two
        /// dates' months can be subtracted. nil for anything that is not a date.
        static func monthNumber(_ ymd: String) -> Int? {
            let parts = ymd.split(separator: "-")
            guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) else { return nil }
            return y * 12 + (m - 1)
        }

        public var unweighed: Int { max(0, things - weighed) }
        public var withoutPlace: Int { max(0, things - withPlace) }
        /// The kit's total weight in kilos, to one decimal.
        public var totalKilos: Double { (totalGrams / 1000 * 10).rounded() / 10 }
    }

    public func kitStats(today: String = "", heaviestCount: Int = 8) -> KitStats {
        var out = KitStats()
        let day = today.isEmpty ? String(nowISO().prefix(10)) : today
        let live = items.filter { !$0.retired }
        out.things = live.count

        for thing in live {
            if thing.weight > 0 { out.weighed += 1; out.totalGrams += thing.weight }
            if !jsTrim(thing.storage).isEmpty { out.withPlace += 1 }
            if let care = thing.maintenance, !(jsTrim(care.notes).isEmpty && care.intervalDays <= 0) {
                out.withCare += 1
            }
            if thing.stats.packed > 0 && thing.stats.used == 0 { out.neverUsed.append(thing.name) }
        }

        // What needs looking after, and when the rest falls due — by CALENDAR month,
        // this month first, as the bars are labelled. (They were 30-day blocks from
        // today under month names, the last one holding everything from day 330 on —
        // the spec pass, 5 Oct 2026.) A service due after the twelfth month is not
        // on the year ahead.
        let thisMonth = KitStats.monthNumber(day)
        for row in careRows(today: day) {
            switch row.status.state {
            case "overdue": out.overdue += 1
            case "soon": out.soon += 1
            default: break
            }
            if let days = row.status.days, days >= 0,
               let now = thisMonth, let due = KitStats.monthNumber(row.status.nextDue) {
                let ahead = due - now
                if (0..<12).contains(ahead) { out.dueByMonth[ahead] += 1 }
            }
        }

        // A kit (a pouch of things, ThingKits) weighs what is inside it too.
        let kits = kitIndex()
        out.heaviest = live.map { (thing: $0, grams: packedWeight($0, index: kits)) }
            .filter { $0.grams > 0 }
            .sorted { $0.grams > $1.grams }
            .prefix(heaviestCount)
            .map { KitStats.Heavy(name: $0.thing.name, grams: $0.grams, place: $0.thing.storage) }

        // Where things live.
        var byPlace: [String: KitStats.Slice] = [:]
        for thing in live {
            let place = jsTrim(thing.storage).isEmpty ? "Nowhere said" : jsTrim(thing.storage)
            var slice = byPlace[place] ?? KitStats.Slice(label: place, count: 0, grams: 0)
            slice.count += 1
            slice.grams += max(0, thing.weight)
            byPlace[place] = slice
        }
        out.places = byPlace.values.sorted { $0.count == $1.count ? $0.label < $1.label : $0.count > $1.count }

        // What each list weighs — his bag list under the name he knows it by, "Bags"
        // (it said the stored "Containers"; his words rule, 27 Sep 2026).
        out.lists = resolvedTemplates().map { list in
            KitStats.Slice(label: shownName(list), count: list.items.count,
                           grams: list.items.reduce(0) { sum, row in
                               sum + max(0, row.weight) + Library.contentsWeight(row.itemId.flatMap { kits.contents[$0] } ?? [])
                           })
        }.sorted { $0.grams > $1.grams }

        out.tips = tips(out)
        return out
    }

    /// Things worth saying, and only when they are true of HIS library.
    private func tips(_ s: KitStats) -> [String] {
        var out: [String] = []
        if s.overdue > 0 {
            out.append("\(s.overdue) thing\(s.overdue == 1 ? "" : "s") \(s.overdue == 1 ? "is" : "are") overdue for looking after.")
        }
        if s.withCare <= 2, s.things > 50 {
            out.append("Only \(s.withCare) of your \(s.things) things have care notes. The ones that wear out — boots, wetsuit, bike — are worth a schedule.")
        }
        if s.withoutPlace > 0 {
            out.append("\(s.withoutPlace) thing\(s.withoutPlace == 1 ? "" : "s") \(s.withoutPlace == 1 ? "has" : "have") no storage place. Saying where they live makes packing quicker.")
        }
        if let heaviest = s.heaviest.first, s.totalGrams > 0 {
            let share = Int((heaviest.grams / s.totalGrams * 100).rounded())
            if share >= 5 {
                out.append("\(heaviest.name) alone is \(share)% of everything you own by weight.")
            }
        }
        if !s.neverUsed.isEmpty {
            let n = s.neverUsed.count
            out.append("\(n) thing\(n == 1 ? "" : "s") went along and came home unused. Worth leaving behind next time.")
        }
        if s.unweighed > 0, s.weighed > 0 {
            out.append("\(s.unweighed) thing\(s.unweighed == 1 ? "" : "s") \(s.unweighed == 1 ? "has" : "have") no weight yet, so the totals are a little light.")
        }
        return out
    }
}
