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
