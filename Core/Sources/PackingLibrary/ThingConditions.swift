import Foundation
import PackingCore

// A thing's condition is stored as the condition's ID ("retire"), never its label
// ("Needs replacing"). Everything that reads it matches ids: the buy list's "Needs
// replacing" offer (`conditionReplaces`), the lit pill on the thing's page, and
// Settings → Your choices, which refuses to remove a condition still in use.
//
// The table's Condition menu and Change all stored the LABEL until 0.62 (the spec
// pass, 5 Oct 2026): a thing marked "Needs replacing" there never reached To buy,
// its page lit nothing, and Your choices thought the condition unused. They store
// the id now, and a thing already stored the old way is put right on load
// (`repairConditionLabels`, run by the app each time the library is read).

extension Library {
    /// The condition a stored value means: its id when it IS an id of his
    /// conditions; else the id of the condition whose label it is (the way the table
    /// used to store it — compared as names are, so "needs replacing " counts); else
    /// nil (an id this device does not know: kept as it is, never "corrected" — it
    /// may be another device's newer condition).
    public func conditionId(for stored: String) -> String? {
        let value = jsTrim(stored)
        guard !value.isEmpty else { return nil }
        let known = conditions()
        if known.contains(where: { $0.id == value }) { return value }
        return known.first { normName($0.label) == normName(value) }?.id
    }

    /// What he reads for a stored condition: its label — or the stored text itself
    /// when no condition of his answers to it.
    public func conditionLabel(_ stored: String) -> String {
        guard let id = conditionId(for: stored) else { return jsTrim(stored) }
        return conditions().first { $0.id == id }?.label ?? jsTrim(stored)
    }

    /// Things whose condition was stored as a LABEL get the condition's id instead.
    /// Only a value that is no id of his and IS one of his labels is touched, so
    /// running it twice, or on two devices at once, comes to the same answer.
    /// Returns how many things changed.
    @discardableResult
    public mutating func repairConditionLabels() -> Int {
        var n = 0
        for i in items.indices {
            let stored = items[i].condition
            guard !stored.isEmpty, let id = conditionId(for: stored), id != stored else { continue }
            items[i].condition = id
            n += 1
        }
        return n
    }
}
