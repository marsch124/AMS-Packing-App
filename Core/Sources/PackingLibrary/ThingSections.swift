import PackingCore

// A thing's section, set from the thing's own page (0.64). His ask (6 Oct 2026): he
// likes sections because "it gives a visual structure to the packing", and asked
// whether a thing's section can be set "already in this view" — its page — instead of
// opening every template it is on. A section belongs to a TEMPLATE (`PackList.sections`)
// and a thing's place on a template (its membership) names one of that template's
// sections, so the page has one Section per template the thing is on.
//
// What is stored is exactly what the row editor stores for its Section (`saveRow`):
// the place's `section`, a section typed there made only on Save — and the thing's
// open lines on trips still ahead follow, as they do after a row is saved.

extension Library {
    /// The place on a template the thing's page speaks for: the FIRST, as the template
    /// reads its rows (by `order`; equal numbers keep the stored order). A thing can sit
    /// on one template twice — with another "When", say — and each place keeps its own
    /// section: the page sets the first, the template's own row sets any other.
    public func firstPlace(itemId: String, templateId: String) -> Membership? {
        func ord(_ m: Membership) -> Double { m.order.isNaN ? 0 : m.order }
        return memberships
            .filter { $0.itemId == itemId && $0.templateId == templateId }
            .stableSorted(compare: { a, b in jsSign(ord(a) - ord(b)) })
            .first
    }

    /// The section the thing's page shows for a template: the first place's section
    /// when it is one of THAT template's, else "" — an id from another template, or of
    /// a section since removed, reads as none, as the template's own page reads it
    /// (`groupItemsBySection` puts such a row under no heading).
    public func thingSection(itemId: String, templateId: String) -> String {
        guard let place = firstPlace(itemId: itemId, templateId: templateId), !place.section.isEmpty,
              let t = templates.first(where: { $0.id == templateId }),
              t.sections.contains(where: { $0.id == place.section }) else { return "" }
        return place.section
    }

    /// Put a thing under a section of one template — or under none — from its page.
    /// - `section`: a section id of THAT template, or "" for no section.
    /// - `newSection`: a name typed on the page. When it is not blank it wins over
    ///   `section`: the template's section of that name (case and spaces do not count)
    ///   is chosen, or a new one is made now — on Save, never while typing, so Cancel
    ///   leaves the template as it was (as in the row editor).
    /// Only the first place changes (`firstPlace`). Its open lines on trips still
    /// ahead follow (`followThing`), as after a row is saved in the row editor.
    /// Returns whether anything changed. Nothing is written — no section made, no trip
    /// touched — when the place is already there, the thing is not on the template, or
    /// `section` is not one of the template's.
    @discardableResult
    public mutating func setThingSection(itemId: String, templateId: String, section: String,
                                         newSection: String = "") -> Bool {
        guard let place = firstPlace(itemId: itemId, templateId: templateId),
              let t = templates.first(where: { $0.id == templateId }) else { return false }
        let typed = jsTrim(newSection)
        var wanted = section
        if !typed.isEmpty {
            // The template's section of that name, or a new one (`addSection` makes one
            // only when the name is new). The place already there is caught below — but
            // a NEW name is always a change, so nothing is made for nothing.
            guard let s = addSection(templateId: templateId, name: typed) else { return false }
            wanted = s.id
        } else if !section.isEmpty, !t.sections.contains(where: { $0.id == section }) {
            return false
        }
        guard wanted != place.section else { return false }
        updateMembership(memId: place.id) { $0.section = wanted }
        followThing(id: itemId)
        return true
    }
}
