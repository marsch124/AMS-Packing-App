import Foundation
import PackingCore

// "Make a small core from this…" (0.71, 8 Oct 2026). His always-packed template had
// grown far too big for a weekend away: "Always packed will be a small core, and
// [the big one] becomes a big kit that I tick." The library lives in his app, so the
// APP makes the move, with one confirmation from him:
//
//  - a NEW always-packed template is made from the rows he ticks — the same things,
//    with every row's own answers (How many, Section, Note, Only on, When, bag);
//  - the big template keeps every row it had and only changes its area: out of
//    Always packed, to the area he picks (GA / WET / OE / none), so from then on it
//    comes on a trip only when ticked.
//
// What is offered ticked at first: the sections that read as clothes or washing
// (English and Swedish words) and the things packed per night. His own pasted list
// wins over that (`planPaste`). Reminders are not things: they stay on the big one.

extension Library {
    /// An always-packed template with more than this many things offers the door.
    public static let SMALL_CORE_FROM = 20

    /// Words in a section's name that make it "clothes or washing" — ticked at first.
    public static let SMALL_CORE_WORDS = ["clothing", "clothes", "underwear", "toiletries", "hygiene", "wash",
                                          "bathroom", "kläder", "hygien", "toalett"]

    /// Lower case, accents gone, spaces collapsed: "Kläder " and "klader" read the same.
    static func folded(_ s: String) -> String {
        normName(s).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// The things (not reminders) on a template, as resolved rows.
    public func smallCoreRows(templateId: String) -> [Item] {
        (resolvedTemplate(id: templateId)?.items ?? []).filter { !Library.isReminder($0) && $0.memId != nil }
    }

    /// Does this template offer "Make a small core from this…"? Always packed, and big.
    public func offersSmallCore(templateId: String) -> Bool {
        guard let t = templates.first(where: { $0.id == templateId }), t.role == Library.ALWAYS_PACKED_AREA else { return false }
        return smallCoreRows(templateId: templateId).count > Library.SMALL_CORE_FROM
    }

    /// The template's things under its own headings, in its order ("Everything else"
    /// last) — as the sheet shows them.
    public func smallCoreGroups(templateId: String) -> [(title: String, rows: [Item])] {
        let sections = templates.first { $0.id == templateId }?.sections ?? []
        return groupItemsBySection(smallCoreRows(templateId: templateId), sections)
            .filter { !$0.items.isEmpty }
            .map { ($0.section?.name ?? "Everything else", $0.items) }
    }

    /// Is this a section of clothes or washing? (Any of `SMALL_CORE_WORDS` in its name.)
    public static func readsAsCore(sectionName: String) -> Bool {
        let n = folded(sectionName)
        return SMALL_CORE_WORDS.contains { n.contains(folded($0)) }
    }

    /// The rows ticked when the sheet opens (their membership ids): those under a
    /// clothes or washing heading, and the things packed per night.
    public func smallCoreSuggestion(templateId: String) -> Set<String> {
        var out = Set<String>()
        for g in smallCoreGroups(templateId: templateId) {
            let core = g.title != "Everything else" && Library.readsAsCore(sectionName: g.title)
            for r in g.rows where core || r.perNight { if let m = r.memId { out.insert(m) } }
        }
        return out
    }
    // MARK: - His own list, pasted

    /// One line of a pasted list: its names (a line may hold several, by commas) and
    /// whether it is indented under the line before — a thing inside a kit.
    public struct PastedLine: Equatable, Sendable {
        public var names: [String]
        public var depth: Int
    }

    /// A bullet, a dash, "1." / "2)" or a "[ ]" box in front — repeatedly, so "- [x]
    /// Socks" is Socks — but never a number that is part of the name ("3-in-1").
    private static let lead = try! NSRegularExpression(pattern: "^\\s*(?:[-\u{2013}\u{2014}*\u{2022}\u{00B7}+>]+|\\d+[.)]|\\[[ xX]?\\])\\s*")

    static func stripLead(_ raw: String) -> String {
        var s = raw
        while let m = lead.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), m.range.length > 0,
              let r = Range(m.range, in: s) { s.removeSubrange(r) }
        return jsTrim(s)
    }

