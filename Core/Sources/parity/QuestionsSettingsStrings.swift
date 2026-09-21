// §12 The Settings lists and their shared rows · §13 Every real string, and every id

import Foundation
import PackingCore

let FIXED_STRINGS: [String] = [
    "", "  Mixed   CASE  ", "Sun-glasses", "sunglasses", "Sun glasses", "Glass", "Boss", "Socks", "ÅÄÖ åäö",
    "Tab\tand\nnewline", "e\u{0301} combining", "😀 emoji 👍🏽", "nbsp\u{00a0}\u{00a0}gap", "\u{feff}bom lead",
    "nel\u{0085}\u{0085}gap", "thin\u{2009}\u{2009}gap\u{2028}", "İstanbul ǅ ß", "½ litre №5",
]

extension Parity {

    // === §12 The Settings lists and their shared rows ========================
    func askSettings() {
        struct Grab { var id: String; var items: [J]; var label: String; var icon: String; var tone: String }
        let grabIn: [Grab] = {
            let g = prefs["grab"]?.objectValue != nil ? prefs["grab"] : nil
            let items = g?["items"]?.objectValue ?? [:]
            let meta = g?["meta"]?.objectValue ?? [:]
            return sortedByCodeUnit(distinct(Array(items.keys) + Array(meta.keys))).map { gid in
                Grab(id: gid, items: asArr(items[gid]), label: str(meta[gid]?["label"]), icon: str(meta[gid]?["icon"]),
                     tone: str(meta[gid]?["tone"]))
            }
        }()
        var presetsIn: [J] = nonEmptyArr(prefs["presets"]) ? asArr(prefs["presets"]) : []
        for (i, e) in EVENTS.enumerated() {
            presetsIn.append(obj(["name": .string("Preset \(i + 1)"), "createdAt": .string(e.createdAt),
                                  "config": presetConfigFromEvent(e).json]))
        }
        presetsIn.append(["name": "  preset 1 ", "createdAt": "", "config": ["mode": "quick"]])   // same name, other spelling: must be dropped
        presetsIn.append(["name": "No config"])                                                        // must be dropped
        let inputs: [String: J] = [
            "conditions": .array(CONDITIONS_IN), "people": .array(PEOPLE_IN), "places": .array(PLACES_IN),
            "owners": .array(OWNERS_IN), "presets": .array(presetsIn),
            "grab": .array(grabIn.map { obj(["id": .string($0.id), "items": .array($0.items), "label": .string($0.label),
                                             "icon": .string($0.icon), "tone": .string($0.tone)]) }),
        ]
        let allRows: () -> [SharedRow] = { SHARED_KINDS.flatMap { sharedRowsFrom($0, json: inputs[$0]) } }
        let reversedRows: () -> [SharedRow] = { allRows().reversed() }
        for kind in SHARED_KINDS {
            ask("settings.rows", kind) { .array(sharedRowsFrom(kind, json: inputs[kind]).map { shapeRow($0) }) }
            ask("settings.rowsOfKind", kind) { jstrings(sharedRowsOfKind(reversedRows(), kind).map { $0.id }) }
            ask("settings.isFactoryList", kind) {
                obj(["inForce": .bool(isFactoryList(kind, json: inputs[kind])), "factory": .bool(isFactoryList(kind, defaultListFor(kind))),
                     "defaultList": .array(defaultListFor(kind))])
            }
        }
        ask("settings.back", "conditions") { .array(conditionsFromRows(reversedRows()).map { shapeCondition($0) }) }
        ask("settings.back", "people") { .array(peopleFromRows(reversedRows()).map { shapePerson($0) }) }
        for kind in ["places", "owners"] {
            ask("settings.back", kind) {
                obj(["ordered": jstrings(orderedNamesFromRows(reversedRows(), kind)), "az": jstrings(namesFromRows(reversedRows(), kind))])
            }
        }
        ask("settings.back", "presets") { .array(presetsFromRows(reversedRows()).map { $0.json }) }
        ask("settings.back", "grab") { .array(grabFromRows(reversedRows()).map { $0.json }) }
        ask("settings.ownersByUsage", ALL) {
            var order: [String] = [], seen: [String: Set<String>] = [:], spelling: [String: String] = [:]
            for l in self.LISTS {
                for it in l.items {
                    let key = normName(it.ownedBy)
                    if key.isEmpty { continue }
                    if seen[key] == nil { order.append(key); seen[key] = []; spelling[key] = jsTrim(it.ownedBy) }
                    seen[key]?.insert((it.itemId ?? "").isEmpty ? it.id : (it.itemId ?? ""))
                }
            }
            var counts: [String: Int] = [:]
            for (k2, set) in seen { counts[k2] = set.count }
            let names = self.OWNERS_IN.isEmpty ? order.map { spelling[$0] ?? "" }
                                               : self.OWNERS_IN.map { $0.stringValue ?? str($0["name"]) }
            return obj(["counts": .object(counts.mapValues { jint($0) }), "order": jstrings(ownersByUsage(names, counts))])
        }
        for g in grabIn {
            ask("settings.grabShare", g.id) {
                let code = try encodeGrabShare(json: obj([
                    "name": .string(g.label.isEmpty ? g.id : g.label), "icon": .string(g.icon), "tone": .string(g.tone),
                    "items": .array(g.items),
                ]))
                return obj(["code": .string(code), "decoded": try decodeGrabShare("Try this: https://example.invalid/#/g/\(code).").json])
            }
        }
    }

