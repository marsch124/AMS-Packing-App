// §6 Setup state · §7 Coercion — whole objects · §8 Per list

import Foundation
import PackingCore

extension Parity {

    // === §6 Setup state ======================================================
    func askSetupState() {
        ask("setup.phases", ALL) {
            obj(["phases": .array(PHASES.map { shapePhase($0) }), "ids": jstrings(PHASE_IDS),
                 "customised": .bool(phasesCustomised()), "defaultPhaseId": .string(defaultPhaseId())])
        }
        ask("setup.conditions", ALL) {
            obj(["conditions": .array(ITEM_CONDITIONS.map { shapeCondition($0) }), "ids": jstrings(ITEM_CONDITION_IDS)])
        }
        ask("setup.people", ALL) { .array(self.PEOPLE.map { shapePerson($0) }) }
        for (i, p) in rawPhases.enumerated() { ask("coerce.phase", String(i)) { shapePhase(coercePhase(json: p, i)) } }
        for (i, c) in CONDITIONS_IN.enumerated() { ask("coerce.condition", String(i)) { shapeCondition(coerceCondition(json: c)) } }
        for (i, p) in PEOPLE_IN.enumerated() {
            ask("coerce.person", String(i)) {
                let minted = nonEmptyString(p["id"]) == nil
                // `coercePerson({ ...p })` — anything that is not an object is `{}` here.
                let person = coercePerson(json: p.objectValue != nil ? p : [:])
                return person.map { shapePerson($0, minted: minted) }
            }
        }
    }

    // === §7 Coercion — whole objects =========================================
    // Input is the RAW object from the backup, not the coerced one.
    func askCoercion() {
        for (i, raw) in rawLists.enumerated() {
            ask("coerce.list", rawKey(raw, i)) {
                // a section that arrived without an id has one minted: write that one down by position
                let known = Set(asArr(raw["sections"]).compactMap { nonEmptyString($0["id"]) })
                guard let c = coerceList(json: raw) else { return raw }
                var minted: [String: String] = [:]
                for (j, s) in c.sections.enumerated() where !known.contains(s.id) { minted[s.id] = "S\(j)" }
                return shapeList(c, ShapeMap(sectionId: { minted[$0] ?? $0 }))
            }
        }
        for (i, raw) in rawEvents.enumerated() {
            ask("coerce.event", rawKey(raw, i)) { coerceEvent(json: raw).map { shapeEvent($0) } ?? raw }
        }
        for (i, raw) in rawActions.enumerated() {
            ask("coerce.action", rawKey(raw, i)) {
                guard let a = coerceAction(json: raw) else { return raw }
                var o = shapeAction(a)
                if raw["createdAt"]?.stringValue == nil {
                    o["createdAt"] = .string(NOWMARK)
                    if raw["updatedAt"]?.stringValue == nil { o["updatedAt"] = .string(NOWMARK) }
                }
                return o
            }
        }
        for (i, raw) in rawKits.enumerated() {
            ask("coerce.kit", rawKey(raw, i)) { coerceKit(json: raw).map { shapeKit($0) } ?? raw }
        }
        for (i, raw) in rawThings.enumerated() {
            ask("coerce.thing", rawKey(raw, i)) { coerceItem(json: raw).map { shapeItem($0) } ?? raw }
        }
    }

    // === §8 Per list =========================================================
    func askLists() {
        for (i, l) in LISTS.enumerated() {
            let k = listKey(l, i)
            ask("list.cover", k) {
                // `listColor({ id, name })` / `listColor({ name })`: a list with no colour of its own
                let byId = PackList(id: l.id, name: l.name, color: "")
                let byName = PackList(id: "", name: l.name, color: "")
                return obj([
                    "emoji": .string(listEmoji(l)), "color": .string(listColor(l)),
                    "hashedById": .string(listColor(byId)), "hashedByName": .string(listColor(byName)),
                    "contextApplies": .bool(contextApplies(l)), "defaults": templateDefaults(l).json,
                    "groupLabel": .string(groupLabel(l.group)),
                ])
            }
            ask("list.sectionNames", k) { jstrings(l.items.map { sectionName(l, $0.section) }) }
            ask("list.groupItemsBySection", k) {
                .array(groupItemsBySection(l.items, l.sections).map { g in
                    obj(["section": g.section.map { shapeSection($0) } ?? .null, "items": jstrings(g.items.map(itemRef))])
                })
            }
            ask("list.photos", k) {
                obj(["hasInline": .bool(hasInlinePhotos(l.items)),
                     "refs": jint(l.items.reduce(0) { $0 + photoRefs($1).count }),
                     "inline": jint(l.items.reduce(0) { $0 + inlinePhotos($1).count })])
            }
            // Share round trip: the code itself, what it decodes to, and the template it becomes.
            var code: String? = nil
            ask("list.share.encoded", k) { code = try encodeListShare(l); return code.map { .string($0) } }
            guard let code = code else { continue }
            ask("list.share.decoded", k) { try decodeListShare("https://example.invalid/app/#/l/\(code)").json }
            ask("list.share.addressInside", k) { .bool(addressInside(try unpackShare(code))) }
            ask("list.share.imported", k) {
                let made = listFromShare(try decodeListShare(code))
                var secIds: [String: String] = [:]
                for (j, s) in made.sections.enumerated() { secIds[s.id] = "S\(j)" }
                return shapeList(made, ShapeMap(
                    id: { _ in ID }, section: { $0.isEmpty ? "" : (secIds[$0] ?? $0) },
                    sectionId: { secIds[$0] ?? $0 }, listId: { _ in ID }, stamps: true))
            }
        }
    }
}
