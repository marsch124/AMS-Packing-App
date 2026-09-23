import Foundation
import PackingCore

// More grab lists than Home can hold.
//
// Home has SIX slots — six big targets he can hit with his glasses off, which is
// the whole point of the thing. So the lists themselves are unlimited: the six he
// keeps on Home are his choice, in his order, and everything else waits on the
// shelf with all its things. Nothing is ever deleted by making room.
//
// The original six keep their ids and their storage (the `grab` rows the web app
// reads). His own lists live in the library's own `meta` — a new shared-row kind
// does not survive PackingCore, which keeps only the kinds the web app knows.

public let GRAB_OWN_META = "grabOwnLists"
public let GRAB_HOME_META = "grabHome"
/// How many fit on Home.
public let GRAB_HOME_SLOTS = 6

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

    /// The six on Home, in his order. Anything he has not chosen falls back to the
    /// original six, so a library that has never been arranged looks as it always did.
    public func homeGrabLists() -> [GrabDefinition] {
        let all = allGrabLists()
        let chosen = (meta[GRAB_HOME_META]?.arrayValue ?? []).compactMap { $0.stringValue }
        guard !chosen.isEmpty else { return Array(all.prefix(GRAB_HOME_SLOTS)) }
        let byId = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return chosen.compactMap { byId[$0] }.prefix(GRAB_HOME_SLOTS).map { $0 }
    }

    /// The ones waiting: everything that is not on Home, with all their things.
    public func shelvedGrabLists() -> [GrabDefinition] {
        let onHome = Set(homeGrabLists().map(\.id))
        return allGrabLists().filter { !onHome.contains($0.id) }
    }

    /// Put these lists on Home, in this order. More than six is refused rather
    /// than silently trimmed — Home holds six, and he chooses which.
    @discardableResult
    public mutating func setHomeGrabLists(_ ids: [String]) -> Bool {
        let known = Set(allGrabLists().map(\.id))
        var seen = Set<String>()
        let clean = ids.filter { known.contains($0) && seen.insert($0).inserted }
        guard clean.count <= GRAB_HOME_SLOTS else { return false }
        meta[GRAB_HOME_META] = JSONValue(clean)
        return true
    }

    /// A new list of his own. It goes on the shelf, not on Home: Home is full
    /// until he says what steps back.
    @discardableResult
    public mutating func addGrabList(label: String, title: String = "", tone: String = "blue",
                                     icon: String = "", items: [String] = []) -> GrabDefinition? {
        let name = jsTrim(label)
        guard !name.isEmpty else { return nil }
        let id = "own-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 100...999))"
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
