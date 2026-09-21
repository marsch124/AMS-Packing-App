// TripBuilding — how a trip's Total List is made: which building-block items belong
// on this trip, which lists feed it, the combined de-duplicated list, and the
// regenerate that keeps the user's own edits.
// Ported from js/model.js ("Filtering", "Total List generation").

import Foundation

// MARK: - Filtering: does a building-block item belong in this event?
// An empty constraint array means "applies to any value" for that dimension.

// (Not exported by the JS module, so not public here either.)
func dimOk(_ itemVals: [String], _ eventVal: String?) -> Bool {
    if itemVals.isEmpty { return true }                         // no constraint -> always applies
    guard let ev = eventVal, !ev.isEmpty else { return true }
    return itemVals.contains(ev)
}
func contextsOk(_ itemContexts: [String], _ eventContexts: [String]) -> Bool {
    if itemContexts.isEmpty { return true }
    if eventContexts.isEmpty { return true }                    // event didn't pin a context -> keep
    return itemContexts.contains { eventContexts.contains($0) }
}

/// The event's Context (Indoor / Outdoor / Race) only narrows items that belong to
/// a WET list. `list` is the building-block list the item came from; when it isn't
/// a WET list (or isn't given), context is ignored and the item always applies.
public func contextApplies(_ list: PackList?) -> Bool {
    guard let list = list else { return false }
    return list.group == "WET"
}

public func itemMatchesEvent(_ item: Item, _ event: TripEvent, _ list: PackList? = nil) -> Bool {
    dimOk(item.seasons, event.season)
        && dimOk(item.transports, event.transport)
        && dimOk(item.catering, event.catering)
        && (contextApplies(list) ? contextsOk(item.contexts, event.contexts) : true)
}

// MARK: - Total List generation

/// The display name of a section id within a template's `sections` ('' if none/unknown).
public func sectionName(_ list: PackList?, _ sectionId: String?) -> String {
    guard let sid = sectionId, !sid.isEmpty, let list = list else { return "" }
    return list.sections.first { $0.id == sid }?.name ?? ""
}

/// Turn a building-block item into an editable Total-List entry.
/// ONLY the fields named here cross over — everything else on the entry is
/// `coerceItem`'s answer for a missing field (no photos, no care record, zero stats,
/// no descriptive metadata), exactly as the JS builds it.
/// (Not exported by the JS module, so not public here either.)
func entryFromItem(_ item: Item, _ list: PackList?) -> Item {
    coerceItem(Item(
        id: PackingEnv.makeId(),
        name: item.name,
        swedish: item.swedish,
        qty: item.qty,
        category: item.category.isEmpty ? CATEGORY_DEFAULT : item.category,
        container: item.container,
        phase: item.phase,
        itemType: item.itemType.isEmpty ? "item" : item.itemType,
        charging: item.charging,
        chargeType: item.chargeType,
        shortList: item.shortList,
        // constraints are irrelevant once materialised, but keep shape stable
        seasons: [], contexts: [], transports: [], catering: [], weather: [],
        sub: item.sub,
        note: item.note,
        weight: item.weight.isFinite ? item.weight : 0,
        liquid: item.liquid,
        restricted: item.restricted,
        perNight: item.perNight,
        section: sectionName(list, item.section),   // resolved to the DISPLAY NAME so sections merge by name across templates
        kit: item.kit,                              // kit name carried onto the trip so the packing list can cluster kit-mates
        packer: item.packer,                        // the item's standing packer becomes this trip's, still changeable per trip
        storage: item.storage,                      // carried onto the trip so packing shows where to grab it
        sourceListId: list?.id,
        sourceItemId: item.id,
        custom: false,
        checked: false
    ))
}

/// The building-block lists that feed a trip's Total List, in dedup-priority order:
///  1. every always-on base list (role 'base') — the common core of any trip,
///  2. the one transport list matching the trip's transport (role 'transport'),
///  3. the GA/WET activity lists the user ticked, in the order they picked them.
/// Earlier lists win on a name+container clash, so the common base takes priority.
/// (A list with any other role — the retired loose bin, the Containers catalogue —
/// is never tickable, so it can never feed a trip even if its id is in `activities`.)
public func listsForEvent(_ event: TripEvent, _ lists: [PackList]) -> [PackList] {
    let all = lists.map { coerceList($0) }
    var tickable: [String: PackList] = [:]                       // a repeated id: the last one wins, as a JS Map
    for l in all where l.role.isEmpty { tickable[l.id] = l }
    let ticked = event.activities.compactMap { tickable[$0] }
    // Quick mode: just the ticked activity lists — no common base, no transport kit.
    // (Items are still narrowed by the trip's Indoor/Outdoor context, season, etc.)
    let chosen: [PackList] = event.mode == "quick"
        ? ticked
        : all.filter { $0.role == "base" }
            + all.filter { $0.role == "transport" && $0.transport == event.transport }
            + ticked
    var out: [PackList] = []
    var seen = Set<String>()
    for l in chosen {
        if seen.contains(l.id) { continue }
        seen.insert(l.id)
        out.append(l)
    }
    return out
}

/// Build the raw combined list from the chosen building blocks, de-duplicated by
/// name+container (the first source wins; keep it simple & predictable).
public func buildTotalEntries(_ event: TripEvent, _ lists: [PackList]) -> [Item] {
    var seen = Set<String>()
    var out: [Item] = []
    for list in listsForEvent(event, lists) {
        for item in list.items {
            if jsTrim(item.name).isEmpty { continue }
            if item.retired { continue }   // "Not in use" — kept on record but never packed
            if !itemMatchesEvent(item, event, list) { continue }
            // Weather-conditional gear is normally held back (offered via the forecast).
            // But a trip can "force on" conditions (event.weatherOn) to pack that gear as a
            // precaution regardless of the forecast — e.g. cold-weather kit on a summer trip.
            let wtags = item.weather
            if !wtags.isEmpty && !wtags.contains(where: { event.weatherOn.contains($0) }) { continue }
            let key = "\(normName(item.name))|\(item.container)"
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append(entryFromItem(item, list))
        }
    }
    return out
}

/// Regenerate while preserving the user's manual edits:
///  - custom (manually added) entries are always kept
///  - entries the user edited or checked are kept as-is (matched by source item id)
///  - brand-new matching items are appended
///  - source items that no longer match are dropped (unless edited/checked/custom)
public func regenerateEntries(_ event: TripEvent, _ lists: [PackList]) -> [Item] {
    let fresh = buildTotalEntries(event, lists)
    let prev = event.entries
    var prevBySource: [String: Item] = [:]                       // a repeated source id: the last one wins
    for e in prev { if let sid = e.sourceItemId, !sid.isEmpty { prevBySource[sid] = e } }

    var out: [Item] = []
    var usedSources = Set<String>()
    for f in fresh {
        if let sid = f.sourceItemId, !sid.isEmpty, let existing = prevBySource[sid] {
            out.append(existing)
            usedSources.insert(sid)
        } else {
            out.append(f)
        }
    }
    // Keep anything the user added or touched that the fresh build didn't cover.
    for e in prev {
        if e.custom { out.append(e); continue }
        if let sid = e.sourceItemId, !sid.isEmpty, !usedSources.contains(sid), e.checked || e.edited { out.append(e) }
    }
    return out
}
