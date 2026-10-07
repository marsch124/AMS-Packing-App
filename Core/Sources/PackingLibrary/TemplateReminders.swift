import PackingCore

// Reminders on a template — his idea of 7 Oct 2026: "a list of simple reminders for
// each Template" (spec 07, part 12). Nothing new is invented for them: the web app
// already knows a reminder — a catalogue item whose `itemType` is "reminder", put on
// a template by a membership like any thing, copied onto a trip as a line that is
// ticked but never weighed, never in a bag and never asked about in the review. So a
// reminder made here is exactly that, and the web app (and the parity check) read it
// as their own.
//
// What this file adds is the WAY he handles them: on a template's page they are a
// list of their own (add, rename, order, When, remove), and they are kept out of the
// screens about his THINGS.

/// The `itemType` of a reminder (the web app's word).
public let REMINDER_TYPE = "reminder"
/// The kind of thing a reminder made here is filed under — the web app's own
/// "Reminders" category, the last of `CATEGORIES`.
public let REMINDERS_CATEGORY = "Reminders"

extension Library {
    /// Is this row, line or thing a reminder? (A resolved row says so with its
    /// template's own answer, `membership.itemType`, over the thing's.)
    public static func isReminder(_ row: Item) -> Bool { row.itemType == REMINDER_TYPE }

    /// Why a reminder's name cannot be taken on a template.
    public enum ReminderNameProblem: Equatable, Sendable {
        /// Nothing typed.
        case blank
        /// This template has a reminder of that name already.
        case alreadyHere
        /// One of his THINGS has that name: a reminder is no thing to pack.
        case aThing
    }

    /// The template's reminders, as resolved rows, in their order (the membership
    /// `order` a trip reads).
    public func reminders(templateId: String) -> [Item] {
        (resolvedTemplate(id: templateId)?.items ?? []).filter(Library.isReminder)
    }

    /// Can this name be a reminder on this template? `except` is the reminder being
    /// renamed (its own name, in other capitals, is no clash). nil = it can.
    public func reminderNameProblem(templateId: String, name: String, except memId: String = "") -> ReminderNameProblem? {
        let clean = jsTrim(name)
        if clean.isEmpty { return .blank }
        let wanted = normName(clean)
        if reminders(templateId: templateId).contains(where: { $0.memId != memId && normName($0.name) == wanted }) {
            return .alreadyHere
        }
        if items.contains(where: { !Library.isReminder($0) && normName($0.name) == wanted }) { return .aThing }
        return nil
    }

    /// The When a new reminder starts with on this template: that of its last
    /// reminder, else the day before (the first step one day ahead), else the step a
    /// new thing gets.
    public func whenForNewReminder(templateId: String) -> String {
        if let last = reminders(templateId: templateId).last, !last.phase.isEmpty { return last.phase }
        return PHASES.first { $0.leadDays == 1 }?.id ?? defaultPhaseId()
    }

    /// Put a reminder on a template, last among its rows. A reminder of that name he
    /// already has (on another template) is put on this one too — one reminder, two
    /// places, as a thing is; otherwise a new one is made: kind "Reminders", no bag,
    /// no weight, and on the Quick list so a quick trip brings it too. Refused (nil)
    /// for any `reminderNameProblem`, or a template that does not exist. Returns the
    /// row as the template now shows it.
    @discardableResult
    public mutating func addReminder(templateId: String, name: String, when: String = "") -> Item? {
        guard templates.contains(where: { $0.id == templateId }),
              reminderNameProblem(templateId: templateId, name: name) == nil else { return nil }
        let clean = jsTrim(name)
        let phase = jsTrim(when).isEmpty ? whenForNewReminder(templateId: templateId) : jsTrim(when)
        let item: Item
        if let had = items.first(where: { Library.isReminder($0) && normName($0.name) == normName(clean) }) {
            item = had
        } else {
            item = madeReminder(clean, phase: phase)
        }
        let last = memberships.filter { $0.templateId == templateId }.map { $0.order.isNaN ? 0 : $0.order }.max()
        let m = newMembership(itemId: item.id, templateId: templateId,
                              phase: phase == item.phase ? "" : phase, order: (last ?? -1) + 1)
        memberships.append(m)
        touchTemplate(templateId)
        return reminders(templateId: templateId).first { $0.memId == m.id }
    }

