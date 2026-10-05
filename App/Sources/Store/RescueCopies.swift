import Foundation
import PackingCore
import PackingLibrary

/// A copy of the library, written to this device BEFORE anything replaces it.
///
/// He has lost data to a restore before (the web app, 2026-08-16), so a restore
/// here keeps a way back that does not depend on him having thought to save a
/// file first. The copy is the ordinary backup JSON — either app can read it.
/// It is written before the destructive write, never after, and the newest three
/// are kept. How copies are named, read out and pruned: `RescueNames` (the model).
enum RescueCopies {

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
        let url = dir.appendingPathComponent(RescueNames.fileName(at: moment))
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

    /// The moment a copy was written, as it should be read out: "22 September, 23:04",
    /// in this device's own time.
    static func when(_ url: URL) -> String { RescueNames.when(fileName: url.lastPathComponent) }

    /// Under the UI tests the copies are cleared at launch — the same folder and
    /// the same code as ever, just emptied, so a test can count what a restore
    /// wrote instead of finding yesterday's copies.
    static func clearForTesting() {
        for old in all() { try? FileManager.default.removeItem(at: old) }
    }

    private static func prune(_ dir: URL) {
        let gone = Set(RescueNames.toRemove(all().map(\.lastPathComponent)))
        for old in all() where gone.contains(old.lastPathComponent) { try? FileManager.default.removeItem(at: old) }
    }
}
