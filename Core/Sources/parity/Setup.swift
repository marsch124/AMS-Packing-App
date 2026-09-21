// Setup — the backup, the frozen clock, the coerced inputs, the synthetic overlays
// and `ask` (QUESTIONS.md §1, §4, §5; §2–§7 of js-answers.mjs).

import Foundation
import PackingCore

struct ParityFailure: Error, CustomStringConvertible {
    let description: String
    init(_ text: String) { description = text }
}

final class Parity {
    let TODAY: String
    let NOW: String

    /// The parsed backup, as the file holds it (§4.1: nothing is stripped).
    let B: J
    let prefs: J
    let rawLists: [J], rawEvents: [J], rawActions: [J], rawKits: [J], rawThings: [J], rawPhases: [J]

    // §4.4 The Settings lists in force — raw JSON, as the JS holds them.
    let CONDITIONS_IN: [J]
    let PEOPLE_IN: [J]
    let PLACES_IN: [J]
    let OWNERS_IN: [J]
    let PEOPLE: [Person]
    let PEOPLE_NAMES: [String]

    // §4.5 Everything coerced once. Swift values are copies by nature, so every
    // question gets its own deep copy of these for free (D5).
    let LISTS: [PackList]
    let EVENTS: [TripEvent]
    let ACTIONS: [ActionItem]
    let KITS: [Kit]
    let THINGS: [Item]

    /// item id → k, in order of first appearance across LISTS (§5).
    private(set) var itemOrder: [String: Int] = [:]
    private(set) var itemOrderIds: [String] = []

    private(set) var answers: [String: [String: J]] = [:]
    private(set) var reservedKeysSeen = 0
    private(set) var unknownKeys: [String: Set<String>] = [
        "list": [], "item": [], "event": [], "entry": [], "action": [], "kit": [], "phase": [],
    ]

    init(backupPath: String, today: String) throws {
        let now = "\(today)T12:00:00.000Z"
        TODAY = today
        NOW = now

        // A frozen clock (D2) and ids that are never compared (D3) but must be unique.
        PackingEnv.freeze(at: now, idPrefix: "minted-")
        // A settled collation (D6).
        PackingEnv.collationLocale = Locale(identifier: "en_US")

        guard let data = FileManager.default.contents(atPath: backupPath) else {
            throw ParityFailure("cannot read \(backupPath)")
        }
        B = try JSONValue.parse(data)
        guard B.objectValue != nil, B["lists"]?.arrayValue != nil || B["events"]?.arrayValue != nil else {
            throw ParityFailure("That file does not look like an AMS Packing backup.")
        }
        prefs = (B["prefs"]?.objectValue != nil) ? (B["prefs"] ?? [:]) : [:]
        rawLists = asArr(B["lists"]); rawEvents = asArr(B["events"]); rawActions = asArr(B["actions"])
        rawKits = asArr(B["kits"]); rawThings = asArr(B["things"]); rawPhases = asArr(B["phases"])

        // 6.2 Phases first (applyBackup does the same), then the conditions from prefs.
        let incoming = rawPhases.enumerated().map { coercePhase(json: $0.element, $0.offset) }
            .filter { !$0.id.isEmpty && !$0.label.isEmpty }
        setPhases(incoming)
        if nonEmptyArr(prefs["conditions"]) { setItemConditions(json: prefs["conditions"]) } else { setItemConditions([]) }

        // 6.3 The Settings lists in force.
        CONDITIONS_IN = nonEmptyArr(prefs["conditions"]) ? asArr(prefs["conditions"]) : DEFAULT_ITEM_CONDITIONS.map { $0.json }
        PEOPLE_IN = nonEmptyArr(prefs["people"]) ? asArr(prefs["people"]) : defaultListFor("people")
        PLACES_IN = nonEmptyArr(prefs["storageLocations"]) ? asArr(prefs["storageLocations"]) : DEFAULT_STORAGE_LOCATIONS.map { .string($0) }
        OWNERS_IN = nonEmptyArr(prefs["owners"]) ? asArr(prefs["owners"]) : []
        PEOPLE = peopleFromRows(peopleToRows(json: .array(PEOPLE_IN)))
        PEOPLE_NAMES = PEOPLE.map { $0.name }

        // 6.4 Coerce everything once.
        LISTS = rawLists.compactMap { coerceList(json: $0) }
        EVENTS = rawEvents.compactMap { coerceEvent(json: $0) }
        ACTIONS = rawActions.compactMap { coerceAction(json: $0) }
        KITS = rawKits.compactMap { coerceKit(json: $0) }
        THINGS = rawThings.compactMap { coerceItem(json: $0) }
        guard LISTS.count == rawLists.count, EVENTS.count == rawEvents.count else {
            throw ParityFailure("A list or an event in the backup is not an object.")
        }

        for l in LISTS { for it in l.items where itemOrder[it.id] == nil { itemOrder[it.id] = itemOrderIds.count; itemOrderIds.append(it.id) } }
        noteKeys()
    }

