import Foundation
import PackingCore

// An open grab list, grouped by KIND OF THING (0.84). His words, 15 Oct 2026, on
// "Outdoor bike" open on the Mac — seventeen things in one flat run: "a bit more visual
// with some grouping … only for visuals but important to me", with "small headings in
// the list … maybe another colour, grey or something like that".
//
// Only the LOOK changes. A grab list is still a run of names in his order; nothing about
// it is stored differently, ticked differently or counted differently. A name is grouped
// under the Kind of thing of the THING of that name (one of his things, by `normName`),
// the kinds in HIS order (`categories()`); a name that is none of his things, or a thing
// with no kind, goes under "Other", last. Within a group the list's own order holds.

/// One small heading of an open grab list and the list's places under it.
public struct GrabGroup: Equatable, Sendable {
    /// The heading: his kind of thing as his list spells it, or "Other".
    public var kind: String
    /// Positions in the list's `items`, in the list's own order.
    public var rows: [Int]

    public init(kind: String, rows: [Int]) { self.kind = kind; self.rows = rows }
}

extension Library {
    /// The heading for names the app knows no kind for.
    public static let grabOtherKind = "Other"

    /// The kind of thing a grab list's name is: the Kind of thing of his thing of that
    /// name (by `normName`; the first such thing that has a kind) — "" when no thing of
    /// his has that name, or it has no kind.
    public func grabKind(of name: String) -> String {
        grabKinds()[normName(name)] ?? ""
    }

    /// Every thing's kind by its plain name, built in ONE pass over his things (an open
    /// list asks for each of its names at every tick; his library holds hundreds).
    func grabKinds() -> [String: String] {
        var kinds: [String: String] = [:]
        for it in items {
            let key = normName(it.name), kind = jsTrim(it.category)
            if !key.isEmpty, !kind.isEmpty, kinds[key] == nil { kinds[key] = kind }
        }
        return kinds
    }

    /// The groups an open grab list shows — or NONE, when its things fall into fewer than
    /// two kinds: a list all of one kind (or of names the app does not know) stays flat,
    /// with no heading at all, as he made it.
    ///
    /// Order: his kinds of thing in his order (`categories()`); then a kind a thing still
    /// carries that is no longer on his list (from the web app, or an older device), in the
    /// order the list first meets it; "Other" always last — names that are none of his
    /// things, things with no kind, and a kind he himself called "Other". "Other" does not
    /// count towards the two: it sorts nothing.
    public func grabGroups(_ names: [String]) -> [GrabGroup] {
        let mine = categories()
        let other = normName(Library.grabOtherKind)
        var byKey: [String: GrabGroup] = [:]
        var seen: [String] = []                        // keys in the order the list meets them
        let known = grabKinds()
        for (n, name) in names.enumerated() {
            let kind = known[normName(name)] ?? ""
            var key = normName(kind)
            if key.isEmpty { key = other }
            if byKey[key] == nil {
                // His own spelling where the kind is on his list.
                let label = key == other ? Library.grabOtherKind
                    : (mine.first { normName($0) == key } ?? kind)
                byKey[key] = GrabGroup(kind: label, rows: [])
                seen.append(key)
            }
            byKey[key]?.rows.append(n)
        }
        let kinds = seen.filter { $0 != other }
        guard kinds.count >= 2 else { return [] }
        let order = mine.map(normName)
        let listed = order.filter { kinds.contains($0) && $0 != other }
        let unlisted = kinds.filter { !order.contains($0) }
        return (listed + unlisted + (byKey[other] == nil ? [] : [other])).compactMap { byKey[$0] }
    }
}
