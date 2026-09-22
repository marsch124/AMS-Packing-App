import Foundation
import PackingCore
import PackingLibrary

/// A copy of the library, written to this device BEFORE anything replaces it.
///
/// He has lost data to a restore before (the web app, 2026-08-16), so a restore
/// here keeps a way back that does not depend on him having thought to save a
/// file first. The copy is the ordinary backup JSON — either app can read it.
/// It is written before the destructive write, never after, and the newest three
/// are kept.
enum RescueCopies {
    static let keep = 3

    static var folder: URL? {
        guard let base = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                      in: .userDomainMask, appropriateFor: nil, create: true)
        else { return nil }
        return base.appendingPathComponent("AMS Packing/rescue", isDirectory: true)
    }

    /// Write what the library holds now. An empty library is not worth keeping, so
    /// nothing is written for one — and nothing is deleted either.
    @discardableResult
    static func write(_ library: Library, at moment: String = nowISO()) throws -> URL? {
        guard !library.isEmpty, let dir = folder else { return nil }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = moment.replacingOccurrences(of: ":", with: "-")
        let url = dir.appendingPathComponent("before-restore-\(stamp).json")
        try library.backupData(exportedAt: moment).write(to: url)
        prune(dir)
        return url
    }

    /// The copies on this device, newest first.
    static func all() -> [URL] {
        guard let dir = folder,
              let found = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return [] }
        return found.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// What a copy holds, as bytes — read back through the same door as any other
    /// backup file, so a copy that cannot be read is caught like any other.
    static func read(_ url: URL) -> Data? { try? Data(contentsOf: url) }

    /// The moment a copy was written, as it should be read out: "22 September, 23:04".
    static func when(_ url: URL) -> String {
        let stamp = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "before-restore-", with: "")
        // 2026-09-22T23-04-11.123Z → 22 September, 23:04
        let parts = stamp.split(separator: "T")
        guard parts.count == 2 else { return stamp }
        let day = parts[0].split(separator: "-"), clock = parts[1].split(separator: "-")
        guard day.count == 3, clock.count >= 2, let month = Int(day[1]) else { return stamp }
        let months = ["January", "February", "March", "April", "May", "June", "July",
                      "August", "September", "October", "November", "December"]
        let name = (1...12).contains(month) ? months[month - 1] : String(day[1])
        return "\(Int(day[2]) ?? 0) \(name), \(clock[0]):\(clock[1])"
    }

    /// Under the UI tests the copies are cleared at launch — the same folder and
    /// the same code as ever, just emptied, so a test can count what a restore
    /// wrote instead of finding yesterday's copies.
    static func clearForTesting() {
        for old in all() { try? FileManager.default.removeItem(at: old) }
    }

    private static func prune(_ dir: URL) {
        for old in all().dropFirst(keep) { try? FileManager.default.removeItem(at: old) }
    }
}
