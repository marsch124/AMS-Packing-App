// §9 Per event · §10 Probe trips

import Foundation
import PackingCore

let NIGHTS_PROBE = 7

/// `byName`: `String(a.name ?? "").localeCompare(String(b.name ?? ""), undefined, { sensitivity: "base" })`
func byName(_ a: String, _ b: String) -> Int { jsLocaleCompare(a, b, sensitivity: .base) }

extension Parity {

    func bundleShape(_ b: TripBundle) -> J {
        let j = b.json
        return obj(["app": j["app"], "kind": j["kind"], "version": j["version"], "exportedAt": j["exportedAt"],
                    "event": shapeEvent(j["event"], entryShape: { shapeSlimEntry($0) })])
    }
    /// What a bundle must never carry: the sync addon's two keys, and an address anywhere.
    /// Looked for in the bundle as it would be written to a file or a link.
    func leaksOf(_ b: TripBundle) -> J {
        let j = b.json
        let event = j["event"]
        return obj([
            "reservedOnBundle": jstrings(SYNC_RESERVED_KEYS.filter { j[$0] != nil }),
            "reservedOnEvent": jstrings(SYNC_RESERVED_KEYS.filter { event?[$0] != nil }),
            "entriesWithReserved": jint(asArr(event?["entries"]).filter { e in SYNC_RESERVED_KEYS.contains { e[$0] != nil } }.count),
            "addressInside": .bool(addressInside(b.text())),
        ])
    }

    // === §9 Per event ========================================================
    func askEvents() {
        for (i, E) in EVENTS.enumerated() { askEvent(E, i) }
    }

