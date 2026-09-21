import Foundation
import PackingCore

// Library ⇄ records. The ONLY place that knows how the library is cut into records.

extension Library {
    static let entryOrderKey = "entryOrder"

    static func entryKey(_ tripId: String, _ entryId: String) -> String { "\(tripId)|\(entryId)" }

    /// The whole library as records. Deterministic, so two calls on equal libraries
    /// differ in nothing but `updatedAt` — which `recordChanges` ignores.
    public func records(at now: Date = PackingEnv.now()) -> [StoredRecord] {
        var out: [StoredRecord] = []
        func add(_ t: Table, _ key: String, _ json: JSONValue, parent: String = "", blob: Data? = nil) {
            guard !key.isEmpty else { return }
            out.append(StoredRecord(table: t, key: key, parent: parent, json: json, blob: blob, updatedAt: now))
        }
        for i in items { add(.items, i.id, i.json) }
        for m in memberships { add(.memberships, m.id, m.json, parent: m.templateId) }
        for t in templates {
            var bare = t; bare.items = []
            add(.templates, t.id, bare.json)
        }
        for trip in trips {
            var head = trip; head.entries = []
            var o = head.json.objectValue ?? [:]
            o["entries"] = nil
            // The order of the lines is the trip's; the lines themselves are their own
            // records. A line missing from this list (added on the other device while
            // this one saved the head) is not lost — it is appended on load.
            o[Library.entryOrderKey] = .array(trip.entries.map { .string($0.id) })
            add(.trips, trip.id, .object(o))
            for e in trip.entries { add(.entries, Library.entryKey(trip.id, e.id), e.json, parent: trip.id) }
        }
        for a in actions { add(.actions, a.id, a.json) }
        for k in kits { add(.kits, k.id, k.json) }
        for p in phases { add(.phases, p.id, p.json) }
        for r in shared { add(.shared, r.id, r.json) }
        for p in photos {
            let (bytes, mime) = Library.bytes(fromDataURL: p.data)
            add(.photos, p.id, ["id": .string(p.id), "createdAt": .string(p.createdAt), "mime": .string(mime)], blob: bytes)
        }
        for (k, v) in meta { add(.meta, k, v) }
        return out
    }

    /// A library from whatever the store holds. Never fails: decoding is coercion,
    /// duplicates are settled by rule, and a line whose trip has not arrived yet is
    /// simply not shown until it has.
    public init(records all: [StoredRecord]) {
        self.init()
        let records = settleDuplicates(all).kept.sorted { $0.id < $1.id }
        var entriesByTrip: [String: [(key: String, entry: Item)]] = [:]
        var heads: [(trip: TripEvent, order: [String])] = []
        for r in records {
            switch r.table {
            case .items: items.append(Item(json: r.json))
            case .memberships: memberships.append(Membership(json: r.json))
            case .templates:
                var t = PackList(json: r.json); t.items = []
                templates.append(t)
            case .trips:
                var o = r.json.objectValue ?? [:]
                let order = (o[Library.entryOrderKey]?.arrayValue ?? []).compactMap(\.stringValue)
                o[Library.entryOrderKey] = nil
                heads.append((TripEvent(json: .object(o)), order))
            case .entries:
                entriesByTrip[r.parent, default: []].append((r.key, Item(json: r.json)))
            case .actions: actions.append(ActionItem(json: r.json))
            case .kits: kits.append(Kit(json: r.json))
            case .phases: phases.append(Phase(json: r.json))
            case .shared: shared.append(SharedRow(json: r.json))
            case .photos:
                let mime = r.json["mime"]?.stringValue ?? "image/jpeg"
                let data = r.blob.map { "data:\(mime);base64,\($0.base64EncodedString())" } ?? ""
                photos.append(PhotoRecord(json: ["id": .string(r.key), "data": .string(data),
                                                 "createdAt": r.json["createdAt"] ?? .string("")]))
            case .meta: meta[r.key] = r.json
            }
        }
        for (head, order) in heads {
            var trip = head
            let mine = entriesByTrip[trip.id] ?? []
            var byId: [String: Item] = [:]
            for e in mine { byId[e.entry.id] = e.entry }
            var lines: [Item] = []
            var placed = Set<String>()
            for id in order { if let e = byId[id], placed.insert(id).inserted { lines.append(e) } }
            for e in mine.sorted(by: { $0.key < $1.key }) where placed.insert(e.entry.id).inserted { lines.append(e.entry) }
            trip.entries = lines
            trips.append(trip)
        }
        phases = phases.stableSorted(compare: { a, b in jsOr(jsSign(a.order - b.order), jsLocaleCompare(a.id, b.id)) })
    }

    /// "data:image/jpeg;base64,…" → its bytes and its type. Anything else → no bytes.
    static func bytes(fromDataURL s: String) -> (Data?, String) {
        guard s.hasPrefix("data:"), let comma = s.firstIndex(of: ",") else { return (nil, "image/jpeg") }
        let header = s[s.index(s.startIndex, offsetBy: 5)..<comma]
        let mime = header.split(separator: ";").first.map(String.init) ?? "image/jpeg"
        guard header.contains("base64") else { return (nil, mime) }
        return (Data(base64Encoded: String(s[s.index(after: comma)...])), mime.isEmpty ? "image/jpeg" : mime)
    }
}
