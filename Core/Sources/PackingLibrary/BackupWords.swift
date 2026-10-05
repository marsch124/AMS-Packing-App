import Foundation
import PackingCore

// What Settings says about backups — the words, here where the model tests hold them.

extension Library {
    /// "2 templates, 10 things and 1 trip" — what a library holds, in the three
    /// numbers he knows it by.
    public var holdsWords: String {
        func n(_ count: Int, _ one: String) -> String { "\(count) \(one)\(count == 1 ? "" : "s")" }
        return "\(n(templates.count, "template")), \(n(items.count, "thing")) and \(n(trips.count, "trip"))"
    }

    /// When this library was brought in from a backup file, and which file — read
    /// from the import's own marker, which travels with the library (the spec pass,
    /// 2026-10-05: the import counted everything and no screen showed any of it).
    /// nil for a library that never came from a file.
    public func broughtInWords(now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard let mark = meta["import"]?.objectValue, let at = mark["at"]?.stringValue, isoMoment(at) != nil else { return nil }
        var words = "Brought in from a backup \(SyncCheck.when(iso: at, now: now, calendar: calendar))"
        if let saved = mark["exportedAt"]?.stringValue, isoMoment(saved) != nil {
            words += " (the file was saved \(SyncCheck.when(iso: saved, now: now, calendar: calendar)))"
        }
        return words + "."
    }

    /// "Last saved from this iPhone today 14:05." — when a backup was last saved from
    /// THIS device (kept on the device, not in the library). The web app's "last
    /// backup" date, without its reminder: he decides when (the spec pass, 2026-10-05).
    public static func lastSavedWords(_ iso: String?, device: String,
                                      now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard let iso, isoMoment(iso) != nil else { return nil }
        return "Last saved from this \(device) \(SyncCheck.when(iso: iso, now: now, calendar: calendar))."
    }
}
