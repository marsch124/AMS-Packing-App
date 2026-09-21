// §11 The whole library

import Foundation
import PackingCore

extension Parity {

    func askLibrary() {
        ask("library.containerNames", ALL) { jstrings(containerNames(self.LISTS)) }
        ask("library.containerLimits", ALL) { .object(containerLimits(self.LISTS).mapValues { .number($0) }) }
        ask("library.backupCounts", ALL) { backupCounts(lists: self.LISTS, events: self.EVENTS, actions: self.ACTIONS).json }
        for gid in GROUP_IDS + [""] {
            ask("library.orderActivities", gid) {
                jstrings(orderActivities(gid, self.LISTS.filter { $0.group == gid && $0.role.isEmpty }).map { $0.id })
            }
        }
        ask("library.orderActivities", "WET-reversed") {
            jstrings(orderActivities("WET", self.LISTS.filter { $0.group == "WET" && $0.role.isEmpty }.reversed()).map { $0.id })
        }
        askRelationalCore()
        askOverview()
        askCare()
        askDeviceAudit()
        askEventsAsASet()
        askBackupReminders()
    }

    // --- the relational core: fold into a catalogue, resolve back -------------
    private func askRelationalCore() {
        let CAT = buildCatalog(LISTS)    // ids are minted: written down by position
        var itemPos: [String: String] = [:], memPos: [String: String] = [:]
        for (n, it) in CAT.items.enumerated() where itemPos[it.id] == nil { itemPos[it.id] = "I\(n)" }
        for (n, m) in CAT.memberships.enumerated() where memPos[m.id] == nil { memPos[m.id] = "M\(n)" }
        let catMap = ShapeMap(id: { itemPos[$0] ?? $0 }, mem: { memPos[$0] ?? $0 })

        ask("library.buildCatalog.items", ALL) { .array(CAT.items.map { shapeItem($0, catMap) }) }
        ask("library.buildCatalog.memberships", ALL) { .array(CAT.memberships.map { shapeMembership($0, catMap) }) }
        ask("library.buildCatalog.templates", ALL) { .array(CAT.templates.map { shapeList($0) }) }
        for (i, t) in CAT.templates.enumerated() {
            ask("library.resolveTemplate", listKey(t, i)) { shapeList(resolveTemplate(t, CAT.items, CAT.memberships), catMap) }
            ask("library.resolveTemplate.drift", listKey(t, i)) {
                let back = resolveTemplate(t, CAT.items, CAT.memberships).items.map { $0.json }
                let orig = self.LISTS[i].items.filter { !jsTrim($0.name).isEmpty }.map { $0.json }
                let fields = ["name", "container", "phase", "itemType", "qty", "note", "section", "seasons", "contexts",
                              "transports", "catering", "weather", "category", "weight", "storage", "swedish", "packer", "ownedBy"]
                var drift: [J] = []
                for (j, o) in orig.enumerated() {
                    let b: J = j < back.count ? back[j] : [:]
                    let diff = fields.filter { CJ(o[$0] ?? .null) != CJ(b[$0] ?? .null) }
                    if !diff.isEmpty { drift.append(obj(["index": jint(j), "fields": jstrings(diff)])) }
                }
                return obj(["original": jint(orig.count), "resolved": jint(back.count), "drift": .array(drift)])
            }
        }
        for (i, t) in CAT.templates.enumerated() {
            ask("library.resolveTemplateItems", listKey(t, i)) {
                // the same resolve, handed the catalogue as a Map and the memberships back to front
                var byId: [String: Item] = [:]
                for it in CAT.items { byId[it.id] = it }
                return jstrings(resolveTemplateItems(t, byId, CAT.memberships.reversed()).map {
                    "\(itemPos[$0.id] ?? $0.id)|\($0.name)|\($0.container)|\($0.phase)"
                })
            }
        }
        ask("library.resolveItemAlone", ALL) { .array(CAT.items.prefix(25).map { shapeItem(resolveItemAlone($0), catMap) }) }
        ask("library.applyIntrinsic", ALL) {
            .array(CAT.items.prefix(25).map { c in
                var src: Item? = nil
                for l in self.LISTS { src = l.items.first { normName($0.name) == normName(c.name) }; if src != nil { break } }
                return shapeItem(src.map { applyIntrinsic(c, $0) } ?? applyIntrinsic(c, json: nil), catMap)
            })
        }
        let planShape: (ContainerMigrationPlan) -> J = { p in
            var defaults: [String: J] = [:], effective: [String: J] = [:]
            for r in p.defaults { defaults[itemPos[r.itemId] ?? r.itemId] = .string(r.container) }
            for r in p.effective { effective[memPos[r.id] ?? r.id] = .string(r.container) }
            return obj([
                "defaults": .object(defaults), "effective": .object(effective),
                "itemChanges": .array(p.itemChanges.map { obj(["id": .string(itemPos[$0.id] ?? $0.id), "container": .string($0.container)]) }),
                "memChanges": .array(p.memChanges.map { obj(["id": .string(memPos[$0.id] ?? $0.id), "container": .string($0.container)]) }),
            ])
        }
        ask("library.planContainerMigration", ALL) { planShape(planContainerMigration(CAT.items, CAT.memberships, CAT.templates)) }
        ask("library.planContainerMigration.legacy", ALL) {
            // the pre-v108 shape: every real choice an override, every default frozen
            var items = CAT.items, mems = CAT.memberships
            var byId: [String: Item] = [:]
            for it in items { byId[it.id] = it }
            var tplDef: [String: String] = [:]
            for t in CAT.templates { tplDef[t.id] = templateDefaults(t).container }
            for n in mems.indices {
                let m = mems[n]
                // `m.container || tplDef.get(m.templateId) || (byId.get(m.itemId) || {}).container || ''`
                if !m.container.isEmpty { continue }
                if let d = tplDef[m.templateId], !d.isEmpty { mems[n].container = d } else { mems[n].container = byId[m.itemId]?.container ?? "" }
            }
            for n in items.indices { items[n].container = "Carry-on / hand luggage" }
            return planShape(planContainerMigration(items, mems, CAT.templates))
        }

        // the save path: one resolved item -> catalogue item + membership -> resolved again
        let minted = ShapeMap(id: { _ in ID }, mem: { _ in ID })
        for (i, l) in LISTS.enumerated() {
            let k = listKey(l, i)
            ask("library.decompose", k) {
                var order = 0
                var out: [J] = []
                for it in l.items where !jsTrim(it.name).isEmpty {
                    let cat = catalogItemFromResolved(it)
                    let m = membershipFromResolved(cat, l.id, it, Double(order)); order += 1
                    let back = resolveMembership(cat, m, templateDefaults(l))
                    out.append(obj(["membership": shapeMembership(m, minted), "resolved": shapeItem(back, ShapeMap(id: { _ in ID }))]))
                }
                return .array(out)
            }
            ask("library.decompose.inferred", k) {
                var order = 0
                var out: [J] = []
                for it in l.items where !jsTrim(it.name).isEmpty {
                    let cat = catalogItemFromResolved(it)
                    var bare = it
                    bare.ovContainer = nil; bare.ovPhase = nil
                    bare.tplContainer = templateDefaults(l).container
                    out.append(shapeMembership(membershipFromResolved(cat, l.id, bare, Double(order)), minted)); order += 1
                }
                return .array(out)
            }
            ask("library.containerOverrideFor", k) {
                jstrings(l.items.map { containerOverrideFor($0.container, templateDefaults(l).container, $0.defContainer ?? "") })
            }
            let nextIndex = (i + 1) % LISTS.count
            let next = LISTS[nextIndex]
            ask("library.mapSectionAcrossTemplates", "\(k)>\(listKey(next, nextIndex))") {
                var out: [String: J] = [:]
                for s in l.sections { out[s.id] = .string(mapSectionAcrossTemplates(s.id, l, next)) }
                out["(unknown)"] = .string(mapSectionAcrossTemplates("no-such-section", l, next))
                out["(blank)"] = .string(mapSectionAcrossTemplates("", l, next))
                return .object(out)
            }
            ask("library.linkFromResolved", k) {
                guard let it = l.items.first else { return .null }
                let itemId = (it.itemId ?? "").isEmpty ? it.id : (it.itemId ?? "")
                let link = linkFromResolved(it, itemId, section: mapSectionAcrossTemplates(it.section, l, next))
                return pick(link.json, ["_itemId", "_link", "name"] + CONTEXTUAL_FIELDS + ["section", "_ovContainer", "_ovPhase"])
            }
        }
        ask("library.containerDefaultsFrom", ALL) {
            var rows: [ContainerRow] = []
            for l in self.LISTS { for it in l.items { rows.append(ContainerRow(itemId: it.id, container: it.container)) } }
            var out: [String: J] = [:]
            for r in containerDefaultsFrom(rows) { out[r.itemId] = .string(r.container) }
            return .object(out)
        }
    }

