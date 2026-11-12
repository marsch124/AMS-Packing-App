import Foundation
import PackingCore

// Trip papers (0.125 — his pick "4" of 12 Nov 2026: "Trip papers: booking confirmations, boarding
// passes and hotel details on the trip page, and they work without internet").
//
// WHERE THEY ARE KEPT. As a thing's papers (Papers.swift): each paper is a record in the photo
// store (`photos` — synced, backed up, kept on the device, so it opens with no internet) and a
// small entry in the trip's `extra` under "papers": [{ id, kind, at, file }]. A PDF (a booking
// confirmation from a mail) is kept as the thing's PDFs are (`data:application/pdf;base64,…`).
// A trip paper counts as in use (`photoInUse`, `photoIdsInUse`), so Worth a look never offers it;
// deleting the trip takes its papers with it. Start again copies none (other bookings next time),
// and a shared trip sends none: they are his tickets.

public let TRIP_PAPERS_KEY = "papers"
/// Papers a trip keeps: twenty — boarding passes out and home for two, a hotel, a car, tickets.
public let TRIP_PAPERS_MAX = 20

/// What a trip paper is. The raw value is what is stored.
public enum TripPaperKind: String, CaseIterable, Sendable {
    case boardingPass, booking, hotel, ticket, insurance, other

    public var label: String {
        switch self {
        case .boardingPass: return "Boarding pass"
        case .booking: return "Booking"
        case .hotel: return "Hotel"
        case .ticket: return "Ticket"
        case .insurance: return "Insurance"
        case .other: return "Other"
        }
    }
}

/// One paper of a trip.
public struct TripPaper: Equatable, Sendable {
    /// The photo record's id.
    public var id: String
    public var kind: TripPaperKind
    /// When it was kept (ISO).
    public var at: String
    /// A kept PDF's name, as the file was called ("" for a photo).
    public var file: String
    public init(id: String, kind: TripPaperKind, at: String, file: String = "") {
        self.id = id; self.kind = kind; self.at = at; self.file = file
    }

    var json: JSONValue {
        var o: [String: JSONValue] = ["id": .string(id), "kind": .string(kind.rawValue), "at": .string(at)]
        if !file.isEmpty { o["file"] = .string(file) }
        return .object(o)
    }

    /// What the row says: "Boarding pass" or "Booking · Hotel Sol".
    public var title: String { file.isEmpty ? kind.label : "\(kind.label) \u{00B7} \(file)" }
}

extension Library {
    /// A trip's papers, in the order kept. Unknown kinds read as Other; rows with no id are skipped.
    public static func tripPapers(_ trip: TripEvent?) -> [TripPaper] {
        guard case .array(let rows)? = trip?.extra[TRIP_PAPERS_KEY] else { return [] }
        return rows.compactMap { row in
            let id = jsStringOr(row["id"])
            guard !id.isEmpty else { return nil }
            return TripPaper(id: id, kind: TripPaperKind(rawValue: jsStringOr(row["kind"])) ?? .other,
                             at: jsStringOr(row["at"]), file: jsStringOr(row["file"]))
        }
    }

    /// The photo ids of a trip's papers — what `photoInUse` counts.
    public static func tripPaperIds(_ trip: TripEvent?) -> [String] { tripPapers(trip).map(\.id) }

    private mutating func setTripPapers(tripId: String, _ list: [TripPaper]) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }) else { return false }
        trips[n].extra[TRIP_PAPERS_KEY] = list.isEmpty ? nil : .array(list.map(\.json))
        trips[n].updatedAt = nowISO()
        return true
    }

    /// A trip's papers with their pictures on this device (nil while one is still on its way).
    public func tripPapersShown(tripId: String) -> [(paper: TripPaper, photo: PhotoRecord?)] {
        Library.tripPapers(trips.first { $0.id == tripId }).map { p in (p, photos.first { $0.id == p.id }) }
    }

    /// Room for one more paper on this trip?
    public func takesTripPaper(tripId: String) -> Bool {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return false }
        return Library.tripPapers(trip).count < TRIP_PAPERS_MAX
    }

    /// Keep a photo (JPEG bytes) as a trip paper. Refused (nil) for no trip, no bytes or a full list.
    @discardableResult
    public mutating func addTripPaper(tripId: String, jpeg: Data, kind: TripPaperKind = .booking) -> TripPaper? {
        guard !jpeg.isEmpty, takesTripPaper(tripId: tripId) else { return nil }
        let at = nowISO()
        let photo = PhotoRecord(id: PackingEnv.makeId(), data: "data:image/jpeg;base64,\(jpeg.base64EncodedString())",
                                createdAt: at)
        photos.append(photo)
        let paper = TripPaper(id: photo.id, kind: kind, at: at)
        _ = setTripPapers(tripId: tripId, Library.tripPapers(trips.first { $0.id == tripId }) + [paper])
        return paper
    }

    /// Keep a PDF (a booking confirmation, an e-ticket) as a trip paper. Refused (nil) for no trip,
    /// a full list, a file that is not a PDF or one over 25 MB.
    @discardableResult
    public mutating func addTripPaperPDF(tripId: String, pdf: Data, name: String,
                                         kind: TripPaperKind = .booking) -> TripPaper? {
        guard pdf.count <= PAPER_PDF_MAX_BYTES, pdf.starts(with: Array("%PDF".utf8)),
              takesTripPaper(tripId: tripId) else { return nil }
        let at = nowISO()
        let photo = PhotoRecord(id: PackingEnv.makeId(), data: "data:\(PDF_MIME);base64,\(pdf.base64EncodedString())",
                                createdAt: at)
        photos.append(photo)
        var file = jsTrim(name)
        if file.lowercased().hasSuffix(".pdf") { file = String(file.dropLast(4)) }
        let paper = TripPaper(id: photo.id, kind: kind, at: at, file: file)
        _ = setTripPapers(tripId: tripId, Library.tripPapers(trips.first { $0.id == tripId }) + [paper])
        return paper
    }

    /// Call a trip paper something else (a booking that is really the hotel).
    @discardableResult
    public mutating func setTripPaperKind(tripId: String, paperId: String, kind: TripPaperKind) -> Bool {
        var list = Library.tripPapers(trips.first { $0.id == tripId })
        guard let k = list.firstIndex(where: { $0.id == paperId }) else { return false }
        list[k].kind = kind
        return setTripPapers(tripId: tripId, list)
    }

    /// Take a paper off a trip; its picture goes too unless something else still shows it.
    @discardableResult
    public mutating func removeTripPaper(tripId: String, paperId: String) -> Bool {
        let list = Library.tripPapers(trips.first { $0.id == tripId })
        guard list.contains(where: { $0.id == paperId }) else { return false }
        _ = setTripPapers(tripId: tripId, list.filter { $0.id != paperId })
        if !photoInUse(paperId) { photos.removeAll { $0.id == paperId } }
        return true
    }

    /// The folded card's line: "Boarding pass ×2 · Hotel" ("" when none).
    public static func tripPapersLine(_ trip: TripEvent?) -> String {
        let list = tripPapers(trip)
        return TripPaperKind.allCases.compactMap { kind in
            let n = list.filter { $0.kind == kind }.count
            return n == 0 ? nil : (n == 1 ? kind.label : "\(kind.label) \u{00D7}\(n)")
        }.joined(separator: " \u{00B7} ")
    }
}