    private func askEvent(_ E: TripEvent, _ i: Int) {
        let k = eventKey(E, i)
        let lists = LISTS

        ask("event.listsForEvent", k) { jstrings(listsForEvent(E, lists).map { $0.id }) }
        ask("event.matchCounts", k) {
            var out: [String: J] = [:]
            for l in lists { out[l.id] = jint(l.items.filter { itemMatchesEvent($0, E, l) }.count) }
            return .object(out)
        }
        ask("event.buildTotalEntries", k) { .array(buildTotalEntries(E, lists).map { shapeItem($0, ShapeMap(dropId: true)) }) }
        ask("event.buildTotalEntries.weatherAll", k) {
            var e = E; e.weatherOn = WEATHER_CONDITION_IDS
            return jstrings(buildTotalEntries(e, lists).map(buildRef))
        }
        ask("event.regenerateEntries", k) {
            let had = Set(E.entries.map { $0.id })
            return jstrings(regenerateEntries(E, lists).map { "\(entryRef($0))|\(had.contains($0.id) ? $0.id : "<new>")" })
        }

        // grouping — real entries, then the synthetic overlay
        for (suffix, e) in [("", E), (".synth", synthEvent(E))] {
            ask("event.entriesByPhase\(suffix)", k) {
                .array(entriesByPhase(e.entries).map { obj(["phase": shapePhase($0.phase), "entries": refs($0.entries)]) })
            }
            for mode in ["category", "container", "section", "stored", "when"] {
                ask("event.groupBy.\(mode)\(suffix)", k) {
                    .array(groupBy(mode, e.entries).map { g in
                        obj(["label": .string(g.label), "hint": g.hint.map { .string($0) }, "entries": refs(g.entries)])
                    })
                }
            }
            ask("event.progress\(suffix)", k) {
                obj(["progress": progress(e.entries).json, "packable": jint(packable(e.entries).count),
                     "setAside": jint(e.entries.filter { isSetAside($0) }.count)])
            }
            ask("event.packSteps\(suffix)", k) {
                .array(packSteps(e.entries).map { s in
                    obj(["phase": .string(s.phase.id), "total": jint(s.total), "done": jint(s.done),
                         "remaining": jint(s.remaining), "entries": refs(s.entries)])
                })
            }
            ask("event.assignedPeople\(suffix)", k) { jstrings(assignedPeople(e.entries)) }
            ask("event.groupByPacker\(suffix)", k) {
                .array(groupByPacker(e.entries, self.PEOPLE_NAMES).map { obj(["packer": .string($0.packer), "entries": refs($0.entries)]) })
            }
            ask("event.clusterByKit\(suffix)", k) {
                .array(clusterByKit(e.entries).map { obj(["kit": .string($0.kit), "entries": refs($0.entries)]) })
            }
            ask("event.expiringOnTrip\(suffix)", k) {
                let tripEnd = tripEndDate(e)
                let end = tripEnd.isEmpty ? addDays(self.TODAY, 14) : tripEnd
                return .array(expiringOnTrip(e.entries, end, self.TODAY).map { r in
                    obj(["entry": .string(entryRef(r.entry)), "expiry": .string(r.expiry),
                         "alreadyOut": .bool(r.alreadyOut), "daysLeft": jint(r.daysLeft)])
                })
            }
            ask("event.bagLoads\(suffix)", k) { .array(bagLoads(e.entries, qtyNights(e), containerLimits(lists)).map { $0.json }) }
            ask("event.packingFlags\(suffix)", k) { packingFlags(e.entries, qtyNights(e)).json }
            ask("event.tripNudge\(suffix)", k) { tripNudge(e, self.TODAY)?.json }
        }
        ask("event.groupByContainer", k) {
            .array(groupByContainer(E.entries).map { obj(["container": .string($0.container), "entries": refs($0.entries)]) })
        }
        ask("event.groupByCategory", k) {
            .array(groupByCategory(E.entries).map { obj(["category": .string($0.category), "entries": refs($0.entries)]) })
        }
        ask("event.groupBySection", k) {
            .array(groupBySection(E.entries).map { obj(["label": .string($0.label), "entries": refs($0.entries)]) })
        }
        ask("event.groupByStorage", k) {
            .array(groupByStorage(E.entries).map { obj(["label": .string($0.label), "entries": refs($0.entries)]) })
        }
        let tie: (Item, Item) -> Int = { a, b in byName(a.name, b.name) }
        let entrySorts: [(String, (Item) -> J?, Bool, ((Item, Item) -> Int)?)] = [
            ("name", { .string($0.name) }, false, nil), ("storage", { .string($0.storage) }, false, tie),
            ("container", { .string($0.container) }, false, tie), ("weight", { .number($0.weight) }, true, tie),
        ]
        for (name, valOf, num, tieBy) in entrySorts {
            for dir in ["asc", "desc"] {
                ask("event.sortRowsBy.\(name).\(dir)", k) { refs(sortRowsBy(E.entries, valOf, dir: dir, num: num, tie: tieBy)) }
            }
        }
        let entryGroups: [(String, (Item) -> String?, [String], String?)] = [
            ("category", { $0.category }, CATEGORIES, nil), ("container", { $0.container }, CONTAINERS, nil),
            ("storage", { $0.storage }, [], nil), ("packer", { $0.packer }, PEOPLE_NAMES, "Anyone"),
        ]
        for (name, keyOf, order, emptyLabel) in entryGroups {
            ask("event.groupRowsBy.\(name)", k) {
                let entries = self.synthEvent(E).entries
                let groups = emptyLabel.map { groupRowsBy(entries, keyOf, order: order, emptyLabel: $0) }
                    ?? groupRowsBy(entries, keyOf, order: order)
                return .array(groups.map { obj(["key": .string($0.key), "label": .string($0.label), "rows": refs($0.rows)]) })
            }
        }

        // quantities and weight
        ask("event.qtyNights", k) { jint(qtyNights(E)) }
        ask("event.effectiveQty", k) {
            let n = qtyNights(E)
            var out: [String: J] = [:]
            for (j, x) in E.entries.enumerated() {
                out[x.id.isEmpty ? "#\(j)" : x.id] = [.number(effectiveQty(x, n)), .number(effectiveQty(x, 0)), .number(effectiveQty(x, NIGHTS_PROBE))]
            }
            return .object(out)
        }
        ask("event.bagLoads.n7", k) { .array(bagLoads(E.entries, NIGHTS_PROBE).map { $0.json }) }
        ask("event.packingFlags.n7", k) { packingFlags(E.entries, NIGHTS_PROBE).json }

        // dates
        ask("event.dates", k) {
            let d = daysUntil(E.startDate, self.TODAY)
            return obj([
                "daysUntil": jint(d), "countdown": .string(countdownLabel(d)),
                "nightsBetween": jint(nightsBetween(E.startDate, E.endDate)),
                "tripEndDate": .string(tripEndDate(E)), "endFromNights": .string(endFromNights(E.startDate, E.nights)),
                "monthKeyStart": .string(monthKey(E.startDate)), "monthKeyEnd": .string(monthKey(E.endDate)),
                "orderRange": jstrings(orderRange(E.startDate, E.endDate)),
                "orderRangeReversed": jstrings(orderRange(E.endDate, E.startDate)),
            ])
        }
        ask("event.tripNudge.sweep", k) {
            var e = self.synthEvent(E)
            let start = e.startDate.isEmpty ? self.TODAY : e.startDate
            e.startDate = start
            var out: [String: J] = [:]
            for d in [40, 30, 8, 7, 2, 1, 0, -1] { out[String(d)] = tripNudge(e, addDays(start, -d))?.json ?? .null }
            return .object(out)
        }
        ask("event.rangeCells", k) {
            let key = monthKey(E.startDate)
            if key.isEmpty { return .null }
            return jstrings(monthGrid(key, 1).days.map { rangeCellState($0.iso, E.startDate, E.endDate) })
        }

        // weather and place
        ask("event.deriveWeather", k) { deriveWeather(E)?.json }
        ask("event.weatherGear", k) { .array(weatherGear(E, lists).map { $0.json }) }
        ask("event.pendingWeatherItems", k) { jint(pendingWeatherItems(E, lists)) }
        ask("event.weatherSuggestions", k) { weatherSuggestions(E, lists).json }
        ask("event.weatherSuggestions.synth", k) {
            // a fixed forecast laid over the trip: one wet cool day, one hot windy one, one snowy one
            var e = E
            let d0 = e.startDate.isEmpty ? self.TODAY : e.startDate
            e.entries = []
            let forecast: J = ["weather": [
                "place": "Testville, XX", "lat": 12.25, "lon": -12.25, "fetchedAt": .string(self.NOW),
                "daily": [
                    ["date": .string(d0), "code": 61, "tmax": 12.5, "tmin": 4.5, "precipProb": 80, "wind": 10],
                    ["date": .string(addDays(d0, 1)), "code": 1, "tmax": 27.5, "tmin": 15.49, "precipProb": 49.5, "wind": 35],
                    ["date": .string(addDays(d0, 2)), "code": 73, "tmax": -0.5, "tmin": -2.5, "precipProb": 0, "wind": 34.4],
                ],
            ]]
            e.weather = coerceEvent(json: forecast)?.weather
            return obj(["derived": deriveWeather(e)?.json ?? .null, "suggestions": weatherSuggestions(e, lists).json,
                        "coords": eventCoords(e)?.json ?? .null])
        }
        ask("event.eventCoords", k) { eventCoords(E)?.json }

        // export and sharing
        ask("event.totalListRows", k) { .array(totalListRows(E, lists).map { $0.json }) }
        var bundleCanon: J? = nil
        ask("event.tripBundle", k) { bundleCanon = self.bundleShape(buildTripBundle(E, whenISO: self.NOW)); return bundleCanon }
        ask("event.tripBundle.leaks", k) { self.leaksOf(buildTripBundle(E, whenISO: self.NOW)) }
        ask("event.tripBundle.parsed", k) { importedEventShape(try parseTripBundle(buildTripBundle(E, whenISO: self.NOW).text())) }
        ask("event.tripLink", k) {
            guard let link = encodeTripLink(E, whenISO: self.NOW) else { return obj(["fits": false, "roundTrip": .null]) }
            return obj(["fits": true, "prefix": .string(jsSlice(link, 0, 4)),
                        "roundTrip": importedEventShape(try decodeTripLink(jsSlice(link, 4)))])
        }
        if let canon = bundleCanon {
            ask("event.packedCanonical", k) {
                let text = CJ(canon)
                let packed = packShare(text)
                return obj(["packed": .string(packed), "textLength": jint(jsLength(text)),
                            "roundTrip": .bool(try unpackShare("\(packed).") == text)])
            }
        }

        // presets and the review
        ask("event.presetConfig", k) { presetConfigFromEvent(E).json }
        ask("event.applyPresetConfig", k) {
            let donor = self.EVENTS[(i + 1) % self.EVENTS.count]
            return presetConfigFromEvent(applyPresetConfig(E, presetConfigFromEvent(donor))).json
        }
        let review: (TripEvent) -> J = { e in
            var ls = lists
            let changed = applyReview(e, &ls, self.NOW)
            var stats: [String: J] = [:]
            for l in changed {
                var per: [String: J] = [:]
                for it in l.items where it.stats.lastReviewed == self.NOW { per[it.id] = it.stats.json }
                stats[l.id] = .object(per)
            }
            let prune: (Int) -> J = { minTrips in
                .array(pruneSuggestions(ls, minTrips: minTrips).map { p in
                    obj(["listId": .string(p.listId), "listName": .string(p.listName), "item": .string(itemRef(p.item)),
                         "stats": p.stats.json, "reason": .string(p.reason), "times": jint(p.times)])
                })
            }
            return obj(["changed": jstrings(changed.map { $0.id }), "stats": .object(stats), "prune1": prune(1), "prune2": prune(2)])
        }
        ask("event.applyReview.real", k) { review(E) }
        ask("event.applyReview.synth", k) { review(self.synthEvent(E)) }
        ask("event.applyReview.synthUnticked", k) {
            var e = self.synthEvent(E)
            for j in e.entries.indices { e.entries[j].checked = false }
            return review(e)
        }
        ask("event.itemFromEntry", k) {
            var out: [String: J] = [:]
            for (j, x) in E.entries.enumerated() where j < 10 || x.custom {
                out[String(j)] = shapeItem(itemFromEntry(x), ShapeMap(id: { _ in ID }))
            }
            return .object(out)
        }
    }

