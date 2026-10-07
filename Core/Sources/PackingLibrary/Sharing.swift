import Foundation
import PackingCore

// Sharing a trip, a template or a grab list — the web app's share links and QR
// codes (gap list, 2026-09-27). The codes are PackingCore's port of model.js
// (`encodeTripLink`, `encodeListShare`, `encodeGrabShare` and their decoders), so a
// link made here opens in the web app, and a link from the web app opens here.

/// Where the web app lives: a shared link opens there for anyone without this app.
public let SHARE_WEB_BASE = "https://marsch124.github.io/AMS-Packing/"

/// What a pasted link or code turned out to hold.
public enum SharedThing: Equatable {
    case trip(TripEvent)
    case template(SharedList)
    case grab(GrabShare)
}

extension Library {
    /// A trip as a link, or nil when it is too big for one (then share it as a file).
    public func shareLink(tripId: String) -> String? {
        guard let trip = trips.first(where: { $0.id == tripId }),
              let frag = encodeTripLink(Library.justTheList(trip)) else { return nil }
        return SHARE_WEB_BASE + frag
    }

    /// A trip as a file — the web app's "<name>-trip.json", which it can open too.
    public func shareFile(tripId: String) -> (fileName: String, data: Data)? {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return nil }
        let text = buildTripBundle(Library.justTheList(trip)).text(pretty: true)
        return (Library.workbookFileName(trip.name).replacingOccurrences(of: " packing list.xlsx", with: " trip.json"),
                Data(text.utf8))
    }

    /// A template as a link.
    public func shareLink(templateId: String) -> String? {
        guard let list = resolvedTemplate(id: templateId), let code = try? encodeListShare(list) else { return nil }
        return SHARE_WEB_BASE + "#/l/" + code
    }

    /// A grab list as a link.
    public func shareLink(grabId: String) -> String? {
        guard let g = allGrabLists().first(where: { $0.id == grabId }),
              let code = try? encodeGrabShare(name: g.label, icon: g.icon, tone: g.tone, items: g.items) else { return nil }
        return SHARE_WEB_BASE + "#/g/" + code
    }

    /// What a pasted link or code holds — a grab list, a template or a trip, tried in
    /// the web app's order. A whole link, a bare code, or a message with a link in it.
    public static func readShared(_ text: String) -> SharedThing? {
        let t = jsTrim(text)
        guard !t.isEmpty else { return nil }
        if let g = try? decodeGrabShare(t) { return .grab(g) }
        if let l = try? decodeListShare(t) { return .template(l) }
        let code = t.range(of: "#/t/[A-Za-z0-9_.-]+", options: .regularExpression)
            .map { String(t[$0].dropFirst(4)) } ?? t
        if let e = try? decodeTripLink(code) { return .trip(e) }
        return nil
    }

    /// A shared trip becomes a trip of his: new ids, nothing ticked, not reviewed
    /// (parseTripBundle has seen to that) — and none of the sender's own marks, even
    /// from a link made before they stopped travelling.
    ///
    /// It arrives QUICK (the spec pass, 5 Oct 2026): its list is what was sent, and
    /// Trip settings' Save keeps it as it came. Quick means his own always-packed and
    /// transport templates do not pour in on top of it at the first Save; a template he
    /// ticks there adds to it, and picking Full trip brings in the rest — his choice,
    /// in plain sight.
    @discardableResult
    public mutating func importTrip(_ trip: TripEvent) -> TripEvent {
        var t = Library.justTheList(trip)
        t.mode = "quick"
        t.updatedAt = nowISO()
        trips.append(t)
        return t
    }

    /// What a trip's sender keeps to himself (the spec pass, 5 Oct 2026: "a shared trip
    /// carries your private marks and scale readings"): the trip's luggage-scale
    /// readings and its bag photos (only their ids would travel — the photos never
    /// do); a line's "not this time", way-home tick, used up, maintenance note,
    /// bought on site, packing time, the pockets it went into (0.69: his bags are not
    /// theirs) and "changed on the trip". The list itself — its
    /// lines, bags, When, quantities and the trip's answers — goes as it is.
    public static func justTheList(_ trip: TripEvent) -> TripEvent {
        var t = trip
        t.extra[WEIGHED_KEY] = nil
        t.extra[BAG_PHOTOS_KEY] = nil
        // His review and his vault (0.70): what he missed, Apple Health's rows, and the
        // page asked for or written on his Mac are his.
        for key in [MISSED_AT_REVIEW_KEY, TRIP_WORKOUTS_KEY, VAULT_WAITING_KEY, VAULT_WRITTEN_KEY] { t.extra[key] = nil }
        t.entries = t.entries.map { line in
            var l = line
            l.extra[KIT_TICKED_KEY] = nil        // what was ticked inside a kit (ThingKits)
            l.skipped = false
            l.edited = false
            for key in [HOME_KEY, USED_UP_KEY, HOME_NOTE_KEY, BOUGHT_ON_SITE_KEY, "packedAt", POCKET_KEY, HOME_POCKET_KEY] { l.extra[key] = nil }
            return l
        }
        return t
    }

    /// A shared template, as a new one — or in place of one of his with the same
    /// name (keeping its id, so trips still know it). A thing he already has, by
    /// name, is LINKED, not overwritten: his weight, bag, brand, notes — and the way
    /// he spells its name — stay his; only things new to him take the sender's details.
    ///
    /// As a NEW template it needs a name he does not have yet (`named`, else the
    /// sender's): two templates of one name is what Worth a look reads as "two
    /// libraries may have met", and New and Rename refuse it too — so this refuses
    /// it (nil) and the screen asks for another name (the spec pass, 5 Oct 2026).
    ///
    /// REPLACING one of his keeps where his lives — always packed, by transport or
    /// his activity area — so replacing his Hiking with a shared always-packed list
    /// never turns his Hiking into one that every trip packs.
    @discardableResult
    public mutating func importTemplate(_ shared: SharedList, replacing id: String? = nil, named: String? = nil) -> PackList? {
        var partial: [String: JSONValue] = [:]
        let old = id.flatMap { id in templates.first { $0.id == id } }
        if let old {
            partial["id"] = .string(old.id)
            partial["createdAt"] = .string(old.createdAt)
        }
        var list = listFromShare(shared, partial: .object(partial))
        if old == nil, let named, !jsTrim(named).isEmpty { list.name = jsTrim(named) }
        guard !jsTrim(list.name).isEmpty else { return nil }
        if let old {
            list.role = old.role
            list.group = old.group
            list.transport = old.transport
        } else if templateNameTaken(list.name) {
            return nil
        }
        var mine: [String: Item] = [:]
        for i in items where mine[normName(i.name)] == nil { mine[normName(i.name)] = i }
        for n in list.items.indices {
            if let have = mine[normName(list.items[n].name)] {
                list.items[n].itemId = have.id
                list.items[n].link = true
                // A link still carries a name, and the save writes it onto the thing:
                // the sender's "towel" would have renamed his "Towel" (the spec pass).
                list.items[n].name = have.name
            }
        }
        saveTemplate(list)
        return templates.first { $0.id == list.id }
    }

    /// The template of his with this name, if any — offered as "Replace".
    public func templateNamed(_ name: String) -> PackList? {
        let want = normName(name)
        return templates.first { $0.role.isEmpty && normName($0.name) == want }
    }

    /// A shared grab list is a NEW list: it takes a free place on Home when there is
    /// one, and waits in Grab Lists only while Home is full. A drawing or a colour
    /// this app does not have becomes the standard look a list made here gets — its
    /// initial, in blue — instead of the runner and the slate grey it was drawn in
    /// until 5 Oct 2026.
    @discardableResult
    public mutating func importGrab(_ g: GrabShare) -> GrabDefinition? {
        addGrabList(label: g.name.isEmpty ? "Shared" : g.name, tone: GRAB_TONES.contains(g.tone) ? g.tone : "blue",
                    icon: GRAB_ICONS.contains(g.icon) ? g.icon : "", items: g.items)
    }
}