    /// The lines of a pasted list. A line indented deeper than the last line at the
    /// left (spaces or a tab — a tab counts as four) is inside it: depth 1. The first
    /// line is never inside anything.
    public static func pastedLines(_ text: String) -> [PastedLine] {
        var out: [PastedLine] = []
        var top: Int?
        for raw in text.components(separatedBy: CharacterSet(charactersIn: "\n\r")) {
            var indent = 0
            for c in raw { if c == " " { indent += 1 } else if c == "\t" { indent += 4 } else { break } }
            let names = raw.components(separatedBy: CharacterSet(charactersIn: ",;")).map(stripLead).filter { !$0.isEmpty }
            guard !names.isEmpty else { continue }
            if let t = top, indent > t, !out.isEmpty { out.append(PastedLine(names: names, depth: 1)) }
            else { top = indent; out.append(PastedLine(names: names, depth: 0)) }
        }
        return out
    }

    /// Every name in a pasted list, in order, nesting ignored.
    public static func pastedNames(_ text: String) -> [String] { pastedLines(text).flatMap(\.names) }

    /// A name with a trailing number and a plural s taken off: "Socks 2" → "sock".
    static func stem(_ s: String) -> String {
        var n = folded(s)
        while let c = n.last, c.isNumber || c == " " { n.removeLast() }
        if n.count > 2, n.hasSuffix("s") { n.removeLast() }
        return n
    }

    /// The words of a name, each stemmed: "Change shirt / t-shirt" → change, shirt, t.
    static func words(_ s: String) -> Set<String> {
        Set(folded(s).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.map(stem))
    }

    /// The things a pasted name means, most certain first: the same name (case and
    /// accents aside); else the same but for a trailing number or plural s; else every
    /// thing whose name holds all its words ("T-shirts" → "Change shirt / t-shirt").
    static func matches(_ name: String, in things: [Item]) -> [Item] {
        let f = folded(name), s = stem(name), w = words(name)
        let same = things.filter { folded($0.name) == f }
        if !same.isEmpty { return same }
        let near = things.filter { stem($0.name) == s }
        if !near.isEmpty { return near }
        guard !w.isEmpty else { return [] }
        return things.filter { w.isSubset(of: words($0.name)) }
    }

    /// A kit his paste asks for: a line with lines indented under it.
    public struct PastedKit: Equatable, Sendable {
        /// Its name as pasted.
        public var name: String
        /// The thing that is the kit, if he has one of that name; nil = made new.
        public var thingId: String?
        /// The kit's row on the big template, if it has one (ticked for the core).
        public var rowId: String?
        /// The things that go in, by id.
        public var inside: [String]
    }

    /// A thing his paste puts in a kit while it sits in another kit (or under two
    /// kits in the paste): not moved — "Make a second one" can be asked instead.
    public struct KitClash: Equatable, Sendable, Identifiable {
        public var id: String { thingId + ">" + wantedKit }
        public var thingId: String
        public var thingName: String
        /// The kit it is in now.
        public var inKit: String
        /// The kit the paste wanted it in (its name as pasted).
        public var wantedKit: String
        /// "Power bank is already in Cable pouch — a thing sits in one kit only".
        public var words: String { "\(thingName) is already in \(inKit) \u{2014} a thing sits in one kit only" }
    }

    /// What a pasted list WOULD do — shown before anything changes; "Make the small
    /// core" carries it out (`makeSmallCore`).
    public struct PastePlan: Equatable, Sendable {
        /// The big template's rows to tick (its things named at the left).
        public var ticked: Set<String> = []
        public var kits: [PastedKit] = []
        public var clashes: [KitClash] = []
        /// Names that found one thing or more.
        public var found = 0
        /// Names that found nothing — listed, never added.
        public var notFound: [String] = []
        /// "matched 3 things for shirt": a name that found several (all ticked).
        public var several: [String] = []
        /// Things that cannot go in a kit at all (a bag, a kit itself), in his words.
        public var refused: [String] = []

        public init() {}

        /// "16 found · 2 not found: Hammock, Kayak" — and what else he should know.
        public var words: String {
            var parts = ["\(found) found"]
            if !notFound.isEmpty { parts.append("\(notFound.count) not found: " + notFound.joined(separator: ", ")) }
            parts += several
            for k in kits { parts.append("\(k.name): a kit of \(k.inside.count)" + (k.thingId == nil ? " (new)" : "")) }
            parts += refused
            return parts.joined(separator: " \u{00B7} ")
        }
    }

