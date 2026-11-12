import Foundation
import PackingCore

// Papers of a thing (0.119 — inventory step "Papers", his answers of 11 Nov 2026: "Photos with the
// iPhone camera as you go — receipt, delivery note, anything on paper"; "Manuals: link first, a
// stored PDF when wanted").
//
// WHERE THEY ARE KEPT. Each paper is a photo in the photo store (the `photos` table — synced and
// backed up as every photo is; no new record type, no new iCloud field) and a small entry in the
// thing's `extra` under "papers": { id, kind, at }. The thing's own two photos (how it LOOKS) are
// not touched: papers are their own list. The manual's web address is `extra["manualLink"]`.
// `extra` travels through a backup and the web app untouched, so nothing else had to change.
// A paper counts as in use (`photoInUse`, `photoIdsInUse`), so Worth a look never offers it, and
// deleting the thing takes its papers with it. Papers travel in NO share, like a thing's photos.

public let PAPERS_KEY = "papers"
public let MANUAL_LINK_KEY = "manualLink"
/// Papers a thing keeps: twelve — a receipt, a delivery note, a warranty card and a manual of
/// several pages fit, and the thing stays a small record.
public let THING_PAPERS_MAX = 12

/// What a paper is. The raw value is what is stored.
public enum PaperKind: String, CaseIterable, Sendable {
    case receipt, deliveryNote, warrantyCard, manual, other

    public var label: String {
        switch self {
        case .receipt: return "Receipt"
        case .deliveryNote: return "Delivery note"
        case .warrantyCard: return "Warranty card"
        case .manual: return "Manual"
        case .other: return "Other"
        }
    }
}

/// One paper of a thing.
public struct Paper: Equatable, Sendable {
    /// The photo record's id.
    public var id: String
    public var kind: PaperKind
    /// When it was kept (ISO).
    public var at: String
    /// A kept PDF's name, as the file was called ("" for a photo) — 0.121.
    public var file: String
    public init(id: String, kind: PaperKind, at: String, file: String = "") {
        self.id = id; self.kind = kind; self.at = at; self.file = file
    }

    var json: JSONValue {
        var o: [String: JSONValue] = ["id": .string(id), "kind": .string(kind.rawValue), "at": .string(at)]
        if !file.isEmpty { o["file"] = .string(file) }
        return .object(o)
    }
}

extension Library {
    /// A thing's papers, in the order kept. Unknown kinds read as Other; rows with no id are skipped.
    public static func papers(_ it: Item?) -> [Paper] {
        guard case .array(let rows)? = it?.extra[PAPERS_KEY] else { return [] }
        return rows.compactMap { row in
            let id = jsStringOr(row["id"])
            guard !id.isEmpty else { return nil }
            return Paper(id: id, kind: PaperKind(rawValue: jsStringOr(row["kind"])) ?? .other, at: jsStringOr(row["at"]),
                         file: jsStringOr(row["file"]))
        }
    }

    static func setPapers(_ it: inout Item, _ list: [Paper]) {
        it.extra[PAPERS_KEY] = list.isEmpty ? nil : .array(list.map(\.json))
    }

    /// The photo ids of a thing's papers — what `photoInUse` counts.
    public static func paperIds(_ it: Item?) -> [String] { papers(it).map(\.id) }

    /// The manual's web address ("" when none).
    public static func manualLink(_ it: Item) -> String { it.extra[MANUAL_LINK_KEY]?.stringValue ?? "" }
    public static func setManualLink(_ it: inout Item, _ s: String) {
        let t = jsTrim(s); it.extra[MANUAL_LINK_KEY] = t.isEmpty ? nil : .string(t)
    }
    /// The link as a web address to open: "https://" is added when he typed only "sony.com/…".
    public static func manualURL(_ it: Item) -> URL? {
        let t = manualLink(it)
        guard !t.isEmpty, !t.contains(" ") else { return nil }
        let full = t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://") ? t : "https://\(t)"
        guard let url = URL(string: full), url.host?.contains(".") == true else { return nil }
        return url
    }

    /// A thing's papers with their pictures on this device (nil while one is still on its way).
    public func thingPapers(id: String) -> [(paper: Paper, photo: PhotoRecord?)] {
        Library.papers(items.first { $0.id == id }).map { p in (p, photos.first { $0.id == p.id }) }
    }

    /// Room for one more paper?
    public func takesPaper(id: String) -> Bool {
        guard let thing = items.first(where: { $0.id == id }) else { return false }
        return Library.papers(thing).count < THING_PAPERS_MAX
    }

    /// Keep one more paper (JPEG bytes) of a kind. Refused (nil) for no thing, no bytes, or a full list.
    @discardableResult
    public mutating func addPaper(id: String, jpeg: Data, kind: PaperKind = .receipt) -> Paper? {
        guard !jpeg.isEmpty, takesPaper(id: id) else { return nil }
        let at = nowISO()
        let photo = PhotoRecord(id: PackingEnv.makeId(), data: "data:image/jpeg;base64,\(jpeg.base64EncodedString())",
                                createdAt: at)
        photos.append(photo)
        let paper = Paper(id: photo.id, kind: kind, at: at)
        _ = updateThing(id: id) { thing in
            var list = Library.papers(thing); list.append(paper); Library.setPapers(&thing, list)
        }
        return paper
    }

    /// Call a paper something else (a receipt that is really the delivery note).
    @discardableResult
    public mutating func setPaperKind(id: String, paperId: String, kind: PaperKind) -> Bool {
        guard Library.paperIds(items.first { $0.id == id }).contains(paperId) else { return false }
        _ = updateThing(id: id) { thing in
            var list = Library.papers(thing)
            for k in list.indices where list[k].id == paperId { list[k].kind = kind }
            Library.setPapers(&thing, list)
        }
        return true
    }

    /// Take a paper off a thing; its picture goes too unless something else still shows it.
    @discardableResult
    public mutating func removePaper(id: String, paperId: String) -> Bool {
        guard Library.paperIds(items.first { $0.id == id }).contains(paperId) else { return false }
        _ = updateThing(id: id) { thing in
            Library.setPapers(&thing, Library.papers(thing).filter { $0.id != paperId })
        }
        if !photoInUse(paperId) { photos.removeAll { $0.id == paperId } }
        return true
    }

    /// How many papers of each kind a thing has, in the kinds' order — "Receipt · Manual ×2".
    public static func papersLine(_ it: Item?) -> String {
        let list = papers(it)
        return PaperKind.allCases.compactMap { kind in
            let n = list.filter { $0.kind == kind }.count
            return n == 0 ? nil : (n == 1 ? kind.label : "\(kind.label) ×\(n)")
        }.joined(separator: " · ")
    }
}
