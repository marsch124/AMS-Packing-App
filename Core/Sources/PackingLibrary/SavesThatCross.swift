import Foundation
import PackingCore

// Warn instead of merge (0.102 — his decision of 26 Oct 2026, option B of spec 01 Open question 32).
//
// Some of the library is kept as ONE value in ONE record, and iCloud keeps the last whole version
// sent: a grab list's lines and "1 in 10" marks (an original list's `grab` row; ALL his own lists
// share one `meta` record), a template's head (its name, cover, sections…), what a kit holds (a field
// of the kit's own record), his own lists of Your choices, his kinds of thing. Two devices changing
// the same such block before either has seen the other's change: the device that sends last wins, and
// the other device's change is gone without a word.
//
// He chose to be TOLD rather than merged silently:
// 1. A page's Done (Save) that changed such a block, when the block changed here too since the page
//    opened — the other device's save arrived meanwhile — asks: Keep both (the 0.95/0.97 merge: what
//    each side added and took off) or Keep mine (the page's version of that block, whole). Asked only
//    when the two answers differ; nothing changed meanwhile = no question, saved as before.
// 2. A save that crossed — the other device's save of the same block arrives AFTER this device sent
//    its own, without what this device changed in it — is told once, quietly, in a note: the block's
//    name, "also changed on your iPhone — open it to check". Read from what this device saved in the
//    last minutes (`RecentSaves`), in memory: nothing new is stored, no CloudKit field.

/// A block of the library that iCloud keeps whole: one value in one record (above).
public enum Block: Hashable, Comparable, Sendable {
    /// A grab list: its lines (things and headings), its name and look, its "1 in 10" marks.
    case grabList(String)
    /// A template's head: everything of it but its rows — its name, cover, sections, area…
    case template(String)
    /// What a thing holds as a kit, and which of it is taken out (the thing's id).
    case kit(String)
    /// One of his lists in Your choices, by its kind: places, owners, people, conditions, phases.
    case choices(String)
    /// His kinds of thing.
    case kinds

    var sortKey: String {
        switch self {
        case .grabList(let id): return "1|" + id
        case .template(let id): return "2|" + id
        case .kit(let id): return "3|" + id
        case .choices(let kind): return "4|" + kind
        case .kinds: return "5|"
        }
    }
    public static func < (a: Block, b: Block) -> Bool { a.sortKey < b.sortKey }
}

extension Library {
    /// The block as this library holds it — nil when it is not there (a list or template deleted).
    /// The same value on every device that holds the same; a stamp (`updatedAt`) is no part of it,
    /// nor the order of "1 in 10" marks (a set of names).
    public func value(of block: Block) -> JSONValue? {
        switch block {
        case .grabList(let id):
            guard let list = grabList(id: id) else { return nil }
            let marks = sometimes(listId: id).map(jsTrim).sorted()
            return .object(["lines": JSONValue(GrabLine.stored(list.lines)), "label": .string(list.label),
                            "title": .string(list.title), "icon": .string(list.icon), "tone": .string(list.tone),
                            "marks": JSONValue(marks)])
        case .template(let id):
            guard let t = templates.first(where: { $0.id == id }), var o = t.json.objectValue else { return nil }
            o["items"] = nil
            o["updatedAt"] = nil
            return .object(o)
        case .kit(let id):
            guard let thing = items.first(where: { $0.id == id }) else { return nil }
            return .object(["contents": JSONValue(Library.listedContents(thing)),
                            "out": JSONValue(Library.kitIds(thing.extra[KIT_OUT_KEY]).sorted())])
        case .choices(let kind):
            if kind == "phases" { return .array((phases.isEmpty ? DEFAULT_PHASES : phases).map(\.json)) }
            return .array(Library.shownRows(shared, kind).map(\.json))
        case .kinds:
            return JSONValue(categories())
        }
    }

