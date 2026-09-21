// §14 Fixed calculations — the same on any data · §15 Installing a list (asked LAST)

import Foundation
import PackingCore

extension Parity {

    func askCalc() {
        ask("calc.constants", ALL) { self.constants() }
        ask("calc.constructors", ALL) {
            let minted = ShapeMap(id: { _ in ID })
            let stamped: (J) -> J = { v in var o = v; o["id"] = .string(ID); o["createdAt"] = .string(NOWMARK); o["updatedAt"] = .string(NOWMARK); return o }
            return obj([
                "newItem": shapeItem(newItem(), minted),
                "newItemNamed": shapeItem(newItem(json: ["name": "Test socks", "qty": "2", "weight": 40, "phase": "door", "perNight": true]), minted),
                "newList": shapeList(
                    newList(json: ["name": "Test list", "sections": [["id": "", "name": " Tools "], ["id": "", "name": ""],
                                                                     ["id": "keep-me", "name": "Kept"], ["id": "keep-me", "name": "Twin"]]]),
                    ShapeMap(sectionId: { $0 == "keep-me" ? $0 : ID }, listId: { _ in ID }, stamps: true)),
                "newEvent": shapeEvent(newEvent(json: ["name": "Test trip", "nights": 3, "mode": "quick", "weatherOn": ["rain", "fog"]]).json, minted: true),
                "newAction": stamped(shapeAction(newAction(json: ["text": "Test", "priority": "urgent", "whenDate": "2026-1-1"]))),
                "newKit": stamped(shapeKit(newKit(json: ["name": "Test kit", "itemIds": ["a", "b", "a", ""]]))),
                "newPerson": shapePerson(newPerson(json: ["name": "  Test  ", "color": "blue"]), minted: true),
                "newMembership": shapeMembership(newMembership(), ShapeMap(mem: { _ in ID })),
                "newSection": obj(["id": .string(ID), "name": .string(newSection("  Tools ").name)]),
            ])
        }
        askHostile()
        askTripBundles()

        ask("calc.countdownLabel", ALL) {
            var o: [String: J] = ["null": .string(countdownLabel(nil))]
            for d in [-10, -3, -2, -1, 0, 1, 2, 3, 10] { o[String(d)] = .string(countdownLabel(d)) }
            return .object(o)
        }
        ask("calc.qtyNights", ALL) {
            var o: [String: J] = [:]
            for n in 0...10 { for laundry in [false, true] { o["\(n)/\(laundry)"] = jint(qtyNights(TripEvent(nights: n, laundry: laundry))) } }
            return .object(o)
        }
        ask("calc.backupShrinks", ALL) {
            var o: [String: J] = [:]
            for (p, n) in [(0, 0), (0, 5), (10, 0), (10, 4), (10, 5), (10, 6), (3, 1)] {
                o["\(p)>\(n)"] = .bool(backupShrinks(BackupCounts(items: p), BackupCounts(items: n)))
            }
            return .object(o)
        }
        ask("calc.coerceGeo", ALL) {
            let cases: [(String, J?)] = [
                ("valid", ["lat": 58.5, "lon": 16.25, "place": "Testville"]), ("strings", ["lat": "12.5", "lon": "-7"]),
                ("tooFarNorth", ["lat": 91, "lon": 0]), ("tooFarEast", ["lat": 0, "lon": 180.5]), ("edge", ["lat": -90, "lon": 180]),
                ("notNumbers", ["lat": "x", "lon": 1]), ("blankStrings", ["lat": "", "lon": ""]), ("nothing", .null),
                ("placeNotString", ["lat": 1, "lon": 2, "place": 7]),
            ]
            var o: [String: J] = [:]
            for (name, g) in cases { o[name] = coerceGeo(json: g)?.json ?? .null }
            return .object(o)
        }
        ask("calc.photos", ALL) {
            let item = Item(json: ["photos": ["ref-1", "data:image/png;base64,AAAA", "", 5, "ref-2"]])
            let refsOnly = Item(json: ["photos": ["ref-1"]])
            return obj([
                "isPhotoRef": .array([isPhotoRef("ref-1"), isPhotoRef("data:x"), isPhotoRef(""), isPhotoRef(nil)].map { .bool($0) }),
                "photoRefs": jstrings(photoRefs(item)), "inlinePhotos": jstrings(inlinePhotos(item)),
                "hasInline": .bool(hasInlinePhotos([item])), "hasInlineNone": .bool(hasInlinePhotos([refsOnly])),
            ])
        }
        askDates()
        askLZW()
    }