    // === §10 Probe trips — one dimension moved at a time =====================
    func askProbes() {
        let tickable = LISTS.filter { $0.role.isEmpty }.map { $0.id }
        let base: [String: J] = [
            "id": "probe", "name": "Probe", "mode": "trip", "activities": jstrings(tickable), "transport": "Car",
            "season": "Summer", "contexts": [], "weatherOn": [], "catering": "mixed", "entries": [],
        ]
        var probes: [(String, [String: J])] = [("baseline", [:])]
        for s in SEASONS { probes.append(("season=\(s)", ["season": .string(s)])) }
        for t in TRANSPORTS { probes.append(("transport=\(t)", ["transport": .string(t)])) }
        for c in CATERING { probes.append(("catering=\(c.id)", ["catering": .string(c.id)])) }
        for c in CONTEXTS { probes.append(("contexts=\(c)", ["contexts": [.string(c)]])) }
        probes.append(("contexts=Indoor+Race", ["contexts": ["Indoor", "Race"]]))
        probes.append(("mode=quick", ["mode": "quick"]))
        probes.append(("weatherOn=all", ["weatherOn": jstrings(WEATHER_CONDITION_IDS)]))
        probes.append(("activities=reversed", ["activities": jstrings(tickable.reversed())]))
        for (name, patch) in probes {
            ask("probe.buildTotalEntries", name) {
                let e = TripEvent(json: .object(base.merging(patch) { _, new in new }))
                return jstrings(buildTotalEntries(e, self.LISTS).map(buildRef))
            }
        }
        ask("probe.weatherGear", "baseline") { .array(weatherGear(TripEvent(json: .object(base)), self.LISTS).map { $0.json }) }
    }
}
