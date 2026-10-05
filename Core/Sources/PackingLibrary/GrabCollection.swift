import Foundation
import PackingCore

// More grab lists than Home can hold.
//
// Home has EIGHT places (4 × 2 since 2 Oct 2026; six before). So the lists
// themselves are unlimited: the ones he keeps on Home are his choice, in his order,
// and everything else waits in Grab Lists (the screen behind Home's "Grab Lists"
// door) with all its things. Nothing is ever deleted by making room. (Called "the
// shelf" until the field test of Oct 2026.)
//
// A list he sends to wait STAYS waiting until he puts it back (4 Oct 2026). Home
// used to fill every free place from the waiting lists, so "Off Home" put the very
// list he had taken off straight back at the end — the button seemed to do
// nothing. Now his arrangement remembers what it left out (`grabOff`), and only a
// list that is NEW since he last arranged Home — made here, made on the other
// device, received as a link — takes a free place by itself.
//
// The original six keep their ids and their storage (the `grab` rows the web app
// reads). His own lists live in the library's own `meta` — a new shared-row kind
// does not survive PackingCore, which keeps only the kinds the web app knows.

public let GRAB_OWN_META = "grabOwnLists"
public let GRAB_HOME_META = "grabHome"
/// The lists he left off Home when he last arranged it: they wait until he puts
/// them back, and a free place on Home never pulls one of them in.
public let GRAB_OFF_META = "grabOff"
/// How many fit on Home.
public let GRAB_HOME_SLOTS = 8          // 4 × 2 since 2 Oct 2026, his ask: "I need four of them × 2 rows" (was 6)

extension Library {
    /// Every grab list there is: the original six, then his own, in the order he
    /// made them.
    public func allGrabLists() -> [GrabDefinition] {
        grabLists() + ownGrabLists()
    }

    /// The ones he made himself.
    public func ownGrabLists() -> [GrabDefinition] {
        (meta[GRAB_OWN_META]?.arrayValue ?? []).compactMap { one in
            guard let id = one["id"]?.stringValue, !id.isEmpty else { return nil }
            return GrabDefinition(id: id,
                                  label: one["label"]?.stringValue ?? "",
                                  title: one["title"]?.stringValue ?? "",
                                  tone: one["tone"]?.stringValue ?? "blue",
                                  icon: one["icon"]?.stringValue ?? "",
                                  items: (one["items"]?.arrayValue ?? []).compactMap { $0.stringValue })
        }
    }

    /// The ones on Home (up to eight), in his order. A library that has never been
    /// arranged shows the first eight, so it looks as it always did.
    public func homeGrabLists() -> [GrabDefinition] {
        let all = allGrabLists()
        let chosen = (meta[GRAB_HOME_META]?.arrayValue ?? []).compactMap { $0.stringValue }
        let off = Set(offHomeIds())
        let byId = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var home = Array(chosen.compactMap { byId[$0] }.prefix(GRAB_HOME_SLOTS))
        // A free place takes a list he has not yet placed: a new one, in waiting
        // order (and, when Home grew from 6 to 8 on 2 Oct 2026, his arranged six
        // were joined by the next two). NEVER one he sent to wait — that is the
        // "Off Home" that did nothing until 4 Oct 2026.
        for d in all where home.count < GRAB_HOME_SLOTS && !off.contains(d.id) && !home.contains(where: { $0.id == d.id }) {
            home.append(d)
        }
        return home
    }

    /// The ids he left off Home when he last arranged it.
    public func offHomeIds() -> [String] {
        (meta[GRAB_OFF_META]?.arrayValue ?? []).compactMap { $0.stringValue }
    }

    private mutating func writeOff(_ ids: [String]) {
        if ids.isEmpty { meta[GRAB_OFF_META] = nil } else { meta[GRAB_OFF_META] = JSONValue(ids) }
    }

    /// The ones waiting: everything that is not on Home, with all their things.
    public func waitingGrabLists() -> [GrabDefinition] {
        let onHome = Set(homeGrabLists().map(\.id))
        return allGrabLists().filter { !onHome.contains($0.id) }
    }