    // === §13 Every real string, and every id ==================================
    /// POOL: FIXED plus every non-empty string of the data, distinct, by UTF-16 code unit.
    func stringPool() -> [String] {
        var pool = FIXED_STRINGS
        func add(_ v: String) { if !v.isEmpty { pool.append(v) } }
        func addItem(_ it: Item, section: Bool) {
            for v in [it.name, it.swedish, it.storage, it.ownedBy, it.packer, it.kit, it.container, it.category] { add(v) }
            if section { add(it.section) }
        }
        for l in LISTS { add(l.name); add(l.defaultContainer); for s in l.sections { add(s.name) }; for it in l.items { addItem(it, section: false) } }
        for e in EVENTS { add(e.name); add(e.destination); for it in e.entries { addItem(it, section: true) } }
        for a in ACTIONS { add(a.text); add(a.itemName) }
        for k in KITS { add(k.name) }
        for t in THINGS { add(t.name) }
        for v in PLACES_IN + OWNERS_IN { if let s = v.stringValue ?? v["name"]?.stringValue { add(s) } }
        for p in PEOPLE { add(p.name) }
        return sortedByCodeUnit(distinct(pool))
    }

    func askStrings(_ POOL: [String]) {
        for s in POOL {
            ask("strings.normName", s) { .string(normName(s)) }
            ask("strings.dupeKey", s) { .string(dupeKey(s)) }
        }
        ask("strings.collation", "variant") { jstrings(POOL.stableSorted(compare: { a, b in jsLocaleCompare(a, b) })) }
        ask("strings.collation", "base") { jstrings(POOL.stableSorted(compare: { a, b in jsLocaleCompare(a, b, sensitivity: .base) })) }
        // The same comparisons one pair at a time, so a collation difference points at the
        // two strings involved instead of shifting a thousand positions in the lists above.
        for (i, s) in POOL.enumerated() {
            ask("strings.compare", s) {
                .array([1, 37].map { step in
                    let other = POOL[(i + step) % POOL.count]
                    return obj(["with": .string(other), "variant": jint(jsLocaleCompare(s, other)),
                                "base": jint(jsLocaleCompare(s, other, sensitivity: .base))])
                })
            }
        }

        var allShort: [String] = FIXED_STRINGS
        allShort += LISTS.map { $0.name }
        for l in LISTS { allShort += l.sections.map { $0.name } }
        let SHORT = sortedByCodeUnit(distinct(allShort))
        for s in SHORT {
            ask("strings.share", s) {
                let b64 = toBase64Url(s), packed = packShare(s)
                return obj(["b64": .string(b64), "back": .bool(try fromBase64Url(b64) == s), "packed": .string(packed),
                            "unpacked": .bool(try unpackShare(packed) == s)])
            }
        }
        var allLabels: [String] = LISTS.map { $0.name }
        allLabels += PHASES.map { $0.label }
        allLabels += ["!!!", "Ärlig Test 2"]
        for label in distinct(allLabels) {
            // a name with no a–z / 0–9 in it earns a clock-made id: written down as a marker
            let noSlug = !jsTrim(label).lowercased().unicodeScalars.contains { ($0.value >= 0x61 && $0.value <= 0x7A) || ($0.value >= 0x30 && $0.value <= 0x39) }
            ask("strings.newPhase", label) {
                var p = shapePhase(newPhase(label, PHASE_IDS, ["leadDays": 3]))
                if noSlug { p["id"] = "<time-id>" }
                return p
            }
            ask("strings.newCondition", label) {
                var c = newCondition(label, ITEM_CONDITION_IDS).json
                if noSlug { c["id"] = "<time-id>" }
                return c
            }
        }
        let EMAILS = ["anna.berg@example.com", "m.s@example.org", "x@y.z", "first_last+tag@example.com", "  spaced.name@example.com ",
                      "UPPER.case@example.com", "élan.vital@example.com", "-lead@example.com", "noatsign", "two@@example.com",
                      "a b@example.com", ""]
        for e in EMAILS + PEOPLE_NAMES {
            ask("strings.email", e) { obj(["looksLikeEmail": .bool(looksLikeEmail(e)), "ownerName": .string(ownerNameFromEmail(e))]) }
        }
        let OWNER_CASES = ["Anna Berg", "Anna <anna.berg@example.com>", "  Two   Spaces  ", "name@host", "mailto:someone@example.com",
                           "at @ sign alone", "A very long owner name that runs well past forty characters",
                           "\(String(repeating: "x", count: 38)) late@example.com"]
        var allOwners: [String] = EMAILS
        allOwners += OWNER_CASES
        allOwners += PEOPLE_NAMES
        for l in LISTS { allOwners += l.items.map { $0.ownedBy } }
        for e in EVENTS { allOwners += e.entries.map { $0.ownedBy } }
        let owners = sortedByCodeUnit(distinct(allOwners))
        for v in owners { ask("strings.shareSafeOwner", v) { jstrings([shareSafeOwner(v), shareSafeOwner(v, max: 10)]) } }
        var allNames: [String] = PEOPLE_NAMES
        allNames += ["Zed Guest", "amy guest", "Åsa", ""]
        for l in LISTS { for i in l.items { allNames += [i.packer, i.ownedBy] } }
        for e in EVENTS { for i in e.entries { allNames += [i.packer, i.ownedBy] } }
        let names = sortedByCodeUnit(distinct(allNames))
        for n in names {
            ask("strings.personColor", n) { obj(["roster": .string(personColor(n, self.PEOPLE)), "hashed": .string(personColor(n, []))]) }
        }
        // Built up step by step: one long `+` chain of arrays is more than the older
        // compiler on GitHub's runner can type-check in reasonable time.
        var allQtys: [String] = ["", "2", "0", "-1", "2.5", "abc", " 3 ", "1e2", "0x10", "Infinity", "3 pairs", "١٢"]
        for l in LISTS { allQtys += l.items.map { $0.qty } }
        for e in EVENTS { allQtys += e.entries.map { $0.qty } }
        let qtys = sortedByCodeUnit(distinct(allQtys))
        for q in qtys {
            ask("strings.qty", q) {
                [.number(effectiveQty(Item(qty: q), 0)), .number(effectiveQty(Item(qty: q, perNight: true), 0)),
                 .number(effectiveQty(Item(qty: q, perNight: true), 5))]
            }
        }
    }