    // --- the overview, duplicates, sorting -------------------------------------
    func catalogueRows(_ lists: [PackList]) -> [CatalogRow] { catalogRows(lists, THINGS) }

    private func askOverview() {
        ask("library.catalogRows", ALL) {
            .array(self.catalogueRows(self.LISTS).map { r in
                obj(["id": .string(r.id), "name": .string(r.name), "item": .string(itemRef(r.item)),
                     "templates": .array(r.templates.map { $0.json })])
            })
        }
        ask("library.duplicateGroups", ALL) {
            .array(duplicateGroups(self.catalogueRows(self.LISTS)).map { g in
                obj(["key": .string(g.key), "exact": .bool(g.exact), "rows": jstrings(g.rows.map { $0.id })])
            })
        }
        ask("library.duplicateIds", ALL) { jset(duplicateIds(self.catalogueRows(self.LISTS))) }
        let tie: (CatalogRow, CatalogRow) -> Int = { a, b in byName(a.name, b.name) }
        let rowSorts: [(String, (CatalogRow) -> J?, Bool, ((CatalogRow, CatalogRow) -> Int)?)] = [
            ("name", { .string($0.item.name) }, false, nil), ("manufacturer", { .string($0.item.manufacturer) }, false, tie),
            ("storage", { .string($0.item.storage) }, false, tie), ("weight", { .number($0.item.weight) }, true, tie),
            ("price", { .number($0.item.price) }, true, tie),
        ]
        for (name, valOf, num, tieBy) in rowSorts {
            for dir in ["asc", "desc"] {
                ask("library.sortRowsBy.\(name).\(dir)", ALL) {
                    jstrings(sortRowsBy(self.catalogueRows(self.LISTS), valOf, dir: dir, num: num, tie: tieBy).map { $0.id })
                }
            }
        }
        let places = PLACES_IN.map { $0.jsString }   // `String(o)`, as groupRowsBy reads its `order`
        let rowGroups: [(String, (CatalogRow) -> String?, [String])] = [
            ("category", { $0.item.category }, CATEGORIES), ("storage", { $0.item.storage }, places),
            ("ownedBy", { $0.item.ownedBy }, []), ("condition", { itemConditionLabel($0.item.condition) }, ITEM_CONDITIONS.map { $0.label }),
        ]
        for (name, keyOf, order) in rowGroups {
            ask("library.groupRowsBy.\(name)", ALL) {
                .array(groupRowsBy(self.catalogueRows(self.synthLists()), keyOf, order: order).map { g in
                    obj(["key": .string(g.key), "label": .string(g.label), "rows": jstrings(g.rows.map { $0.id })])
                })
            }
        }
    }