    // Keys in the data that no shape carries — reported in _info, never compared.
    private func noteKeys() {
        let reserved = Set(SYNC_RESERVED_KEYS)
        func note(_ bucket: String, _ o: J?, _ known: Set<String>) {
            for k in (o?.objectValue ?? [:]).keys {
                if reserved.contains(k) { reservedKeysSeen += 1 } else if !known.contains(k) { unknownKeys[bucket, default: []].insert(k) }
            }
        }
        for l in rawLists { note("list", l, LIST_KEYS); for it in asArr(l["items"]) { note("item", it, ITEM_KEYS) } }
        for e in rawEvents { note("event", e, EVENT_KEYS); for it in asArr(e["entries"]) { note("entry", it, ITEM_KEYS) } }
        for a in rawActions { note("action", a, ACTION_KEYS) }
        for k in rawKits { note("kit", k, KIT_KEYS) }
        for p in rawPhases { note("phase", p, PHASE_KEYS) }
    }

    // MARK: - 6.5 The synthetic overlays (§5)
    // Real data as the base, deterministic changes on top, so questions the real
    // data leaves empty still have something to answer.

    func synthLists() -> [PackList] {
        var lists = LISTS
        for li in lists.indices {
            for ii in lists[li].items.indices {
                var it = lists[li].items[ii]
                let k = itemOrder[it.id] ?? 0
                if k % 5 == 0 { it.expiry = addDays(TODAY, (k % 120) - 40) }
                if k % 7 == 1 { it.condition = ITEM_CONDITION_IDS[k % ITEM_CONDITION_IDS.count] }
                else if k % 13 == 3 { it.condition = "mystery" }
                if k % 6 == 0 { it.consumable = true }
                if k % 17 == 5 { it.retired = true }
                if k % 8 == 2 {
                    it.maintenance = Maintenance(
                        notes: "Synthetic care note", link: "", intervalDays: [30, 90, 182, 365, 0][k % 5],
                        lastDone: (k % 3 == 0) ? "" : addDays(TODAY, -((k * 7) % 400)), log: [])
                }
                if k % 10 == 4 { it.stats = ItemStats(packed: k % 4, used: (k % 3 == 0) ? 0 : 1, unused: 0, skipped: k % 3, lastReviewed: "") }
                lists[li].items[ii] = it
            }
        }
        return lists
    }

    func synthEvent(_ ev: TripEvent) -> TripEvent {
        var e = ev
        for i in e.entries.indices {
            var x = e.entries[i]
            if i % 5 == 0 { x.expiry = addDays(TODAY, (i % 120) - 40) }
            if i % 4 == 1 && !PEOPLE_NAMES.isEmpty { x.packer = PEOPLE_NAMES[(i / 4) % PEOPLE_NAMES.count] }
            else if i % 11 == 2 { x.packer = "Zed Guest" }
            else if i % 11 == 6 { x.packer = "amy guest" }
            if i % 6 == 2 { x.kit = "Kit \(["A", "B", "C"][(i / 6) % 3])" }
            x.skipped = (i % 9 == 4)
            x.checked = (i % 2 == 0)
            x.used = (i % 3 != 0)
            e.entries[i] = x
        }
        return e
    }