    // Hostile input, decoded from JSON TEXT so both sides start from the same bytes. This
    // is where "decoding is coercion" is proved on shapes the real backup never holds.
    private func askHostile() {
        let key = "calc.coerceHostile"
        let parse: (String) throws -> J = { try JSONValue.parse($0) }
        let item = #"{"id":"x","name":"Hostile","seasons":"Summer","weather":["rain","fog",3],"phase":7,"category":"","itemType":"task","chargeType":"usb-d","stats":{"packed":2.9,"used":-1,"unused":"3","lastReviewed":5},"weight":"12","liquid":1,"section":null,"photos":["a","",null,"b","c","d","e","f"],"maintenance":{"notes":3,"intervalDays":90.7,"lastDone":"2026-1-1","log":[{"date":"2026-02-01","note":1},{"date":"nope"},{"date":"2025-12-31","note":"older"}]},"owner":"Legacy Owner","acquired":"2026-02-3","price":-1,"condition":"  worn-out-and-then-some-more-text-to-cut-at-forty  ","retired":"yes","retiredReason":"stolen","qtyOwned":2.9,"capacityL":null,"maxKg":"7","sub":"nope"}"#
        let itemLegacyPhoto = #"{"id":"y","name":"Legacy photo","photo":"ref-legacy","owner":"someone@example.com","maintenance":{"notes":"","link":"","intervalDays":0},"phase":"   "}"#
        let itemOwnedByWins = #"{"id":"z","name":"Owned","ownedBy":"","owner":"Legacy Owner"}"#
        let membership = #"{"id":"m","itemId":"i","templateId":"t","seasons":"x","weather":["cold","mist"],"container":5,"phase":"  door ","itemType":"task","qty":3,"note":null,"order":"2"}"#
        let action = #"{"id":"a","text":5,"kind":"buy","priority":"urgent","whenPhase":"  week  ","whenDate":"2026-9-1","done":"yes","createdAt":"2026-01-01T00:00:00.000Z"}"#
        let kit = #"{"id":"k","name":7,"emoji":"  ","itemIds":["a","a",3,"","b"]}"#
        let event = #"{"id":"e","mode":"fast","activities":"x","nights":2.7,"laundry":"","status":"finished","weather":{"daily":[{"date":"2026-09-01","code":"61","tmax":"20.5","tmin":null,"precipProb":"x"},{"code":1}],"lat":"58.5","lon":null,"place":3},"weatherOn":["snow","sleet"],"geo":{"lat":"95","lon":0},"entries":[{"name":"In a hostile event"}]}"#
        let eventNoWeather = #"{"id":"e2","nights":-1,"weather":{"daily":[]},"geo":{"lat":"12.5","lon":"-7","place":"Testville"}}"#
        let list = #"{"id":"l","name":"Hostile list","group":"XX","role":"special","transport":"Boat","emoji":"  \ud83d\udce6\ud83d\udce6\ud83d\udce6  ","color":"red","defaultContainer":4,"sections":[{"id":"s1","name":" A "},{"id":"s1","name":"B"},{"id":"s2","name":"  "}],"items":[{"name":"Inside"}]}"#

        ask(key, "item") { shapeItem(coerceItem(json: try parse(item))?.json) }
        ask(key, "itemLegacyPhoto") { shapeItem(coerceItem(json: try parse(itemLegacyPhoto))?.json) }
        ask(key, "itemOwnedByWins") { shapeItem(coerceItem(json: try parse(itemOwnedByWins))?.json) }
        ask(key, "membership") { coerceMembership(json: try parse(membership)).map { shapeMembership($0) } }
        // a NUMERIC qty becomes text by JS's own number formatting (H14): never "1e-05"
        for (name, qty) in [("membershipQtySmall", "0.00001"), ("membershipQtyTiny", "1.5e-7"), ("membershipQtyHuge", "1e21")] {
            ask(key, name) {
                coerceMembership(json: try parse(#"{"id":"m2","itemId":"i","templateId":"t","qty":\#(qty)}"#)).map { shapeMembership($0) }
            }
        }
        ask(key, "action") { shapeAction(coerceAction(json: try parse(action))?.json) }
        ask(key, "kit") { shapeKit(coerceKit(json: try parse(kit))?.json) }
        ask(key, "event") { shapeEvent(coerceEvent(json: try parse(event))?.json) }
        ask(key, "eventNoWeather") { shapeEvent(coerceEvent(json: try parse(eventNoWeather))?.json) }
        ask(key, "list") { shapeList(coerceList(json: try parse(list))?.json) }
        ask(key, "maintenance") {
            normalizeMaintenance(json: try parse(#"{"notes":"Wax it","link":7,"intervalDays":"30","lastDone":"2026-03-01","log":[{"date":"2026-03-01","note":"b"},{"date":"2026-03-01","note":"a"},null]}"#))?.json
        }
        ask(key, "sections") {
            .array(normalizeSections(json: try parse(#"[{"id":"a","name":" One "},{"id":"a","name":"Twin"},{"id":"b"},{"id":"c","name":7},"text",{"id":"d","name":"Four"}]"#)).map { $0.json })
        }
        ask(key, "sharedRow") { shapeRow(coerceSharedRow(json: try parse(#"{"kind":"nonsense","key":"  Some   KEY ","name":"  N  ","order":"3","data":[1,2]}"#), 4)) }
        ask(key, "sharedRowNull") { shapeRow(coerceSharedRow(json: .null, 2)) }
        ask(key, "phase") { shapePhase(coercePhase(json: try parse(##"{"id":" x ","label":" L ","leadDays":400.6,"order":"2","color":"#12","emoji":"  ","task":1}"##), 3)) }
        ask(key, "phaseLeadHalf") { shapePhase(coercePhase(json: try parse(##"{"id":"h","label":"Half","leadDays":-0.5,"color":"#ABCDEF12"}"##), 13)) }
        ask(key, "condition") { shapeCondition(coerceCondition(json: try parse(#"{"id":" c ","label":" L ","tone":"loud","replace":1}"#))) }
        ask(key, "person") { coercePerson(json: try parse(##"{"name":"  P ","color":"#GGG"}"##)).map { shapePerson($0, minted: true) } }
    }

    private func askTripBundles() {
        let incoming: [(String, String)] = [
            ("oldBundle", #"{"app":"ams-packing-list","kind":"trip","version":1,"exportedAt":"2026-08-01T00:00:00.000Z","owner":"sender@example.com","realmId":"sender@example.com","event":{"name":"Old shared trip","owner":"sender@example.com","realmId":"sender@example.com","mode":"quick","startDate":"2026-08-10","status":"done","reviewedAt":"2026-08-20T00:00:00.000Z","entries":[{"name":"Tent","owner":"sender@example.com","realmId":"rlm-1","ownedBy":"sender@example.com","sub":[{"0":"P","1":"e","2":"g","3":"s"},{"name":"Guy lines"},"Mallet","",{"x":1},null],"checked":true,"used":true},{"name":"Stove","owner":"Legacy Name","sub":"nope"},{"name":"Lamp","ownedBy":"Anna <anna@example.com>"},{"name":"Mug","ownedBy":"  Anna   Berg  "}]}}"#),
            // the same, with an emoji in the name that was taken apart: its two halves arrive as
            // lone surrogate ESCAPES in the JSON text, which `JSON.parse` accepts
            ("oldBundleEmoji", #"{"app":"ams-packing-list","kind":"trip","version":1,"event":{"name":"Emoji trip","entries":[{"name":"Kit","sub":[{"0":"H","1":"i","2":" ","3":"\ud83d","4":"\ude00","5":"!"}]}]}}"#),
            ("notATrip", #"{"app":"ams-packing-list","kind":"grab","event":{"name":"x"}}"#),
            ("noEvent", #"{"kind":"trip"}"#),
        ]
        for (name, json) in incoming { ask("calc.tripBundleIncoming", name) { importedEventShape(try parseTripBundle(json)) } }
        let outgoing = #"{"id":"out","name":"Outgoing","owner":"me@example.com","realmId":"me@example.com","mode":"trip","startDate":"2026-10-01","entries":[{"id":"e1","name":"Rope","owner":"me@example.com","realmId":"me@example.com","ownedBy":"me@example.com","sub":["Sling","","Carabiner"],"weight":120,"checked":true,"used":false,"custom":true,"sourceListId":"l","sourceItemId":"i","stats":{"packed":3}},{"id":"e2","name":"Helmet","ownedBy":"Anna Berg","sub":[],"itemType":"reminder"}]}"#
        ask("calc.tripBundleOutgoing", ALL) {
            let b = try buildTripBundle(coerceEvent(json: try JSONValue.parse(outgoing)), whenISO: self.NOW)
            return obj(["bundle": self.bundleShape(b), "leaks": self.leaksOf(b)])
        }
    }

    private func askDates() {
        var all = [TODAY, "2024-02-29", "2026-12-31", "2026-01-01", "2026-03-29", "2026-10-25", "", "not-a-date", "2026-13-01"]
        all += EVENTS.flatMap { [$0.startDate, $0.endDate] } + ACTIONS.map { $0.whenDate }
        for l in LISTS {
            for it in l.items {
                all += [it.acquired, it.expiry, it.warranty]
                if let m = it.maintenance { all.append(m.lastDone); all += m.log.map { $0.date } }
            }
        }
        for d in sortedByCodeUnit(distinct(all)) {
            ask("calc.dates", d) {
                var add: [String: J] = [:]
                for n in [-366, -1, 0, 1, 30, 365] { add[String(n)] = .string(addDays(d, n)) }
                return obj([
                    "addDays": .object(add), "daysBetween": jint(daysBetween(d, self.TODAY)), "daysUntil": jint(daysUntil(d, self.TODAY)),
                    "monthKey": .string(monthKey(d)), "endFromNights": .string(endFromNights(d, 3)),
                    "nightsToToday": jint(nightsBetween(d, self.TODAY)), "nightsFromToday": jint(nightsBetween(self.TODAY, d)),
                ])
            }
        }
        let seeds = distinct([monthKey(TODAY), "2024-02", "2026-12", "2027-01"] + EVENTS.flatMap { [monthKey($0.startDate), monthKey($0.endDate)] })
            .filter { !$0.isEmpty }
        let months = sortedByCodeUnit(distinct(seeds.flatMap { [shiftMonth($0, -1), $0, shiftMonth($0, 1)] }))
        for m in months {
            for ws in [1, 0] {
                ask("calc.monthGrid", "\(m)/\(ws)") {
                    let g = monthGrid(m, ws)
                    return obj(["key": .string(g.key), "year": jint(g.year), "month": jint(g.month),
                                "days": jstrings(g.days.map { "\($0.iso)\($0.inMonth ? "" : "*")" })])
                }
            }
        }
        ask("calc.monthGrid", "invalid") { monthGrid("2026-1", 1).json }
        for m in months + ["x", "2026-1"] {
            ask("calc.shiftMonth", m) {
                var o: [String: J] = [:]
                for n in [-13, -12, -1, 0, 1, 12, 13] { o[String(n)] = .string(shiftMonth(m, n)) }
                return .object(o)
            }
        }
        ask("calc.rangeCellState", ALL) {
            var o: [String: J] = [:]
            for (a, b) in [("2026-09-10", "2026-09-14"), ("2026-09-10", ""), ("2026-09-10", "2026-09-10"), ("", "2026-09-14")] {
                for d in ["2026-09-09", "2026-09-10", "2026-09-12", "2026-09-14", "2026-09-15", ""] {
                    o["\(d)|\(a)|\(b)"] = .string(rangeCellState(d, a, b))
                }
            }
            return .object(o)
        }
    }

    // LZW + base64url on real bulk. The big one is the canonical text of every coerced
    // list: large enough to widen the codes well past 9 bits, which a name never does.
    private func askLZW() {
        let lists = CJ(.object(answer("coerce.list") ?? [:]))
        let events = CJ(.object(answer("coerce.event") ?? [:]))
        let texts: [(String, String)] = [
            ("empty", ""), ("one", "a"), ("run", String(repeating: "a", count: 40)), ("classic", "TOBEORNOTTOBEORTOBEORNOT"),
            ("unicode", String(repeating: "Åäö – “quotes” 😀 ", count: 20)), ("lists", lists), ("events", events),
            ("both", lists + events),   // big enough to FILL the 65 536-entry dictionary, the one branch nothing smaller reaches
        ]
        for (name, text) in texts {
            ask("calc.lzw", name) {
                let raw = Array(text.utf8)
                let z = lzwCompress(raw)
                let back = try lzwDecompress(z)
                let b64 = bytesToBase64Url(z)
                return obj([
                    "textBytes": jint(raw.count), "textHash": .number(Double(fnv1a(raw))), "zipBytes": jint(z.count),
                    "zipHash": .number(Double(fnv1a(z))),
                    "b64Head": .string(jsSlice(b64, 0, 64)), "b64Tail": .string(jsSlice(b64, -64)), "b64Length": jint(jsLength(b64)),
                    "roundTrip": .bool(back == raw), "b64RoundTrip": .bool(try base64UrlToBytes(b64) == z),
                ])
            }
        }
    }

    // === §15 Installing a list — LAST, because it changes the model's global state ===
    func askInstalling() {
        let keepPhases = PHASES, keepConditions = ITEM_CONDITIONS
        let phaseCases: [(String, String)] = [
            ("hostile", #"[{"id":"zeta","label":"Zeta","order":1},{"id":"alpha","label":"Alpha","order":1},{"id":"alpha","label":"Twin","order":0},{"id":"","label":"No id"},{"id":"nolabel"},{"id":"Beta","label":"Beta","order":1},{"id":"last","label":"Last","order":"7","leadDays":-5,"task":true},{"id":"first","label":"First","order":-2}]"#),
            ("empty", "[]"), ("notAList", #"{"id":"x","label":"X"}"#),
        ]
        for (name, json) in phaseCases {
            ask("calc.setPhases", name) {
                let out = setPhases(json: try JSONValue.parse(json)).map { shapePhase($0) }
                return obj(["phases": .array(out), "ids": jstrings(PHASE_IDS), "customised": .bool(phasesCustomised()),
                            "defaultPhaseId": .string(defaultPhaseId()), "orderOfUnknown": jint(phaseOrder("nowhere"))])
            }
        }
        setPhases(keepPhases)
        let conditionCases: [(String, String)] = [
            ("hostile", #"[{"id":"ok","label":"Fine","tone":"warn"},{"id":"ok","label":"Twin"},{"id":"","label":"No id"},{"id":"gone","label":"Gone","tone":"danger","replace":"yes"},{"label":"No id either"}]"#),
            ("empty", "[]"),
        ]
        for (name, json) in conditionCases {
            ask("calc.setItemConditions", name) {
                let out = setItemConditions(json: try JSONValue.parse(json)).map { shapeCondition($0) }
                return obj(["conditions": .array(out), "ids": jstrings(ITEM_CONDITION_IDS), "replaces": .bool(conditionReplaces("gone")),
                            "reason": .string(shoppingReason(Item(condition: "gone"), self.TODAY))])
            }
        }
        setItemConditions(keepConditions)
    }
}