    /// A kind's rows as Your choices shows them: the factory list where none is stored, in order.
    static func shownRows(_ rows: [SharedRow], _ kind: String) -> [SharedRow] {
        var mine = rows.filter { $0.kind == kind }
        if mine.isEmpty {
            let def = defaultListFor(kind)
            mine = def.isEmpty ? [] : sharedRowsFrom(kind, json: .array(def))
        }
        return mine.stableSorted(compare: { a, b in jsOr(jsSign(a.order - b.order), jsLocaleCompare(a.id, b.id)) })
    }

    /// The blocks that differ between two libraries (`a` → `b`).
    public static func blocksChanged(_ a: Library, _ b: Library) -> Set<Block> {
        var out = Set<Block>()
        func check(_ block: Block) { if a.value(of: block) != b.value(of: block) { out.insert(block) } }
        if a.templates != b.templates {
            for id in Set(a.templates.map(\.id)).union(b.templates.map(\.id)) { check(.template(id)) }
        }
        if a.items != b.items {
            var before: [String: Item] = [:]
            for x in a.items { before[x.id] = x }
            for x in b.items where before[x.id] != x {
                if let was = before[x.id], was.extra[KIT_CONTENTS_KEY] == x.extra[KIT_CONTENTS_KEY],
                   was.extra[KIT_OUT_KEY] == x.extra[KIT_OUT_KEY] { continue }
                check(.kit(x.id))
            }
        }
        let grabMeta = [GRAB_OWN_META, GRAB_SOMETIMES_META]
        let grabRows = { (l: Library) in l.shared.filter { $0.kind == "grab" } }
        if grabRows(a) != grabRows(b) || grabMeta.contains(where: { a.meta[$0] != b.meta[$0] }) {
            for id in Set(a.allGrabLists().map(\.id)).union(b.allGrabLists().map(\.id)) { check(.grabList(id)) }
        }
        if a.shared != b.shared {
            let kinds = Set(a.shared.map(\.kind)).union(b.shared.map(\.kind)).subtracting(["grab"])
            for kind in kinds where a.shared.filter({ $0.kind == kind }) != b.shared.filter({ $0.kind == kind }) {
                check(.choices(kind))
            }
        }
        if a.phases != b.phases { check(.choices("phases")) }
        if a.meta[Library.categoriesKey] != b.meta[Library.categoriesKey] { check(.kinds) }
        return out
    }

    // MARK: - 1. At Done: a page's blocks the other device changed meanwhile

    /// The blocks a page changed on its copy (`opened` → `page`) that changed HERE too since it opened
    /// (this library, the real one, is not `opened` there) — and where the two answers differ: Keep
    /// both (`applyingPage`) does not give the page's version. Nothing changed meanwhile = none.
    public func crossings(opened: Library, page: Library) -> [Block] {
        guard opened != page, opened != self else { return [] }
        let mine = Library.blocksChanged(opened, page)
        guard !mine.isEmpty else { return [] }
        let both = mine.intersection(Library.blocksChanged(opened, self))
        guard !both.isEmpty else { return [] }
        let merged = applyingPage(from: opened, to: page)
        return both.filter { merged.value(of: $0) != page.value(of: $0) }.sorted()
    }

    /// Done with the answer: what the page changed put in (`applyingPage`), and for each block in
    /// `mine` (Keep mine) the page's own version of it, whole — the other device's change of that
    /// block is not kept. `mine` empty = Keep both, the merge alone.
    public func applyingPage(from: Library, to: Library, mine: Set<Block>) -> Library {
        var out = applyingPage(from: from, to: to)
        for block in mine.sorted() { out.put(block, from: to) }
        return out
    }

