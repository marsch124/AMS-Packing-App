import Foundation
import PackingCore

// On the trip — his pre-trip ideas 11 and 12 (2 Oct 2026):
//  • A photo of each packed bag, kept with the trip: what went in and how it
//    fitted — the picture to repack from on the way home.
//  • "Bought on site": a thing bought on the trip goes onto its list as it is
//    bought — in hand already, and marked, so the way home packs it too. ("Bought
//    there" until the field test of Oct 2026: "change the word 'there' to 'on site'".)
// Both live in extra keys (the trip's, the line's), so the web app's model is
// untouched; the photo itself is an ordinary photo record, synced like any other.

/// The trip's extra key: `{ "<bag name>": "<photo id>" }`.
public let BAG_PHOTOS_KEY = "bagPhotos"
/// A line's extra key: true when it was bought on the trip (on site).
/// The STORED key keeps its first name, "boughtThere": lines already marked on his
/// devices, in iCloud and in backups say it, so only the Swift name changed.
public let BOUGHT_ON_SITE_KEY = "boughtThere"

extension Library {
    /// The photo of a packed bag on a trip, if there is one.
    public func bagPhoto(tripId: String, bag: String) -> PhotoRecord? {
        guard let trip = trips.first(where: { $0.id == tripId }),
              let id = trip.extra[BAG_PHOTOS_KEY]?.objectValue?[bag]?.stringValue, !id.isEmpty else { return nil }
        return photos.first { $0.id == id }
    }

    /// Keep a photo of the packed bag (JPEG bytes), or take it away (nil). A photo
    /// it replaces goes too, unless something else still shows it.
    @discardableResult
    public mutating func setBagPhoto(tripId: String, bag: String, jpeg: Data?) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }), !bag.isEmpty else { return false }
        var o = trips[n].extra[BAG_PHOTOS_KEY]?.objectValue ?? [:]
        let old = o[bag]?.stringValue
        if let jpeg, !jpeg.isEmpty {
            let photo = PhotoRecord(id: PackingEnv.makeId(), data: "data:image/jpeg;base64,\(jpeg.base64EncodedString())",
                                    createdAt: nowISO())
            photos.append(photo)
            o[bag] = .string(photo.id)
        } else {
            o[bag] = nil
        }
        trips[n].extra[BAG_PHOTOS_KEY] = o.isEmpty ? nil : .object(o)
        trips[n].updatedAt = nowISO()
        if let old, !photoInUse(old) { photos.removeAll { $0.id == old } }
        return true
    }

    /// Is a photo still shown anywhere — on a thing, on a trip's line, or as a bag?
    func photoInUse(_ id: String) -> Bool {
        if items.contains(where: { photoRefs($0).contains(id) }) { return true }
        return trips.contains { t in
            t.entries.contains { photoRefs($0).contains(id) }
                || (t.extra[BAG_PHOTOS_KEY]?.objectValue ?? [:]).values.contains { $0.stringValue == id }
        }
    }

    /// A thing bought on the trip: onto this trip's list, ticked (it is in hand),
    /// marked bought on site.
    @discardableResult
    public mutating func addBoughtOnSite(tripId: String, name: String) -> Item? {
        guard let line = addCustomLine(tripId: tripId, name: name),
              let t = trips.firstIndex(where: { $0.id == tripId }),
              let k = trips[t].entries.firstIndex(where: { $0.id == line.id }) else { return nil }
        trips[t].entries[k].checked = true
        trips[t].entries[k].extra[BOUGHT_ON_SITE_KEY] = .bool(true)
        return trips[t].entries[k]
    }

    public static func isBoughtOnSite(_ line: Item) -> Bool { line.extra[BOUGHT_ON_SITE_KEY]?.boolValue == true }

    /// What was bought on a trip, in the order bought.
    public func boughtOnSite(tripId: String) -> [Item] {
        trips.first { $0.id == tripId }?.entries.filter(Library.isBoughtOnSite) ?? []
    }
}