    // --- care, shopping, actions — real, then synthetic -----------------------
    private func askCare() {
        let synthA = synthActions()
        let cases: [(String, [PackList], [ActionItem])] = [("", LISTS, ACTIONS), (".synth", synthLists(), synthA)]
        for (suffix, lists, actions) in cases {
            ask("library.maintenanceList\(suffix)", ALL) {
                .array(maintenanceList(lists, self.TODAY).map { r in
                    obj(["listId": .string(r.listId), "listName": .string(r.listName), "listNames": jstrings(r.listNames),
                         "item": .string(itemRef(r.item)), "status": r.status.json])
                })
            }
            ask("library.maintenanceStatus\(suffix)", ALL) {
                var o: [String: J] = [:]
                for r in self.catalogueRows(lists) where hasCare(r.item) { o[r.id] = maintenanceStatus(r.item, self.TODAY)?.json ?? .null }
                return .object(o)
            }
            ask("library.careSections\(suffix)", ALL) {
                .array(careSections(maintenanceList(lists, self.TODAY)).map { s in
                    obj(["key": .string(s.key), "state": .string(s.state), "label": .string(s.label), "fold": .bool(s.fold),
                         "rows": jstrings(s.rows.map { $0.item.id })])
                })
            }
            ask("library.maintenanceSummary\(suffix)", ALL) { maintenanceSummary(lists, self.TODAY).json }
            ask("library.maintenanceByDate\(suffix)", ALL) {
                var o: [String: J] = [:]
                for b in maintenanceByDate(lists, self.TODAY) { o[b.date] = jstrings(b.rows.map { $0.item.id }) }
                return .object(o)
            }
            ask("library.logMaintenance\(suffix)", ALL) {
                var out: [String: J] = [:]
                for r in maintenanceList(lists, self.TODAY) {
                    var item = r.item
                    out[r.item.id] = logMaintenance(&item, self.TODAY, "parity").maintenance?.json ?? .null
                }
                return .object(out)
            }
            ask("library.shoppingSuggestions\(suffix)", ALL) {
                .array(shoppingSuggestions(self.catalogueRows(lists).map { $0.item }, actions, self.TODAY).map {
                    obj(["item": .string(itemRef($0.item)), "reason": .string($0.reason)])
                })
            }
            ask("library.shoppingReason\(suffix)", ALL) {
                var o: [String: J] = [:]
                for r in self.catalogueRows(lists) {
                    let why = shoppingReason(r.item, self.TODAY)
                    if !why.isEmpty { o[r.id] = .string(why) }
                }
                return .object(o)
            }
            ask("library.openShoppingCount\(suffix)", ALL) { jint(openShoppingCount(actions)) }
            ask("library.compareActions\(suffix)", ALL) { jstrings(actions.stableSorted(compare: compareActions).map { $0.id }) }
            ask("library.pruneSuggestions\(suffix)", ALL) {
                .array([1, 2].map { minTrips in
                    .array(pruneSuggestions(lists, minTrips: minTrips).map { p in
                        obj(["listId": .string(p.listId), "item": .string(itemRef(p.item)), "reason": .string(p.reason), "times": jint(p.times)])
                    })
                })
            }
        }
    }