    /// `page`'s version of one block, whole, onto this library. A block gone here (deleted on the
    /// other device) stays gone, as the merge leaves it.
    public mutating func put(_ block: Block, from page: Library) {
        switch block {
        case .grabList(let id):
            if GRAB_FACTORY.contains(where: { $0.id == id }) {
                func ofList(_ r: SharedRow) -> Bool { r.kind == "grab" && grabFromRows([r]).first?.id == id }
                shared.removeAll(where: ofList)
                shared.append(contentsOf: page.shared.filter(ofList))
            } else {
                guard let own = page.ownGrabLists().first(where: { $0.id == id }),
                      ownGrabLists().contains(where: { $0.id == id }) else { return }
                _ = saveOwnGrabList(own)
            }
            var marks = sometimesByList()
            marks[id] = page.sometimesByList()[id]
            setSometimesByList(marks)
        case .template(let id):
            guard let n = templates.firstIndex(where: { $0.id == id }),
                  let mine = page.templates.first(where: { $0.id == id }), var o = mine.json.objectValue else { return }
            let here = templates[n]
            o["items"] = here.json["items"]
            o["updatedAt"] = .string(max(mine.updatedAt, here.updatedAt))
            templates[n] = PackList(json: .object(o))
        case .kit(let id):
            guard let mine = page.items.first(where: { $0.id == id }), items.contains(where: { $0.id == id }) else { return }
            _ = setKit(kitId: id, contents: Library.listedContents(mine),
                       takenOut: Set(Library.kitIds(mine.extra[KIT_OUT_KEY])))
        case .choices(let kind):
            if kind == "phases" { phases = page.phases; return }
            shared.removeAll { $0.kind == kind }
            shared.append(contentsOf: page.shared.filter { $0.kind == kind })
        case .kinds:
            meta[Library.categoriesKey] = page.meta[Library.categoriesKey]
        }
    }

    // MARK: - Words

    /// What the block is, as the question and the note say it: "Indoor swim's grab list",
    /// "The Hiking template", "What the First-aid kit holds", "Your storage places"…
    public func words(for block: Block) -> String {
        switch block {
        case .grabList(let id):
            return "\(grabList(id: id)?.title ?? "A")\u{2019}s grab list"
        case .template(let id):
            return "The \(templates.first { $0.id == id }?.name ?? "") template"
        case .kit(let id):
            return "What the \(items.first { $0.id == id }?.name ?? "kit") holds"
        case .choices(let kind):
            switch kind {
            case "places": return "Your storage places"
            case "owners": return "Your owners"
            case "people": return "Your packers"
            case "conditions": return "Your item conditions"
            case "phases": return "Your \u{201C}When\u{201D} steps"
            default: return "Your \(kind)"
            }
        case .kinds:
            return "Your kinds of thing"
        }
    }

    /// Several blocks in one line: "The Hiking template and your storage places".
    public func words(for blocks: [Block]) -> String {
        let all = blocks.enumerated().map { n, b -> String in
            let w = words(for: b)
            guard n > 0, let first = w.first else { return w }
            let rest = w.dropFirst()
            return (w.hasPrefix("The ") || w.hasPrefix("Your ") || w.hasPrefix("What ")) ? first.lowercased() + rest : w
        }
        switch all.count {
        case 0: return ""
        case 1: return all[0]
        default: return all.dropLast().joined(separator: ", ") + " and " + all[all.count - 1]
        }
    }

    /// The device the other changes come from, as the question and the note name it: "your iPhone"
    /// on the Mac, "your Mac" on the iPhone — once it has checked in here (Sync now, or by itself
    /// since 0.101); else "your other device".
    public func otherDevice(thisOne: String) -> String {
        let other = thisOne == "Mac" ? "iPhone" : "Mac"
        return lastCheckIn(device: other) != nil ? "your \(other)" : "your other device"
    }

    /// The question's title: "Changed on your iPhone meanwhile".
    public func crossedTitle(thisDevice: String) -> String {
        "Changed on \(otherDevice(thisOne: thisDevice)) meanwhile"
    }

    /// The note of a save that crossed: "Indoor swim's grab list was also changed on your iPhone —
    /// open it to check."
    public func crossedNote(_ blocks: [Block], thisDevice: String) -> String {
        let one = blocks.count == 1
        return "\(words(for: blocks)) \(one ? "was" : "were") also changed on \(otherDevice(thisOne: thisDevice))"
            + " \u{2014} open \(one ? "it" : "them") to check."
    }
}

// MARK: - The grab list's editor and a kit's page (they save onto the list as it is, not a copy)

