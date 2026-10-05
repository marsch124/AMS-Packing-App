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
        guard let trip = trips.first(where: { $0.id == tripId }), let frag = encodeTripLink(trip) else { return nil }
        return SHARE_WEB_BASE + frag
    }

    /// A trip as a file — the web app's "<name>-trip.json", which it can open too.
    public func shareFile(tripId: String) -> (fileName: String, data: Data)? {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return nil }
        let text = buildTripBundle(trip).text(pretty: true)
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
    /// (parseTripBundle has seen to that).
    @discardableResult
    public mutating func importTrip(_ trip: TripEvent) -> TripEvent {
        var t = trip
        t.updatedAt = nowISO()
        trips.append(t)
        return t
    }

    /// A shared template, as a new one — or in place of one of his with the same
    /// name (keeping its id, so trips still know it). A thing he already has, by
    /// name, is LINKED, not overwritten: his weight, bag, brand and notes stay his;
    /// only things new to him take the sender's details.
    @discardableResult
    public mutating func importTemplate(_ shared: SharedList, replacing id: String? = nil) -> PackList? {
        var partial: [String: JSONValue] = [:]
        if let id, let old = templates.first(where: { $0.id == id }) {
            partial["id"] = .string(old.id)
            partial["createdAt"] = .string(old.createdAt)
        }
        var list = listFromShare(shared, partial: .object(partial))
        guard !jsTrim(list.name).isEmpty else { return nil }
        var mine: [String: String] = [:]
        for i in items where mine[normName(i.name)] == nil { mine[normName(i.name)] = i.id }
        for n in list.items.indices {
            if let have = mine[normName(list.items[n].name)] {
                list.items[n].itemId = have
                list.items[n].link = true
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