    func synthActions() -> [ActionItem] {
        var byId: [String: Item] = [:]
        for l in LISTS { for it in l.items where byId[it.id] == nil { byId[it.id] = it } }
        return itemOrderIds.prefix(12).enumerated().compactMap { i, iid in
            let stamp = "\(addDays("2026-01-01", i % 7))T00:00:00.000Z"
            return coerceAction(json: obj([
                "id": .string("synth-action-\(i)"), "text": .string("Synthetic \(i)"),
                "kind": .string(i % 3 == 0 ? "shopping" : "todo"),
                "itemId": .string(iid), "itemName": .string(byId[iid]?.name ?? ""),
                "priority": .string(i % 2 == 0 ? "high" : "normal"),
                "whenPhase": .string(i % 4 == 1 ? (PHASE_IDS.isEmpty ? "" : PHASE_IDS[i % PHASE_IDS.count]) : (i % 4 == 2 ? "no-such-phase" : "")),
                "whenDate": .string(i % 4 == 0 ? addDays(TODAY, i) : ""),
                "done": .bool(i % 5 == 0), "doneAt": .string(i % 5 == 0 ? NOW : ""),
                "createdAt": .string(stamp), "updatedAt": .string(stamp),
            ]))
        }
    }

    // MARK: - 7. Asking

    /// One answer. `fn` returns the canonical value; nil is JS `undefined` (written
    /// `null`); a throw is answered `{"$error": message}` (D7).
    func ask(_ key: String, _ entity: String, _ fn: () throws -> J?) {
        let v: J
        do { v = try fn() ?? .null } catch { v = ["$error": .string(errorMessage(error))] }
        answers[key, default: [:]][entity] = v
    }
    func answer(_ key: String) -> [String: J]? { answers[key] }

    func listKey(_ l: PackList, _ i: Int) -> String { l.id.isEmpty ? "#\(i)" : l.id }
    func eventKey(_ e: TripEvent, _ i: Int) -> String { e.id.isEmpty ? "#\(i)" : e.id }
    func rawKey(_ raw: J, _ i: Int) -> String { let s = str(raw["id"]); return s.isEmpty ? "#\(i)" : s }

    // MARK: - 8. The document

    func document(poolCount: Int) -> String {
        var answerCount = 0, errors = 0
        var doc: [String: J] = [:]
        for (q, ents) in answers {
            answerCount += ents.count
            for v in ents.values where v["$error"] != nil { errors += 1 }
            doc[q] = .object(ents)
        }
        var unknown: [String: J] = [:]
        for (k, s) in unknownKeys { unknown[k] = jset(Array(s)) }
        let info: J = obj([
            "generator": "swift", "contract": 2, "today": .string(TODAY), "now": .string(NOW),
            "locale": .string(PackingEnv.collationLocale.identifier.replacingOccurrences(of: "_", with: "-")),
            "counts": obj([
                "lists": jint(LISTS.count), "items": jint(LISTS.reduce(0) { $0 + $1.items.count }),
                "distinctItems": jint(itemOrderIds.count),
                "events": jint(EVENTS.count), "entries": jint(EVENTS.reduce(0) { $0 + $1.entries.count }),
                "actions": jint(ACTIONS.count), "kits": jint(KITS.count), "things": jint(THINGS.count),
                "phases": jint(rawPhases.count), "strings": jint(poolCount),
            ]),
            "questions": jint(answers.count), "answers": jint(answerCount), "errors": jint(errors),
            "reservedKeysSeen": jint(reservedKeysSeen),
            "unknownKeys": .object(unknown),
        ])
        FileHandle.standardError.write(Data("parity: \(answers.count) questions, \(answerCount) answers, \(errors) errored, today \(TODAY), collation \(PackingEnv.collationLocale.identifier)\n".utf8))
        return CJ(["_info": info, "answers": .object(doc)]) + "\n"
    }
}
