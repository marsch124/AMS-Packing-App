import Foundation
import PackingCore

// Photos of a thing (0.90 — his ask of 19 Oct 2026: "A photo or two for each item").
//
// WHERE THEY ARE KEPT. Nothing new: the thing's own `photos` — ids into the photo store, as
// the web model keeps every thing's photos (up to MAX_PHOTOS) — exactly as a bag's own photos
// have been since 0.80 (BagDetails.swift: a bag IS a thing, and those are these). So a thing's
// photos are synced as every photo is (the `photos` table; the iCloud fields that carry a
// picture's bytes are deployed already — no new field, no new record type), saved in a backup
// and put back by a restore (a backup holds every photo record and every thing's ids), follow
// a rename (they live on the thing, whose id a rename keeps), are counted in use (`photoInUse`:
// Worth a look never offers them), and travel in NO share (a shared template, trip or grab list
// leaves photos behind, and a trip's line never copies a thing's photos — `entryFromItem`).
// Not in the Excel export (no photo is) nor on the trip's page in Obsidian (only the packed
// bags' photos are, as for a bag's own photos).
//
// HOW MANY. Two, his words "a photo or two" — the same two a bag's page takes of the bag
// (`BAG_OWN_PHOTOS_MAX`), and they are the same photos when the thing is a bag. A thing that
// came with more (the web app took up to MAX_PHOTOS) shows them all and takes no new one.

/// The photos a thing's page takes: two.
public let THING_PHOTOS_MAX = 2

extension Library {
    /// A thing's photo ids, in the order taken, as stored — one still on its way from the other
    /// device counts. None for an id that is no thing.
    public func thingPhotoIds(id: String) -> [String] {
        photoRefs(items.first { $0.id == id })
    }

    /// A thing's photos on this device, in the order taken.
    public func thingPhotos(id: String) -> [PhotoRecord] {
        let ids = thingPhotoIds(id: id)
        guard !ids.isEmpty else { return [] }
        return ids.compactMap { pid in photos.first { $0.id == pid } }
    }

    /// Its first photo on this device — the small one beside it in Your things and Search.
    public func firstThingPhoto(id: String) -> PhotoRecord? {
        guard let first = thingPhotoIds(id: id).first(where: { pid in photos.contains { $0.id == pid } }) else { return nil }
        return photos.first { $0.id == first }
    }

    /// Has it room for one more on its page?
    public func takesThingPhoto(id: String) -> Bool {
        guard let thing = items.first(where: { $0.id == id }) else { return false }
        return photoRefs(thing).count < THING_PHOTOS_MAX && thing.photos.count < MAX_PHOTOS
    }

    /// Keep one more photo of a thing (JPEG bytes) — onto its own `photos`. Refused (nil) for an
    /// id that is no thing, for no bytes, and when it has `THING_PHOTOS_MAX` already (or is full
    /// in the web model's terms, MAX_PHOTOS): a third would push one out unseen.
    @discardableResult
    public mutating func addThingPhoto(id: String, jpeg: Data) -> PhotoRecord? {
        guard !jpeg.isEmpty, takesThingPhoto(id: id) else { return nil }
        let photo = PhotoRecord(id: PackingEnv.makeId(), data: "data:image/jpeg;base64,\(jpeg.base64EncodedString())",
                                createdAt: nowISO())
        photos.append(photo)
        _ = updateThing(id: id) { $0.photos.append(photo.id) }
        return photo
    }

    /// Take one photo off a thing. Its record goes too, unless something else still shows it.
    /// The web app's small `thumb` is of the FIRST photo: taking that one away clears it.
    @discardableResult
    public mutating func removeThingPhoto(id: String, photoId: String) -> Bool {
        guard thingPhotoIds(id: id).contains(photoId) else { return false }
        _ = updateThing(id: id) { thing in
            if thing.photos.first == photoId { thing.thumb = "" }
            thing.photos.removeAll { $0 == photoId }
        }
        if !photoInUse(photoId) { photos.removeAll { $0.id == photoId } }
        return true
    }

    /// A deleted thing's photos: each record goes unless something else still shows it (0.90 —
    /// until then they stayed behind for Worth a look, which called them "left behind by a
    /// deleted trip").
    mutating func dropPhotos(of gone: [String]) {
        for pid in gone where !photoInUse(pid) { photos.removeAll { $0.id == pid } }
    }
}
