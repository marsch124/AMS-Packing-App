import Foundation
import PackingCore

// Is this library sound? The one question it must be able to answer about itself,
// because the answer has been "no" twice: on 31 August 2026 a joining device
// seeded the starter templates into his account and every template existed twice
// ever since; on 23 September 2026 an import landed on a device that looked empty
// while iCloud still held an older copy, and the two libraries merged.
//
// Both times the damage was invisible on screen and obvious in the counts.

extension Library {
    public struct Worry: Equatable, Hashable, Sendable {
        /// What to show him, in his words.
        public var says: String
        /// The names it is about, so a screen can list them.
        public var names: [String]
        public init(says: String, names: [String] = []) { self.says = says; self.names = names }
    }

    /// What looks wrong about this library. Empty = nothing to report.
    public func worries() -> [Worry] {
        var out: [Worry] = []

        // Two templates of the same name: the shape both accidents took.
        let twiceNamed = repeatedNames(templates.map(\.name))
        if !twiceNamed.isEmpty {
            let n = twiceNamed.count
            out.append(Worry(says: "\(n) template name\(n == 1 ? "" : "s") appear\(n == 1 ? "s" : "") twice."
                             + " Two libraries may have met on this account.", names: twiceNamed))
        }

        // A thing on a list that is not there: a membership pointing nowhere. The
        // lists screen would simply not show it, so nothing on screen says it is
        // wrong — but it is, and it travels through every backup.
        let ids = Set(templates.map(\.id))
        let lost = memberships.filter { !ids.contains($0.templateId) }
        if !lost.isEmpty {
            out.append(Worry(says: "\(lost.count) thing\(lost.count == 1 ? " sits" : "s sit") on a list that no longer exists."))
        }

        // A thing that is on no list and in no trip is not wrong — he can keep
        // things loose — so that is not a worry.
        return out
    }

    /// The names that appear more than once, in the order they first appear.
    private func repeatedNames(_ all: [String]) -> [String] {
        var seen: [String: Int] = [:], order: [String] = []
        for name in all {
            let key = normName(name)
            guard !key.isEmpty else { continue }
            if seen[key] == nil { order.append(name) }
            seen[key, default: 0] += 1
        }
        return order.filter { (seen[normName($0)] ?? 0) > 1 }
    }
}