    /// Read his pasted list against a template: what it ticks, the kits it makes and
    /// what they hold, and what it cannot do. Changes nothing.
    public func planPaste(_ text: String, templateId: String) -> PastePlan {
        var plan = PastePlan()
        let rows = smallCoreRows(templateId: templateId)
        let idx = kitIndex()
        let bagIds = Set(bags().compactMap { $0.itemId ?? $0.id })
        let things = items.filter { !Library.isReminder($0) && !bagIds.contains($0.id) }
        let lines = Library.pastedLines(text)
        var seenMissing = Set<String>()
        var claimed: [String: String] = [:]          // thing id → the kit (pasted name) that took it
        func missing(_ name: String) {
            if seenMissing.insert(Library.folded(name)).inserted { plan.notFound.append(name) }
        }
        func several(_ name: String, _ n: Int) { if n > 1 { plan.several.append("matched \(n) things for \(name)") } }
        var i = 0
        while i < lines.count {
            let line = lines[i]
            var children: [String] = []
            var j = i + 1
            while j < lines.count, lines[j].depth == 1 { children += lines[j].names; j += 1 }
            if children.isEmpty || line.names.count != 1 {
                // Plain names: the big template's rows they mean are ticked.
                for name in line.names {
                    let hits = Library.matches(name, in: rows)
                    if hits.isEmpty { missing(name); continue }
                    plan.found += 1
                    several(name, hits.count)
                    for h in hits { if let m = h.memId { plan.ticked.insert(m) } }
                }
                // (Several names on a line with lines under it: those lines are names too.)
                if !children.isEmpty {
                    for name in children {
                        let hits = Library.matches(name, in: rows)
                        if hits.isEmpty { missing(name); continue }
                        plan.found += 1
                        several(name, hits.count)
                        for h in hits { if let m = h.memId { plan.ticked.insert(m) } }
                    }
                }
                i = j
                continue
            }
            // A kit: the line, and the things under it.
            let name = line.names[0]
            let rowHits = rows.filter { Library.folded($0.name) == Library.folded(name) || Library.stem($0.name) == Library.stem(name) }
            let thingHit = rowHits.first.flatMap { r in items.first { $0.id == r.itemId } }
                ?? things.first { Library.folded($0.name) == Library.folded(name) }
                ?? things.first { Library.stem($0.name) == Library.stem(name) }
            var kit = PastedKit(name: thingHit?.name ?? name, thingId: thingHit?.id, rowId: rowHits.first?.memId, inside: [])
            plan.found += 1
            for child in children {
                let hits = Library.matches(child, in: things).filter { $0.id != kit.thingId }
                if hits.isEmpty { missing(child); continue }
                plan.found += 1
                several(child, hits.count)
                for h in hits {
                    if kit.inside.contains(h.id) { continue }
                    if let holder = idx.holder[h.id], holder != kit.thingId {
                        let inKit = items.first { $0.id == holder }?.name ?? ""
                        plan.clashes.append(KitClash(thingId: h.id, thingName: h.name, inKit: inKit, wantedKit: kit.name))
                        continue
                    }
                    if let first = claimed[h.id] {
                        plan.clashes.append(KitClash(thingId: h.id, thingName: h.name, inKit: first, wantedKit: kit.name))
                        continue
                    }
                    if idx.isKit(h.id) { plan.refused.append("\(h.name) holds things itself: a kit cannot go inside another kit"); continue }
                    claimed[h.id] = kit.name
                    kit.inside.append(h.id)
                }
            }
            if let k = kit.thingId, idx.holder[k] != nil {
                plan.refused.append("\(kit.name) is inside another kit: a kit cannot go inside another kit")
            } else {
                plan.kits.append(kit)
            }
            i = j
        }
        return plan
    }

    /// A thing's name not taken yet: "Power bank 2", "Power bank 3"…
    func freeThingName(_ name: String) -> String {
        var n = 2
        while items.contains(where: { normName($0.name) == normName("\(name) \(n)") }) { n += 1 }
        return "\(name) \(n)"
    }

    // MARK: - Making it

    /// What is still missing before the small core can be made — nil when nothing.
    public func smallCoreProblem(templateId: String, name: String, ticked: Set<String>, kits: Int = 0) -> String? {
        let wanted = jsTrim(name)
        if wanted.isEmpty { return "Give the small core a name." }
        if templateNameTaken(wanted) { return "You already have a template called that." }
        let rows = Set(smallCoreRows(templateId: templateId).compactMap(\.memId))
        if rows.intersection(ticked).isEmpty && kits == 0 { return "Tick at least one thing for the small core." }
        return nil
    }

