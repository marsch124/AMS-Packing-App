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
        /// A worry the app can put right in one press: what the button says, and
        /// which repair it runs (`Library.repair(_:)`).
        public var fix: String = ""
        public var fixSays: String = ""
        public init(says: String, names: [String] = [], fix: String = "", fixSays: String = "") {
            self.says = says; self.names = names; self.fix = fix; self.fixSays = fixSays
        }
    }

    /// The one-press repairs a worry can offer.
    public static let FIX_UNUSED_PHOTOS = "unusedPhotos"

    /// Run a worry's repair. How many records it changed.
    @discardableResult
    public mutating func repair(_ fix: String) -> Int {
        switch fix {
        case Library.FIX_UNUSED_PHOTOS: return removeUnusedPhotos()
        default: return 0
        }
    }

    /// What looks wrong about this library. Empty = nothing to report.
    public func worries() -> [Worry] {
        var out: [Worry] = []

        // Two templates of the same name: the shape both accidents took. The bag
        // list is counted apart: its stored name is never shown, so a template he
        // calls "Containers" is not a second bag list (the spec pass, 5 Oct 2026) —
        // while two bag lists still are.
        let twiceNamed = repeatedNames(templates.map { (kind: $0.role == CONTAINER_ROLE ? "bags" : "", name: $0.name) })
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

        // Photos nothing shows any more — left behind by a trip deleted before 0.59
        // took its photos along. They travel through iCloud and every backup.
        let unused = unusedPhotos().count
        if unused > 0 {
            out.append(Worry(says: "\(unused) photo\(unused == 1 ? " is" : "s are") no longer shown anywhere \u{2014} left behind by a deleted trip.",
                             fix: Library.FIX_UNUSED_PHOTOS, fixSays: unused == 1 ? "Remove it" : "Remove them"))
        }

        // A thing that is on no list and in no trip is not wrong — he can keep
        // things loose — so that is not a worry.
        return out
    }

    /// The names that appear more than once among those of one kind, in the order
    /// they first appear.
    private func repeatedNames(_ all: [(kind: String, name: String)]) -> [String] {
        var seen: [String: Int] = [:], order: [(key: String, name: String)] = []
        for (kind, name) in all {
            guard !normName(name).isEmpty else { continue }
            let key = kind + "|" + normName(name)
            if seen[key] == nil { order.append((key, name)) }
            seen[key, default: 0] += 1
        }
        return order.filter { (seen[$0.key] ?? 0) > 1 }.map(\.name)
    }
}
