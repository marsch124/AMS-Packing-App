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

        // What needs looking after, and when the rest falls due.
        for row in careRows(today: day) {
            switch row.status.state {
            case "overdue": out.overdue += 1
            case "soon": out.soon += 1
            default: break
            }
            if let days = row.status.days, days >= 0 {
                let month = min(11, days / 30)
                out.dueByMonth[month] += 1
            }
        }

        out.heaviest = live.filter { $0.weight > 0 }
            .sorted { $0.weight > $1.weight }
            .prefix(heaviestCount)
            .map { KitStats.Heavy(name: $0.name, grams: $0.weight, place: $0.storage) }

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

        // What each list weighs.
        out.lists = resolvedTemplates().map { list in
            KitStats.Slice(label: list.name, count: list.items.count,
                           grams: list.items.reduce(0) { $0 + max(0, $1.weight) })
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