    /// Put these lists on Home, in this order — and ONLY these: every other list
    /// there is waits in Grab Lists until he puts it on Home himself (taken off,
    /// stepped back for another, or simply not chosen). More than eight is refused
    /// rather than silently trimmed — Home holds eight, and he chooses which.
    @discardableResult
    public mutating func setHomeGrabLists(_ ids: [String]) -> Bool {
        let all = allGrabLists().map(\.id)
        let known = Set(all)
        var seen = Set<String>()
        let clean = ids.filter { known.contains($0) && seen.insert($0).inserted }
        guard clean.count <= GRAB_HOME_SLOTS else { return false }
        meta[GRAB_HOME_META] = JSONValue(clean)
        writeOff(all.filter { !seen.contains($0) })
        return true
    }

    /// Is this name taken already — by any grab list's word on its tile or its title,
    /// ignoring case and spaces? Make refuses a second list of the same name: two
    /// tiles saying the same thing cannot be told apart (5 Oct 2026). A list received by sharing is not refused; it is his to rename.
    public func grabListNameTaken(_ name: String) -> Bool {
        let key = normName(name)
        guard !key.isEmpty else { return false }
        return allGrabLists().contains { normName($0.label) == key || normName($0.title) == key }
    }

    /// A new list of his own. It takes a free place on Home if there is one (it
    /// is new: he has not sent it anywhere yet); when Home is full it waits in Grab
    /// Lists until he says what steps back.
    @discardableResult
    public mutating func addGrabList(label: String, title: String = "", tone: String = "blue",
                                     icon: String = "", items: [String] = []) -> GrabDefinition? {
        let name = jsTrim(label)
        guard !name.isEmpty else { return nil }
        // The app's own id maker, as everywhere else — the clock and dice went straight
        // to Date() and Int.random, so no model test could pin a new list's id (the
        // spec pass, 2026-10-05). Lists made before keep their "own-<ms>-<nnn>" ids.
        let id = "own-" + PackingEnv.makeId()
        let made = GrabDefinition(id: id, label: name, title: jsTrim(title).isEmpty ? name : jsTrim(title),
                                  tone: tone, icon: icon, items: items.map(jsTrim).filter { !$0.isEmpty })
        var all = ownGrabLists()
        all.append(made)
        writeOwn(all)
        return made
    }

    /// Change one of his own lists (the original six are changed through
    /// `saveGrabList`, which writes the row the web app reads).
    @discardableResult
    public mutating func saveOwnGrabList(_ list: GrabDefinition) -> Bool {
        var all = ownGrabLists()
        guard let n = all.firstIndex(where: { $0.id == list.id }) else { return false }
        var clean = list
        clean.label = jsTrim(list.label)
        guard !clean.label.isEmpty else { return false }
        var seen = Set<String>()
        clean.items = list.items.map(jsTrim).filter { !$0.isEmpty && seen.insert(normName($0)).inserted }
        all[n] = clean
        writeOwn(all)
        return true
    }

    /// Remove one of his own lists for good — the one place a grab list IS
    /// deleted, and only because he asked for that list to go.
    @discardableResult
    public mutating func deleteOwnGrabList(id: String) -> Bool {
        var all = ownGrabLists()
        guard all.contains(where: { $0.id == id }) else { return false }
        all.removeAll { $0.id == id }
        writeOwn(all)
        let onHome = (meta[GRAB_HOME_META]?.arrayValue ?? []).compactMap { $0.stringValue }.filter { $0 != id }
        if !onHome.isEmpty { meta[GRAB_HOME_META] = JSONValue(onHome) }
        // …and from the lists he sent off Home: nothing is left behind of it, in the
        // library or in a backup made afterwards (it stayed there, unread, until 5 Oct 2026).
        writeOff(offHomeIds().filter { $0 != id })
        var marks = sometimesByList()
        marks[id] = nil
        setSometimesByList(marks)
        return true
    }

    private mutating func writeOwn(_ lists: [GrabDefinition]) {
        guard !lists.isEmpty else { meta[GRAB_OWN_META] = nil; return }
        meta[GRAB_OWN_META] = .array(lists.map { list in
            ["id": .string(list.id), "label": .string(list.label), "title": .string(list.title),
             "tone": .string(list.tone), "icon": .string(list.icon), "items": JSONValue(list.items)]
        })
    }
}
