import Foundation
import PackingCore

// Done headings turn green and fold (0.87) — in an open grab list, a heading of HIS whose things
// are all in hand turns green with a check and folds to that one line, like the groups on a trip
// (0.82's green ring, spec 07 part 20). His yes, 15 Oct 2026, to: "Done headings turn green and
// fold: in a grab list, when everything under a heading is in hand, it turns green and folds to
// one line, like the groups on a trip. You scroll less at the door."
//
// THE RULE (decided by the build):
//   • A heading's things are "to take" unless skipped ⊘; it is DONE when at least one of them is
//     in hand and every one to take is — exactly the whole list's own "All there" rule
//     (`GrabState.isComplete`), asked of the heading's things alone. So a skipped thing counts as
//     done (it does not hold its heading open), and a heading whose things are ALL skipped is not
//     done: nothing under it is in hand, and it stays open so a skip can be taken back.
//   • Only a heading of his folds. The things above his first heading stand under none and never
//     fold; a list without headings is one plain run, as before.
//   • Nothing still to take is ever hidden: only a done heading folds, and the moment one of its
//     things is unticked (or a skip taken back) it is no longer done and opens.
//   • A tap on a folded heading opens it (to untick something); it stays open while it is done
//     and he leaves it so. Once it is no longer done that is forgotten, so the next time
//     everything under it is in hand it folds again. A tap on an open done heading folds it.
//   • Nothing is stored: the folds follow the ticks, which are this device's own (`GrabState`);
//     a heading opened by hand is remembered only while the list is open.

/// One of his headings, as far as its things go (0.87).
public struct GrabGroupProgress: Equatable, Sendable {
    /// Its things in hand (ticked and not skipped).
    public var inHand: Int
    /// Its things to take: not skipped.
    public var toTake: Int

    public init(inHand: Int, toTake: Int) { self.inHand = inHand; self.toTake = toTake }

    /// Something under it is in hand and nothing under it is left to take.
    public var done: Bool { toTake > 0 && inHand >= toTake }
}

extension GrabState {
    /// How far a group is: its things, read from the list's `items` by their places.
    public func progress(of group: GrabGroup, items: [String]) -> GrabGroupProgress {
        let names = group.rows.filter { $0 >= 0 && $0 < items.count }.map { items[$0] }
        return GrabGroupProgress(inHand: inHand(names), toTake: active(names).count)
    }
}

extension GrabDefinition {
    /// Can this group fold now — one of his headings, and done?
    public func folds(_ g: Int, _ state: GrabState) -> Bool {
        let all = groups
        guard g >= 0, g < all.count, !all[g].heading.isEmpty else { return false }
        return state.progress(of: all[g], items: items).done
    }

    /// The groups (by their place in `groups`) shown folded: each done heading of his, but those
    /// he opened again by a tap.
    public func foldedGroups(_ state: GrabState, opened: Set<Int>) -> Set<Int> {
        Set(groups.indices.filter { folds($0, state) && !opened.contains($0) })
    }

    /// What stays opened by hand after a change: only the groups still done — one that is not
    /// done any more is forgotten, so it folds again the next time everything under it is in hand.
    public func keptOpen(_ opened: Set<Int>, _ state: GrabState) -> Set<Int> {
        opened.filter { folds($0, state) }
    }
}