    /// Rename a reminder on THIS template only (his list is per template). A reminder
    /// that sits on this template alone is renamed in place — its open lines on trips
    /// still ahead follow, as a thing's do. One that also sits on another template
    /// keeps its name there: this template's place moves to a reminder of the new name
    /// (one he has, or a new one), keeping its When and its place in the order.
    /// Refused for any `reminderNameProblem`.
    @discardableResult
    public mutating func renameReminder(templateId: String, memId: String, to name: String) -> Bool {
        guard let row = reminders(templateId: templateId).first(where: { $0.memId == memId }),
              let m = memberships.firstIndex(where: { $0.id == memId }),
              let oldId = row.itemId, let old = items.firstIndex(where: { $0.id == oldId }),
              reminderNameProblem(templateId: templateId, name: name, except: memId) == nil else { return false }
        let clean = jsTrim(name)
        if clean == items[old].name { return true }
        let alone = memberships.allSatisfy { $0.itemId != oldId || $0.id == memId }
        if alone && Library.isReminder(items[old]) {
            items[old].name = clean
            followThing(id: oldId)
        } else {
            let target = items.first { Library.isReminder($0) && $0.id != oldId && normName($0.name) == normName(clean) }
                ?? madeReminder(clean, phase: row.phase)
            memberships[m].itemId = target.id
            memberships[m].itemType = ""
            memberships[m].phase = row.phase == target.phase ? "" : row.phase
            dropIfUnused(oldId)
        }
        touchTemplate(templateId)
        return true
    }

    /// Set a reminder's When on THIS template (its own answer: blank when it is the
    /// reminder's own). Its open lines on trips still ahead follow.
    @discardableResult
    public mutating func setReminderWhen(templateId: String, memId: String, when: String) -> Bool {
        let phase = jsTrim(when)
        guard !phase.isEmpty, let row = reminders(templateId: templateId).first(where: { $0.memId == memId }),
              let m = memberships.firstIndex(where: { $0.id == memId }),
              let thing = items.first(where: { $0.id == row.itemId }) else { return false }
        let own = phase == thing.phase ? "" : phase
        guard memberships[m].phase != own else { return true }
        memberships[m].phase = own
        touchTemplate(templateId)
        followThing(id: thing.id)
        return true
    }

    /// Move a reminder one place up (`by` −1) or down (+1) among this template's
    /// reminders. The things between them keep their places; the rows are numbered
    /// 0, 1, 2… again and only the numbers that change are written. False at either
    /// end, or for a row that is no reminder here.
    @discardableResult
    public mutating func moveReminder(templateId: String, memId: String, by step: Int) -> Bool {
        let mine = reminders(templateId: templateId).compactMap(\.memId)
        guard let at = mine.firstIndex(of: memId), step != 0, mine.indices.contains(at + step) else { return false }
        let other = mine[at + step]
        var order = memberships.filter { $0.templateId == templateId }
            .stableSorted(compare: { a, b in jsSign((a.order.isNaN ? 0 : a.order) - (b.order.isNaN ? 0 : b.order)) })
            .map(\.id)
        guard let a = order.firstIndex(of: memId), let b = order.firstIndex(of: other) else { return false }
        order.swapAt(a, b)
        var changed = false
        for (place, id) in order.enumerated() {
            guard let n = memberships.firstIndex(where: { $0.id == id }), memberships[n].order != Double(place) else { continue }
            memberships[n].order = Double(place)
            changed = true
        }
        if changed { touchTemplate(templateId) }
        return true
    }

    /// Take a reminder off a template. A reminder on no other template then goes
    /// altogether (a reminder is no thing to keep in Your things). Trips already made
    /// keep their line: a trip's line is a copy.
    @discardableResult
    public mutating func removeReminder(templateId: String, memId: String) -> Bool {
        guard let row = reminders(templateId: templateId).first(where: { $0.memId == memId }) else { return false }
        memberships.removeAll { $0.id == memId }
        if let id = row.itemId { dropIfUnused(id) }
        touchTemplate(templateId)
        return true
    }

    // MARK: Kept out of the screens about his things

    /// The reminders that sit on a template. Those are shown on their templates'
    /// pages and never among his things; a reminder on NO template (left by the web
    /// app, say) still shows in Your things, so it can be seen and deleted.
    public func remindersOnTemplates() -> Set<String> {
        let rem = Set(items.filter(Library.isReminder).map(\.id))
        return Set(placesOnTemplates().map(\.itemId)).intersection(rem)
    }

    /// His THINGS: every item but the reminders that sit on a template.
    public func ownThings() -> [Item] {
        let hide = remindersOnTemplates()
        return hide.isEmpty ? items : items.filter { !hide.contains($0.id) }
    }

    // MARK: Helpers

    private mutating func madeReminder(_ name: String, phase: String) -> Item {
        var cat = catalogItemFromResolved(newItem(name: name, category: REMINDERS_CATEGORY, container: "",
                                                  phase: phase, itemType: REMINDER_TYPE, shortList: true))
        cat.id = PackingEnv.makeId()
        items.append(cat)
        return cat
    }

    /// A reminder on no template any more goes (never a thing, never one in a kit).
    private mutating func dropIfUnused(_ id: String) {
        guard let it = items.first(where: { $0.id == id }), Library.isReminder(it),
              !memberships.contains(where: { $0.itemId == id }) else { return }
        for k in kits.indices { kits[k].itemIds.removeAll { $0 == id } }
        items.removeAll { $0.id == id }
    }

    private mutating func touchTemplate(_ id: String) {
        if let t = templates.firstIndex(where: { $0.id == id }) { templates[t].updatedAt = nowISO() }
    }
}