extension Library {
    /// The grab list's editor, at Save: do Keep both (`saveGrabEdit(id:opened:…)`, the merge) and Keep
    /// mine (the editor's list and marks, whole) give different lists? Only when the list or its marks
    /// changed here since Edit opened — the other device's save arrived meanwhile.
    public func grabEditCrosses(id: String, opened: [GrabLine], openedSometimes: [String],
                                lines: [GrabLine], sometimes: [String]) -> Bool {
        let marks = { (names: [String]) in Set(names.map(normName)) }
        guard GrabLine.cleaned(lines) != GrabLine.cleaned(opened) || marks(sometimes) != marks(openedSometimes) else {
            return false                                          // the editor changed nothing: nothing to choose
        }
        var both = self, mine = self
        guard both.saveGrabEdit(id: id, opened: opened, openedSometimes: openedSometimes, lines: lines, sometimes: sometimes),
              mine.saveGrabEdit(id: id, lines: lines, sometimes: sometimes) else { return false }
        return both.value(of: .grabList(id)) != mine.value(of: .grabList(id))
    }

    /// A kit's page (a thing's page), at Save: the same question for what the kit holds — the merge
    /// (`kitFromPage`) against the page's own contents.
    public func kitPageCrosses(kitId: String, opened: [String], openedOut: Set<String>,
                               contents: [String], out: Set<String>) -> Bool {
        guard contents != opened || out != openedOut else { return false }
        var both = self, mine = self
        let kept = kitFromPage(kitId: kitId, opened: opened, openedOut: openedOut, contents: contents, out: out)
        both.setKit(kitId: kitId, contents: kept.contents, takenOut: kept.out)
        mine.setKit(kitId: kitId, contents: contents, takenOut: out)
        return both.value(of: .kit(kitId)) != mine.value(of: .kit(kitId))
    }
}

// MARK: - 2. After Done: the other device's save of the same block arrived later

/// What this device saved of each block in the last minutes (0.102), in memory only: when the other
/// device's save of the same block arrives without what this device changed in it — the two saves
/// crossed, and iCloud kept the other one whole — it is told once (`arrived`).
public struct RecentSaves: Sendable {
    /// How long a save is watched: a crossing save arrives within seconds, or minutes when a device
    /// was asleep or off the network.
    public static let window: TimeInterval = 10 * 60

    struct Saved: Sendable {
        var was: JSONValue?
        var mine: JSONValue?
        var at: Date
    }
    private var saved: [Block: Saved] = [:]

    public init() {}

    /// The blocks being watched (for the tests).
    public var watching: [Block] { saved.keys.sorted() }

    /// A save of this device (`before` → `after`): every block it changed is watched. A block saved
    /// again keeps the value it had before the first of those saves.
    public mutating func note(before: Library, after: Library, at: Date = PackingEnv.now()) {
        for block in Library.blocksChanged(before, after) {
            let earlier = saved[block].flatMap { at.timeIntervalSince($0.at) <= RecentSaves.window ? $0 : nil }
            saved[block] = Saved(was: earlier.map(\.was) ?? before.value(of: block), mine: after.value(of: block), at: at)
        }
    }

    /// The library read again (the other device's changes arrived): the blocks a save of ours was
    /// written over in — what this device changed is no longer in them. Each is told once; a block
    /// that holds our change, or was deleted on purpose, is no longer watched.
    public mutating func arrived(_ lib: Library, now: Date = PackingEnv.now()) -> [Block] {
        var lost: [Block] = []
        for (block, s) in saved {
            if now.timeIntervalSince(s.at) > RecentSaves.window { saved[block] = nil; continue }
            let here = lib.value(of: block)
            guard here != s.mine else { continue }                           // still ours
            saved[block] = nil
            guard let here else { continue }                                 // deleted there on purpose
            guard let was = s.was else { continue }                          // made here: it is there
            if Library.mergeValue(here, was: was, now: s.mine) != here { lost.append(block) }
        }
        return lost.sorted()
    }

    /// Nothing watched any more (a restore replaced the library).
    public mutating func forget() { saved = [:] }
}
