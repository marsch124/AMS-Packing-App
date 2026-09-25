import Foundation
import PackingCore

// His bags: the things on the one list whose role is "container".
//
// The web app keeps a bag as an ordinary thing on a special "Containers" list, and
// gives it three numbers of its own: what it may carry (maxKg), its size (capacityL)
// and its empty weight (the thing's own `weight`). The trip's Bags card measures a
// bag against maxKg — so this is where a bag GETS a limit.
//
// Bags are joined to things by NAME (`container` is a string), as in the web app.
// So a bag cannot be renamed here: renaming it would quietly orphan every thing
// packed in it, and its limit would stop applying. Name, then numbers.

extension Library {
    /// The Containers list, if he has one.
    public var containerList: PackList? {
        templates.first { $0.role == CONTAINER_ROLE }
    }

    /// Every bag's weight limit by name — the built-in airline ceilings, overlaid
    /// with the limits he has set on his own bags.
    ///
    /// 🪤 It must be given the RESOLVED lists. `templates` are the lists' shells —
    /// their things live in `memberships` — so `containerLimits(templates)` sees a
    /// Containers list with nothing on it and applies none of his limits. The first
    /// Bags card did exactly that; its test caught it. Always ask here.
    public func bagLimits() -> [String: Double] {
        containerLimits(resolvedTemplates())
    }

    /// His bags, in the list's own order.
    public func bags() -> [Item] {
        guard let list = containerList else { return [] }
        return resolvedTemplate(id: list.id)?.items ?? []
    }

    /// Set a bag's numbers. Blank or negative is taken as "not set".
    @discardableResult
    public mutating func setBag(id: String, maxKg: Double? = nil, capacityL: Double? = nil,
                                emptyGrams: Double? = nil) -> Bool {
        guard bags().contains(where: { $0.id == id }) else { return false }
        return updateThing(id: id) { bag in
            if let maxKg { bag.maxKg = max(0, maxKg) }
            if let capacityL { bag.capacityL = max(0, capacityL) }
            if let emptyGrams { bag.weight = max(0, emptyGrams) }
        }
    }

    /// A bag, on the Containers list — which is made first if he has none.
    ///
    /// A name he already has a BAG by is refused: two bags with one name would be one
    /// bag to every trip, because bags are joined by name. But a THING he already owns
    /// by that name (a toiletry bag he has only ever packed) is not refused — it
    /// becomes a bag. Refusing it would leave him no way to give it a limit, and
    /// making a second thing of the same name is refused by `addThing` anyway.
    @discardableResult
    public mutating func addBag(name: String) -> Item? {
        let wanted = jsTrim(name)
        guard !wanted.isEmpty, !bags().contains(where: { normName($0.name) == normName(wanted) }) else { return nil }
        if containerList == nil {
            saveTemplate(newList(name: CONTAINER_LIST_NAME, role: CONTAINER_ROLE))
        }
        guard let list = containerList else { return nil }
        let bag = items.first { normName($0.name) == normName(wanted) } ?? addThing(name: wanted)
        guard let bag else { return nil }
        setOnTemplate(itemId: bag.id, templateId: list.id, on: true)
        return items.first { $0.id == bag.id }
    }
}
