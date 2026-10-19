import Foundation
import PackingCore

// His own activity areas (0.89). His words, 18 Oct 2026: "I would like the ability to add and
// adjust activity areas so that I can organize templates."
//
// Until now an area was one of three codes fixed in the web app's model (`GROUPS`: GA · Goal
// Activity, WET · Workout, Exercise & Training, OE · Other Events), stored in a template's
// `group`. They are his list now, managed as his other lists are (Your choices, a drop-down's
// tools): a pen renames one, the grip ≡ (on the Mac the arrows) moves it, + makes a new one,
// Remove asks — or, while a template is in it, says which and keeps it.
//
// WHERE IT IS KEPT — decided so the web app's model never sees anything new (parity 211/211):
// - The list: ONE `meta` record, "activityAreas" — `[{id, name}]` in his order — the way his
//   kinds of thing are kept (0.69): a record of its own, so it syncs; in a backup under
//   `prefs.activityAreas`, back with an import and a restore. Stored only while it differs from
//   the three the app ships with (never seeded: no record = the three, in the code).
//   Not shared rows: a NEW shared-row kind is blanked by PackingCore (`coerceSharedRow`).
//   One record = the later of two offline edits of the LIST wins, as for his kinds of thing.
// - Which area a template is in: a built-in area stays the template's `group` ("GA", "WET",
//   "OE") — exactly what the web app and PackingCore read (Context per workout reads "WET").
//   One of his own goes in the template's `extra["area"]` (its id) with `group` "" — `coerceList`
//   would blank any other `group`. The web app shows such a template under its "Other lists".
//
// THE BUILT-INS keep their ids and their roles. Renamed, they show his name alone; under their
// own name they show their code as before ("GA · Goal Activity"). GA and OE can be removed once
// no template is in them; WET never — it is the workout area (each workout's own Context on a
// trip, the workout colours on Create new trip). A template whose area is gone (removed on the
// other device while this one moved a template in) falls under Other Templates, never lost.

/// One activity area of his: a built-in (`id` "GA", "WET", "OE") or one he made
/// (`id` "area-" + a new id). `name` is his words for it.
public struct ActivityArea: Equatable, Hashable, Sendable {
    public var id: String
    public var name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

extension Library {
    /// The `meta` key (and the backup's `prefs` key) his activity areas are kept under.
    public static let areasKey = "activityAreas"
    /// The template `extra` key that names one of HIS areas (a built-in is the `group`).
    public static let areaKey = "area"
    /// The workout area: never removed (each workout's own Context on a trip reads it).
    public static let workoutArea = "WET"
    /// The heading of the templates in no area of his.
    public static let otherTemplates = "Other Templates"
    /// The longest name an area keeps (UTF-16 units), as a "When" step's.
    static let areaNameMax = 60

    /// The three the app ships with, under their own names.
    public static var factoryAreas: [ActivityArea] { GROUPS.map { ActivityArea(id: $0.id, name: $0.label) } }

    /// A built-in area (one of the web app's codes)?
    public static func isBuiltInArea(_ id: String) -> Bool { GROUP_IDS.contains(id) }

    /// His activity areas, in his order. With no list of his: the three the app ships with.
    /// Rows without an id or a name and a repeated id are skipped; the workout area is always
    /// there (last, should a list ever come without it).
    public func activityAreas() -> [ActivityArea] {
        guard let stored = meta[Library.areasKey]?.arrayValue else { return Library.factoryAreas }
        let read = Library.cleanAreas(stored.map { v in
            ActivityArea(id: v["id"]?.stringValue ?? "", name: v["name"]?.stringValue ?? "")
        })
        return read.isEmpty ? Library.factoryAreas : read
    }

    /// Trimmed, cut, each id once, the workout area kept.
    static func cleanAreas(_ list: [ActivityArea]) -> [ActivityArea] {
        var seen = Set<String>()
        var out: [ActivityArea] = []
        for a in list {
            let id = jsTrim(a.id), name = jsSlice(jsTrim(a.name), 0, areaNameMax)
            guard !id.isEmpty, !name.isEmpty, seen.insert(id).inserted else { continue }
            out.append(ActivityArea(id: id, name: name))
        }
        if !out.isEmpty, !seen.contains(workoutArea), let wet = factoryAreas.first(where: { $0.id == workoutArea }) {
            out.append(wet)
        }
        return out
    }

    /// Writes his list. Stored only while it differs from the three the app ships with.
    @discardableResult
    public mutating func setActivityAreas(_ list: [ActivityArea]) -> Bool {
        let clean = Library.cleanAreas(list)
        meta[Library.areasKey] = clean.isEmpty || clean == Library.factoryAreas
            ? nil : .array(clean.map { ["id": .string($0.id), "name": .string($0.name)] })
        return true
    }

    /// How an area reads as a heading and in a list: a built-in under its own name with its
    /// code first ("GA · Goal Activity", as before 0.89); renamed, or one of his, his words.
    public static func areaWords(_ area: ActivityArea) -> String {
        if let g = group(area.id), g.label == area.name { return "\(g.id) \u{00B7} \(area.name)" }
        return area.name
    }

    /// The heading of area `id` ("" or one that is not his: Other Templates).
    public func areaTitle(_ id: String) -> String {
        activityAreas().first { $0.id == id }.map(Library.areaWords) ?? Library.otherTemplates
    }

