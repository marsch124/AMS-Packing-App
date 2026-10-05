import Foundation
import PackingCore

// The copies kept before a restore — how they are named, read out and pruned. The
// files themselves are the app's (RescueCopies); the rules are here, where the model
// tests hold them (the spec pass, 2026-10-05: pruning to three and the time read out
// had no test, and the time was the wrong one).

public enum RescueNames {
    /// How many copies are kept: the newest three.
    public static let keep = 3

    /// "before-restore-2026-09-22T23-04-11.123Z.json" for the moment the copy was
    /// written (UTC, as `nowISO()` gives it: names sort by time on every device).
    public static func fileName(at iso: String) -> String {
        "before-restore-\(iso.replacingOccurrences(of: ":", with: "-")).json"
    }

    /// The moment in a copy's name, or nil when it cannot be read.
    public static func moment(ofFileName name: String) -> Date? {
        var stamp = name
        if stamp.hasSuffix(".json") { stamp.removeLast(5) }
        guard stamp.hasPrefix("before-restore-") else { return nil }
        stamp.removeFirst("before-restore-".count)
        // 2026-09-22T23-04-11.123Z → 2026-09-22T23:04:11.123Z
        let parts = stamp.split(separator: "T", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return isoMoment("\(parts[0])T\(parts[1].replacingOccurrences(of: "-", with: ":"))")
    }

    /// The moment a copy was written, as it should be read out: "22 September, 23:04"
    /// — in HIS time (the spec pass, 2026-10-05). The name holds world time, so a copy
    /// written at 01:04 on 23 September in summer read "22 September, 23:04": an hour
    /// or two off, and near midnight the wrong day. A name that cannot be read is
    /// shown as it is.
    public static func when(fileName name: String, timeZone: TimeZone = .current) -> String {
        guard let moment = moment(ofFileName: name) else {
            return name.hasSuffix(".json") ? String(name.dropLast(5)) : name
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.day, .month, .hour, .minute], from: moment)
        let months = ["January", "February", "March", "April", "May", "June", "July",
                      "August", "September", "October", "November", "December"]
        return String(format: "%d %@, %02d:%02d", c.day ?? 0, months[(c.month ?? 1) - 1], c.hour ?? 0, c.minute ?? 0)
    }

    /// The copies to delete so that the newest `keep` stay — newest by name, which is
    /// by time, since every name holds world time in the same shape.
    public static func toRemove(_ names: [String], keep: Int = keep) -> [String] {
        Array(names.sorted(by: >).dropFirst(keep))
    }
}
