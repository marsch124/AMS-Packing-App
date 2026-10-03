import Foundation
import PackingCore

// On the trip — his pre-trip ideas 11 and 12 (2 Oct 2026):
//  • A photo of each packed bag, kept with the trip: what went in and how it
//    fitted — the picture to repack from on the way home. Up to three since the
//    field test (3 Oct 2026): "maybe up to three, because sometimes you would like
//    a photo from different angles."
//  • "Bought on site": a thing bought on the trip goes onto its list as it is
//    bought — in hand already, and marked, so the way home packs it too. ("Bought
//    there" until the field test of Oct 2026: "change the word 'there' to 'on site'".)
// Both live in extra keys (the trip's, the line's), so the web app's model is
// untouched; the photo itself is an ordinary photo record, synced like any other.

/// The trip's extra key: `{ "<bag name>": ["<photo id>", …] }`, in the order taken.
/// A trip saved by 0.52 or 0.53 holds ONE id as a plain string; it is read as a list
/// of one, and the next change to that bag writes it as a list.
public let BAG_PHOTOS_KEY = "bagPhotos"
/// The photos a bag keeps at most.
public let BAG_PHOTOS_MAX = 3
/// A line's extra key: true when it was bought on the trip (on site).
/// The STORED key keeps its first name, "boughtThere": lines already marked on his
/// devices, in iCloud and in backups say it, so only the Swift name changed.
public let BOUGHT_ON_SITE_KEY = "boughtThere"

extension Library {
    /// The photo ids one bag's value holds: a list (0.54 on), or the single id 0.52
    /// and 0.53 kept as a string — the migration happens here, on every read.
    static func bagPhotoIds(_ value: JSONValue?) -> [String] {
        if let one = value?.stringValue { return one.isEmpty ? [] : [one] }
        return (value?.arrayValue ?? []).compactMap(\.stringValue).filter { !$0.isEmpty }
    }

    /// The ids of a packed bag's photos on a trip, in the order taken — as stored,
    /// so a photo still on its way from the other device counts too.
    public func bagPhotoIds(tripId: String, bag: String) -> [String] {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return [] }
        return Library.bagPhotoIds(trip.extra[BAG_PHOTOS_KEY]?.objectValue?[bag])
    }

    /// A packed bag's photos on a trip, in the order taken.
    public func bagPhotos(tripId: String, bag: String) -> [PhotoRecord] {
        bagPhotoIds(tripId: tripId, bag: bag).compactMap { id in photos.first { $0.id == id } }
    }

    /// Keep one more photo of the packed bag (JPEG bytes). Refused (nil) when the bag
    /// already has three: the fourth would push one out unseen.
    @discardableResult
    public mutating func addBagPhoto(tripId: String, bag: String, jpeg: Data) -> PhotoRecord? {
        guard let n = trips.firstIndex(where: { $0.id == tripId }), !bag.isEmpty, !jpeg.isEmpty else { return nil }
        var o = trips[n].extra[BAG_PHOTOS_KEY]?.objectValue ?? [:]
        var ids = Library.bagPhotoIds(o[bag])
        guard ids.count < BAG_PHOTOS_MAX else { return nil }
        let photo = PhotoRecord(id: PackingEnv.makeId(), data: "data:image/jpeg;base64,\(jpeg.base64EncodedString())",
                                createdAt: nowISO())
        photos.append(photo)
        ids.append(photo.id)
        o[bag] = .array(ids.map(JSONValue.string))
        trips[n].extra[BAG_PHOTOS_KEY] = .object(o)
        trips[n].updatedAt = nowISO()
        return photo
    }

    /// Take one photo off a packed bag. Its record goes too, unless something else
    /// still shows it; the last one gone leaves no empty entry on the trip.
    @discardableResult
    public mutating func removeBagPhoto(tripId: String, bag: String, photoId: String) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }) else { return false }
        var o = trips[n].extra[BAG_PHOTOS_KEY]?.objectValue ?? [:]
        var ids = Library.bagPhotoIds(o[bag])
        guard let k = ids.firstIndex(of: photoId) else { return false }
        ids.remove(at: k)
        o[bag] = ids.isEmpty ? nil : .array(ids.map(JSONValue.string))
        trips[n].extra[BAG_PHOTOS_KEY] = o.isEmpty ? nil : .object(o)
        trips[n].updatedAt = nowISO()
        if !photoInUse(photoId) { photos.removeAll { $0.id == photoId } }
        return true
    }

    /// Is a photo still shown anywhere — on a thing, on a trip's line, or on a bag
    /// (either way a bag's photos are stored)?
    func photoInUse(_ id: String) -> Bool {
        if items.contains(where: { photoRefs($0).contains(id) }) { return true }
        return trips.contains { t in
            t.entries.contains { photoRefs($0).contains(id) }
                || (t.extra[BAG_PHOTOS_KEY]?.objectValue ?? [:]).values.contains { Library.bagPhotoIds($0).contains(id) }
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