    /// The area a template is in — one of his areas' ids, or "" (Other Templates). Always
    /// packed and transport templates are filed by what they do: "". A built-in `group` wins
    /// while that area is his (it is what PackingCore and the web app read); else his own area
    /// named in `extra["area"]`, while it exists; else none.
    public func areaOf(_ list: PackList) -> String {
        areaOf(list, among: Set(activityAreas().map(\.id)))
    }

    func areaOf(_ list: PackList, among live: Set<String>) -> String {
        guard list.role.isEmpty else { return "" }
        if !list.group.isEmpty, live.contains(list.group) { return list.group }
        if let own = list.extra[Library.areaKey]?.stringValue, !own.isEmpty,
           !Library.isBuiltInArea(own), live.contains(own) { return own }
        return ""
    }

    /// The activity templates of `lists` by area: his areas in his order, each with its
    /// templates (Swim/Bike/Run order in the workout area — `orderActivities`), empty ones
    /// left out, then those in none under `Library.otherTemplates` (area id "").
    public func listsByArea(_ lists: [PackList]) -> [(area: ActivityArea, lists: [PackList])] {
        let areas = activityAreas()
        let live = Set(areas.map(\.id))
        var buckets: [String: [PackList]] = [:]
        for l in lists where l.role.isEmpty { buckets[areaOf(l, among: live), default: []].append(l) }
        var out: [(area: ActivityArea, lists: [PackList])] = areas.compactMap { a in
            let mine = orderActivities(a.id, buckets[a.id] ?? [])
            return mine.isEmpty ? nil : (a, mine)
        }
        if let rest = buckets[""], !rest.isEmpty { out.append((ActivityArea(id: "", name: Library.otherTemplates), rest)) }
        return out
    }

    /// The templates in area `id`, by name (A–Z) — what a refusal names.
    public func templatesIn(area id: String) -> [PackList] {
        let live = Set(activityAreas().map(\.id))
        return templates.filter { areaOf($0, among: live) == id }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name) })
    }

    /// A template filed in `area` (an area id, or "" for none) — a built-in in its `group`,
    /// one of his in `extra["area"]`. Role and everything else as they are.
    public static func filed(_ list: PackList, in area: String) -> PackList {
        var l = list
        l.group = isBuiltInArea(area) ? area : ""
        if !area.isEmpty && !isBuiltInArea(area) { l.extra[areaKey] = .string(area) }
        else { l.extra.removeValue(forKey: areaKey) }
        return l
    }

    /// Why area `id` cannot be taken away — nil when it can. The workout area never goes;
    /// one with templates in it stays, and says which.
    public func areaRemoveProblem(_ id: String, label: String) -> String? {
        if id == Library.workoutArea {
            return "\(label) is where your workouts live \u{2014} each gets its own Context on a trip \u{2014} so it stays."
        }
        let names = templatesIn(area: id).map(\.name)
        guard !names.isEmpty else { return nil }
        let said: String
        switch names.count {
        case 1: said = names[0]
        case 2, 3: said = names.dropLast().joined(separator: ", ") + " and " + names.last!
        default: said = names.prefix(3).joined(separator: ", ") + " and \(names.count - 3) more"
        }
        let one = names.count == 1
        return "\(label) still holds \(said), so it stays. Move \(one ? "it" : "them") to another area on \(one ? "its" : "their") page first."
    }

    /// What is wrong with `name` for an area, beyond a name the list already has: one of the
    /// app's own headings would read as two of them.
    public static func areaNameReserved(_ name: String) -> String? {
        let k = normName(name)
        for heading in ["Always Packed", "By Transport", otherTemplates] where normName(heading) == k {
            return "\(heading) is a heading of its own on Templates. Pick another name."
        }
        return nil
    }

    // MARK: - The list's own writes (Your choices' kind "areas", ChoiceEdits.swift)

    /// A new area at the end of his list; answers its id. nil for a blank name or one he has.
    mutating func addArea(_ name: String) -> String? {
        let clean = jsSlice(jsTrim(name), 0, Library.areaNameMax)
        guard !clean.isEmpty, Library.areaNameReserved(clean) == nil,
              !activityAreas().contains(where: { Library.choiceKey($0.name) == Library.choiceKey(clean) }) else { return nil }
        let id = "area-" + PackingEnv.makeId()
        setActivityAreas(activityAreas() + [ActivityArea(id: id, name: clean)])
        return id
    }

    /// A new name for area `id` (its id stays, so every template in it follows).
    mutating func renameArea(_ id: String, to name: String) -> Bool {
        var list = activityAreas()
        guard let n = list.firstIndex(where: { $0.id == id }) else { return false }
        list[n].name = jsSlice(jsTrim(name), 0, Library.areaNameMax)
        return setActivityAreas(list)
    }

    /// Area `id` one place up (−1) or down (1).
    mutating func moveArea(_ id: String, by step: Int) -> Bool {
        var list = activityAreas()
        guard step == 1 || step == -1, let n = list.firstIndex(where: { $0.id == id }), list.indices.contains(n + step) else { return false }
        list.swapAt(n, n + step)
        return setActivityAreas(list)
    }

    /// Takes area `id` away (the caller has asked `areaRemoveProblem`).
    mutating func dropArea(_ id: String) {
        setActivityAreas(activityAreas().filter { $0.id != id })
    }
}