    func askIds() {
        var allPhaseIds: [String] = ["", "no-such-phase"]
        allPhaseIds += DEFAULT_PHASES.map { $0.id }
        allPhaseIds += PHASE_IDS
        for l in LISTS { allPhaseIds += l.items.map { $0.phase } }
        for e in EVENTS { allPhaseIds += e.entries.map { $0.phase } }
        allPhaseIds += ACTIONS.map { $0.whenPhase }
        let phaseIds = sortedByCodeUnit(distinct(allPhaseIds))
        for p in phaseIds {
            ask("ids.phase", p) {
                obj(["known": .bool(phase(p) != nil), "label": .string(phaseLabel(p)), "emoji": .string(phaseEmoji(p)),
                     "color": .string(phaseColor(p)), "leadDays": jint(phaseLeadDays(p)), "order": jint(phaseOrder(p)),
                     "fallback": shapePhase(phaseOrFallback(p))])
            }
        }
        var allCondIds: [String] = ["", "mystery"]
        allCondIds += DEFAULT_ITEM_CONDITIONS.map { $0.id }
        allCondIds += ITEM_CONDITION_IDS
        for l in LISTS { allCondIds += l.items.map { $0.condition } }
        let condIds = sortedByCodeUnit(distinct(allCondIds))
        for c in condIds {
            ask("ids.condition", c) {
                obj(["known": .bool(itemCondition(c) != nil), "label": .string(itemConditionLabel(c)), "tone": .string(conditionTone(c)),
                     "replaces": .bool(conditionReplaces(c))])
            }
        }
        var allChargeIds: [String] = ["bogus"]
        allChargeIds += CHARGE_TYPE_IDS
        for l in LISTS { allChargeIds += l.items.map { $0.chargeType } }
        let chargeIds = sortedByCodeUnit(distinct(allChargeIds))
        for c in chargeIds {
            ask("ids.chargeType", c) {
                obj(["id": .string(chargeType(c).id), "label": .string(chargeTypeLabel(c)), "short": .string(chargeTypeShort(c))])
            }
        }
        ask("ids.labels", ALL) {
            var o: [String: J] = [:]
            for c in CATERING.map({ $0.id }) + ["bogus"] { o["catering:\(c)"] = .string(cateringLabel(c)) }
            for g in GROUP_IDS + ["", "bogus"] {
                o["group:\(g)"] = .string(groupLabel(g))
                o["groupHint:\(g)"] = group(g).map { .string($0.hint) } ?? .null
            }
            for kind in SHARED_KINDS { o["rowId:\(kind)"] = .string(sharedRowId(kind, "  Garage   SHELF ")) }
            for r in RETIRE_REASON_IDS + ["", "bogus"] { o["retire:\(r)"] = .string(retireReasonLabel(r)) }
            for p in ACTION_PRIORITY_IDS + ["", "bogus"] { o["priority:\(p)"] = .string(actionPriorityLabel(p)) }
            let kits: [(J, Kit?)] = [(["emoji": " 🎒 "], Kit(json: ["emoji": " 🎒 "])), (["emoji": ""], Kit(json: ["emoji": ""])), ([:], Kit(json: [:]))]
            for (raw, kit) in kits { o["kitEmoji:\(CJ(raw))"] = .string(kitEmoji(kit)) }
            for level in ["urgent", "due", "ok"] { o["snooze:\(level)"] = jint(backupSnoozeDays(level)) }
            return .object(o)
        }
        for c in -1...100 { ask("ids.weatherCode", String(c)) { weatherCode(Double(c)).json } }
    }
}
