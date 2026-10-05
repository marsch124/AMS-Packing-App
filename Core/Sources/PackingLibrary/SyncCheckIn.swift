import Foundation
import PackingCore

// Sync now — his field test, 3 Oct 2026 ("we need to get the sync going"): each
// device can check in, and the OTHER device then shows when it last heard from it.
// A check-in is one small note in the library's meta records, so it travels the way
// everything else does: seeing the iPhone's check-in on the Mac proves the road from
// the iPhone to the Mac is open, and the other way round.

/// The meta key a device checks in under: "syncCheck.iPhone", "syncCheck.Mac".
public func syncCheckKey(_ device: String) -> String { "syncCheck." + device }

extension Library {
    /// Check in from this device now.
    public mutating func checkIn(device: String, at iso: String = nowISO()) {
        meta[syncCheckKey(device)] = .object(["at": .string(iso), "device": .string(device)])
    }

    /// When a device last checked in — ISO time, or nil if it never has.
    public func lastCheckIn(device: String) -> String? {
        guard let at = meta[syncCheckKey(device)]?.objectValue?["at"]?.stringValue, !at.isEmpty else { return nil }
        return at
    }
}

extension Library {
    /// A note about a DEVICE, not about his things: a device's check-in (Sync now).
    ///
    /// Such a note is no sign that this library holds anything (the spec pass,
    /// 2026-10-05): one press of Sync now on a new, empty device — or the other
    /// device's check-in arriving through iCloud — made the library "not empty", so
    /// the two first-run doors went away and the backup was refused as "already
    /// imported into".
    public static func isDeviceNote(_ key: String) -> Bool { key.hasPrefix(syncCheckKey("")) }

    /// This library, with the devices' check-ins of `other` laid over it. An import
    /// or a restore replaces his LIBRARY; the check-ins say when each device last
    /// came by, and a restore that deleted them told the other device, through
    /// iCloud, that it had never checked in.
    public func keepingDeviceNotes(of other: Library) -> Library {
        var lib = self
        for (key, value) in other.meta where Library.isDeviceNote(key) { lib.meta[key] = value }
        return lib
    }
}