    // --- does this device hold the whole copy? ---------------------------------
    private func askDeviceAudit() {
        let inForce: J = obj([
            "places": .array(PLACES_IN), "owners": .array(OWNERS_IN),
            "conditions": .array(ITEM_CONDITIONS.map { $0.json }), "people": .array(PEOPLE.map { $0.json }),
            "phases": .array(PHASES.map { $0.json }),
        ])
        let referenced = { referencedListValues(lists: self.LISTS, events: self.EVENTS, actions: self.ACTIONS) }
        ask("library.referencedListValues", ALL) {
            let r = referenced()
            var o: [String: J] = [:], display: [String: J] = [:]
            for kind in AUDITABLE_KINDS {
                o[kind] = jset(r[kind])
                var shown: [String: J] = [:]
                for s in r.display[kind] ?? [] { shown[s.key] = .string(s.shown) }
                display[kind] = .object(shown)
            }
            o["display"] = .object(display)
            return .object(o)
        }
        for kind in AUDITABLE_KINDS + ["presets"] {
            ask("library.auditList", kind) { auditList(kind, referenced(), json: inForce[kind]).json }
        }
        ask("library.auditDeviceLists", "signedIn") { auditDeviceLists(referenced: referenced(), json: inForce, signedIn: true, hasCatalogue: true).json }
        ask("library.auditDeviceLists", "signedOut") { auditDeviceLists(referenced: referenced(), json: inForce, signedIn: false, hasCatalogue: true).json }
        ask("library.auditDeviceLists", "emptyLists") {
            let empty: J = ["places": [], "owners": [], "conditions": [], "people": [], "phases": []]
            return auditDeviceLists(referenced: referenced(), json: empty, signedIn: true, hasCatalogue: true).json
        }
    }