    /// Make the small core: a new always-packed template of the ticked rows (each
    /// with its own answers, under the same headings), and the big template moved to
    /// `bigArea` (GA, WET, OE or "" = none) with all its rows. With a pasted plan, its
    /// kits are made and filled first and each kit is on the core; `seconds` are the
    /// clashes he answered with "Make a second one". nil, and nothing changed, when
    /// the template is not always packed, the area is not one of his, or
    /// `smallCoreProblem` has something to say.
    @discardableResult
    public mutating func makeSmallCore(from templateId: String, name: String, ticked: Set<String>,
                                       bigArea: String, plan: PastePlan? = nil, seconds: Set<String> = []) -> PackList? {
        let kits = plan?.kits ?? []
        guard let big = templates.first(where: { $0.id == templateId }), big.role == Library.ALWAYS_PACKED_AREA,
              bigArea.isEmpty || GROUP_IDS.contains(bigArea),
              smallCoreProblem(templateId: templateId, name: name, ticked: ticked,
                               kits: kits.filter { !$0.inside.isEmpty || $0.thingId != nil }.count) == nil else { return nil }
        let bigRows = smallCoreRows(templateId: templateId)
        var ticked = ticked

        // 1. The kits: made where he has no thing of that name, then filled.
        var kitRows: [(kitId: String, section: String)] = []
        for k in kits {
            var kitId = k.thingId
            let twins = (plan?.clashes ?? []).filter { $0.wantedKit == k.name && seconds.contains($0.id) }
            // A kit that would hold nothing (all it named sits in other kits) is not made.
            if k.inside.isEmpty && twins.isEmpty && kitId == nil { continue }
            var inside = k.inside
            // "Make a second one": a copy with the same details, in THIS kit.
            for c in twins {
                guard let orig = items.first(where: { $0.id == c.thingId }) else { continue }
                var twin = orig
                twin.id = PackingEnv.makeId()
                twin.name = freeThingName(orig.name)
                twin.extra[KIT_CONTENTS_KEY] = nil; twin.extra[KIT_OUT_KEY] = nil; twin.extra[KIT_CHECK_KEY] = nil
                items.append(twin)
                inside.append(twin.id)
            }
            if kitId == nil {
                let held = items.filter { inside.contains($0.id) }
                var counts: [String: Int] = [:]
                for t in held where !t.category.isEmpty { counts[t.category, default: 0] += 1 }
                // The most common kind inside (the first met, on a tie); no bag of its own.
                let kind = held.map(\.category).first { counts[$0] == counts.values.max() } ?? ""
                if let made = addThing(name: k.name) {
                    kitId = made.id
                    _ = updateThing(id: made.id) { $0.category = kind.isEmpty ? $0.category : kind; $0.container = "" }
                } else {
                    kitId = items.first { normName($0.name) == normName(k.name) }?.id
                }
            }
            guard let kid = kitId else { continue }
            let now = kitContents(kitId: kid)
            setKit(kitId: kid, contents: now.map(\.thing.id) + inside.filter { id in !now.contains { $0.thing.id == id } },
                   takenOut: Set(now.filter(\.takenOut).map(\.thing.id)),
                   check: items.first { $0.id == kid }.map(Library.kitCheck) ?? false)
            if let row = k.rowId { ticked.insert(row); continue }
            // Under the heading of the first thing inside it that the big template holds.
            let section = bigRows.first { r in inside.contains(r.itemId ?? "") }?.section ?? ""
            kitRows.append((kid, section))
        }

        // 2. The core itself: its headings are the big one's that hold a ticked row.
        let rows = bigRows.filter { ticked.contains($0.memId ?? "") }
        let wanted = Set(rows.compactMap(\.memId))
        var sectionIds: [String: String] = [:]
        var sections: [TemplateSection] = []
        let used = Set(rows.map(\.section) + kitRows.map(\.section))
        for s in big.sections where used.contains(s.id) {
            let copy = TemplateSection(name: s.name)
            sectionIds[s.id] = copy.id
            sections.append(copy)
        }
        var core = newList(name: jsTrim(name), sections: sections, role: Library.ALWAYS_PACKED_AREA)
        core.defaultContainer = big.defaultContainer
        core = coerceList(core)
        core.updatedAt = nowISO()
        templates.append(core)
        // The same rows, each with every answer of its own; only its template and
        // (copied) heading are new.
        var order = 0.0
        for m in memberships where m.templateId == templateId && wanted.contains(m.id) {
            var copy = m
            copy.id = PackingEnv.makeId()
            copy.templateId = core.id
            copy.section = sectionIds[m.section] ?? ""
            memberships.append(copy)
            order = max(order, m.order)
        }
        // A kit he had no row for: a row of its own, at the end.
        for (kid, section) in kitRows where !memberships.contains(where: { $0.templateId == core.id && $0.itemId == kid }) {
            order += 1
            var m = newMembership(itemId: kid, templateId: core.id)
            m.section = sectionIds[section] ?? ""
            m.order = order
            memberships.append(m)
        }
        _ = setTemplateArea(id: templateId, area: bigArea)
        return core
    }
}