    // --- events as a set --------------------------------------------------------
    private func askEventsAsASet() {
        var days = [TODAY]
        for e in EVENTS {
            let end = tripEndDate(e)
            if !end.isEmpty { days += [addDays(end, 0), addDays(end, 1), addDays(end, 30), addDays(end, 31)] }
        }
        let todays = sortedByCodeUnit(distinct(days).filter { !$0.isEmpty })
        let awaiting: ([TripAwaitingReview]) -> J = { rows in
            .array(rows.map { obj(["event": .string($0.event.id), "endedDaysAgo": jint($0.endedDaysAgo)]) })
        }
        for t in todays {
            ask("library.sortEventsForList", t) { jstrings(sortEventsForList(self.EVENTS, t).map { $0.id }) }
            ask("library.tripsAwaitingReview", t) { awaiting(tripsAwaitingReview(self.EVENTS, t)) }
        }
        ask("library.tripsAwaitingReview", "\(TODAY)/window=365") { awaiting(tripsAwaitingReview(self.EVENTS, self.TODAY, 365)) }

        let withPlaces: () -> [TripEvent] = {
            self.EVENTS.enumerated().map { i, ev in
                if eventCoords(ev) != nil { return ev }
                var e = ev
                // quarter-degree coordinates on purpose: toFixed(1) on an exact tie is where runtimes part ways
                let at = 12.25 + Double(i % 2) * 0.5
                e.geo = coerceGeo(json: ["lat": .number(at), "lon": .number(-at), "place": .string(i % 2 == 1 ? "Testville, XX" : "")])
                if i % 2 == 0 { e.destination = "" }   // no label at all, so the pin is keyed by its rounded coordinates
                return e
            }
        }
        let placeShape: (PlacePin?) -> J = { p in
            guard let p = p else { return .null }
            return obj(["key": .string(p.key), "place": .string(p.place), "lat": .number(p.lat), "lon": .number(p.lon),
                        "events": jstrings(p.events.map { $0.id })])
        }
        let cases: [(String, () -> [TripEvent])] = [("", { self.EVENTS }), (".synth", withPlaces)]
        for (suffix, make) in cases {
            ask("library.eventsNeedingCoords\(suffix)", ALL) { jstrings(eventsNeedingCoords(make()).map { $0.id }) }
            ask("library.placesVisited\(suffix)", ALL) { .array(placesVisited(make()).map { placeShape($0) }) }
            ask("library.tripPath\(suffix)", ALL) { .array(tripPath(make()).map { $0.json }) }
            ask("library.mostVisited\(suffix)", ALL) { placeShape(mostVisited(placesVisited(make()))) }
        }
        ask("library.mostVisited.doubled", ALL) { placeShape(mostVisited(placesVisited(withPlaces() + withPlaces()))) }
    }

    // --- backup reminders -----------------------------------------------------------
    private func askBackupReminders() {
        ask("library.backupClock", ALL) {
            obj(["newest": .string(newestChangeAt(self.EVENTS, self.LISTS, self.ACTIONS, self.KITS)),
                 "oldest": .string(oldestCreatedAt(self.EVENTS, self.LISTS, self.ACTIONS, self.KITS))])
        }
        let changedAt = newestChangeAt(EVENTS, LISTS, ACTIONS, KITS)
        let firstUseAt = oldestCreatedAt(EVENTS, LISTS, ACTIONS, KITS)
        let cases: [(String, String)] = [
            ("exportedAt", str(B["exportedAt"])), ("never", ""),
            ("today-13", "\(addDays(TODAY, -13))T08:00:00.000Z"), ("today-14", "\(addDays(TODAY, -14))T08:00:00.000Z"),
            ("today-45", "\(addDays(TODAY, -45))T08:00:00.000Z"), ("date-only", addDays(TODAY, -20)),
            ("future", "\(addDays(TODAY, 3))T08:00:00.000Z"),
        ]
        for (name, lastBackupAt) in cases {
            ask("library.backupState", name) {
                backupState(lastBackupAt: lastBackupAt, changedAt: changedAt, firstUseAt: firstUseAt, hasData: true, now: self.NOW).json
            }
        }
        ask("library.backupState", "noData") {
            backupState(lastBackupAt: "", changedAt: changedAt, firstUseAt: firstUseAt, hasData: false, now: self.NOW).json
        }
        ask("library.backupState", "clock") { backupState(lastBackupAt: "", changedAt: "", firstUseAt: "", hasData: true).json }
    }
}
