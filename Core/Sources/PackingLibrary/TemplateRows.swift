import PackingCore

// A template's rows and faces, as this app decides them — the parts of spec 04 the
// spec pass of 5 Oct 2026 found wrong, put where a model test can hold them (the
// screens only show what these answer). PackingCore stays the web app's copy; what
// this app does differently lives here.

// MARK: - A row's own answers (the membership)

extension Library {
    /// What a row's "How many" or "Note" should STORE: its own answer only where it
    /// says something the thing does not. `shown` is what the row says now; `stored`
    /// is what its place on the template held before (nil = a new place); `thing` is
    /// the thing's own answer. A row whose value did not change keeps what it held —
    /// a real exception stays one even when it happens to equal the thing's.
    static func placeAnswer(shown: String, stored: String?, thing: String) -> String {
        if let stored, shown == (stored.isEmpty ? thing : stored) { return stored }
        return shown == thing ? "" : shown
    }

    /// The clean-up for the rows the old save froze (the spec pass, 5 Oct 2026): a
    /// place on a template whose "How many" or note is EXACTLY the thing's own was a
    /// copy, so it goes back to blank — "the same as the thing" — and a later change
    /// to the thing reaches it again. Nothing on screen changes: the row says the
    /// same either way. A place that says something else is his own and is kept.
    /// Returns how many places changed; running it again changes none.
    @discardableResult
    public mutating func letCopiedAnswersFollowTheirThings() -> Int {
        var things: [String: Item] = [:]
        for i in items { things[i.id] = i }
        var changed = 0
        for n in memberships.indices {
            guard let thing = things[memberships[n].itemId] else { continue }
            var m = memberships[n]
            if !m.qty.isEmpty && m.qty == thing.qty { m.qty = "" }
            if !m.note.isEmpty && m.note == thing.note { m.note = "" }
            if m != memberships[n] { memberships[n] = m; changed += 1 }
        }
        return changed
    }

    /// What the row editor hands back when he presses Save.
    public struct RowAnswers: Equatable, Sendable {
        /// "" = the same as the thing (or the template's own bag, when it has one).
        public var bag: String
        /// "" = the same as the thing.
        public var when: String
        public var qty: String
        public var note: String
        /// A section of this template ("" = none).
        public var section: String
        /// A section typed in the editor. It is MADE only when the row is saved, and
        /// then holds the row — Cancel leaves the template as it was.
        public var newSection: String
        public var seasons: Set<String>
        public var contexts: Set<String>
        public var transports: Set<String>
        public var catering: Set<String>
        public init(bag: String = "", when: String = "", qty: String = "", note: String = "",
                    section: String = "", newSection: String = "",
                    seasons: Set<String> = [], contexts: Set<String> = [],
                    transports: Set<String> = [], catering: Set<String> = []) {
            self.bag = bag; self.when = when; self.qty = qty; self.note = note
            self.section = section; self.newSection = newSection
            self.seasons = seasons; self.contexts = contexts; self.transports = transports; self.catering = catering
        }
    }

    /// Save one row from the row editor: what THIS template says about the thing.
    /// - A section typed there is made now, not when it was typed (Cancel used to
    ///   leave an empty section behind — spec 04, the spec pass).
    /// - How many and the note are stored only where they differ from the thing's
    ///   own; equal is "the same as the thing", so a later change to it reaches here.
    /// - "Only on" keeps a word it does not know (a web-app "summer") unless he
    ///   switched it off; before, Save quietly dropped it.
    /// - The thing's open lines on trips still ahead follow, as a change to the thing
    ///   does (his I.7 decision, 1 Oct 2026, carried to a row's own answers).
    /// false for a row that is not on that template any more.
    @discardableResult
    public mutating func saveRow(templateId: String, memId: String, _ a: RowAnswers) -> Bool {
        guard let m = memberships.first(where: { $0.id == memId && $0.templateId == templateId }),
              let thing = items.first(where: { $0.id == m.itemId }) else { return false }
        var section = a.section
        if !jsTrim(a.newSection).isEmpty, let made = addSection(templateId: templateId, name: a.newSection) {
            section = made.id
        }
        let qty = jsTrim(a.qty), note = jsTrim(a.note)
        updateMembership(memId: memId) { r in
            r.container = a.bag
            r.phase = a.when
            r.qty = qty == thing.qty ? "" : qty
            r.note = note == thing.note ? "" : note
            r.section = section
            r.seasons = Library.keptConditions(a.seasons, SEASONS, r.seasons)
            r.contexts = Library.keptConditions(a.contexts, CONTEXTS, r.contexts)
            r.transports = Library.keptConditions(a.transports, TRANSPORTS, r.transports)
            r.catering = Library.keptConditions(a.catering, CATERING.map(\.id), r.catering)
        }
        followThing(id: thing.id)
        return true
    }

    /// One "Only on" list after an edit: the app's own words in the app's order (so
    /// the stored list reads the same every time), then any word it does not know —
    /// kept, in the order it was stored, as long as he left it switched on.
    public static func keptConditions(_ picked: Set<String>, _ vocabulary: [String], _ stored: [String]) -> [String] {
        var out = vocabulary.filter(picked.contains)
        for w in stored where !vocabulary.contains(w) && picked.contains(w) && !out.contains(w) { out.append(w) }
        return out
    }

    /// The words of a row's "Only on" a template does not know: the editor shows them
    /// as pills of their own, so they can be seen and switched off.
    public static func unknownConditions(_ stored: [String], _ vocabulary: [String]) -> [String] {
        var out: [String] = []
        for w in stored where !vocabulary.contains(w) && !out.contains(w) { out.append(w) }
        return out
    }

    /// "Only on: Summer · Plane" — what a row on this template is limited to, or "".
    /// Context counts only on a workout (WET) template, as a trip reads it, so it is
    /// not claimed on any other (the spec pass: the row said a limit that did nothing).
    public static func onlyOnWords(_ row: Item, on list: PackList?) -> String {
        let food = ["self": "Self-sufficient", "eatout": "Eating out", "mixed": "Mix of both"]
        let all = row.seasons + (contextApplies(list) ? row.contexts : []) + row.transports
            + row.catering.map { food[$0] ?? $0 }
        return all.isEmpty ? "" : "Only on: " + all.joined(separator: " \u{00B7} ")
    }

    /// The first bag pill of the row editor: what a blank bag on this row REALLY
    /// means. A template that came with a bag of its own puts every blank row there,
    /// before the thing's own bag (Resolve: exception → template → thing).
    public func sameBagWords(templateId: String, thing: Item) -> String {
        let own = jsTrim(templates.first { $0.id == templateId }?.defaultContainer ?? "")
        return own.isEmpty ? "Same as the thing (\(thing.container))" : "Same as the template (\(own))"
    }
}

// MARK: - A template's face: its letter and its colour

/// The cover colours of this app: the web app's ten (`TEMPLATE_COLORS`, kept as they
/// are for the parity check) with its cyan and teal swapped for orange and indigo —
/// "Not teal … Do not use teal for anything new" (his colour notes, 28 Sep 2026).
public let COVER_COLOURS: [String] = TEMPLATE_COLORS.map { c in
    switch c.lowercased() {
    case "#06b6d4": return "#f97316"     // cyan → orange
    case "#14b8a6": return "#4f46e5"     // teal → indigo
    default: return c
    }
}

extension Library {
    /// A template's colour: its own when it has one (his data), else the same stable
    /// pick the web app makes — from the colours above, so never teal or cyan.
    public static func coverColour(_ list: PackList?) -> String {
        if let c = list?.color, isHexColor(c) { return c }
        let key = (list?.id.isEmpty == false) ? (list?.id ?? "") : (list?.name ?? "")
        return COVER_COLOURS[Int(jsHash31(key) % UInt32(COVER_COLOURS.count))]
    }

    /// The colour a new "When" step gets: the next of the cover colours, as the web
    /// app picks it — but never teal (the eighth used to be).
    public static func newStepColour(after count: Int) -> String {
        COVER_COLOURS[max(count, 0) % COVER_COLOURS.count]
    }

    /// A new "When" step after the ones he has (Your choices → "When" steps), with
    /// its colour from the cover colours above.
    public func newStep(named name: String) -> Phase {
        let now = timeline()
        return newPhase(jsTrim(name), now.map(\.id), ["color": .string(Library.newStepColour(after: now.count))])
    }

    /// The letter on a cover with no icon: the name's first letter, capital. Never
    /// the emoji a template may carry from the web app — no emoji in this app (his
    /// rule; the spec pass found a web-app emoji showing through).
    public static func coverLetter(_ list: PackList) -> String {
        String(jsTrim(list.name).prefix(1)).uppercased()
    }
}

// MARK: - Which templates the screens show, and what they add up to

extension Library {
    /// The templates he sees as templates — on the Templates tab and in Search: every
    /// one but the bag list (Bags have their own screen) and the web app's retired
    /// "Loose items" bin. Resolved, A–Z.
    public func shownTemplates() -> [PackList] {
        resolvedTemplates().filter { $0.role != CONTAINER_ROLE && $0.role != "loose" }
    }

    /// What the Templates tab's line counts: the templates shown, the THINGS on them
    /// (each once, however many templates it sits on — bags and things on no template
    /// are not on them), and the trips packed from them (by the templates a trip
    /// names or its lines came from). His ask of the spec pass: the words should
    /// match the numbers.
    public func templateSummary(_ shown: [PackList]) -> (templates: Int, things: Int, trips: Int) {
        let ids = Set(shown.map(\.id))
        // A template's reminders are no things (0.70).
        let things = Set(memberships.filter { ids.contains($0.templateId) }.map(\.itemId))
            .intersection(Set(items.filter { !Library.isReminder($0) }.map(\.id)))
        let trips = trips.filter { trip in
            trip.activities.contains(where: ids.contains)
                || trip.entries.contains { ($0.sourceListId).map(ids.contains) ?? false }
        }
        return (shown.count, things.count, trips.count)
    }

    /// Is this name already one of his templates' (another than `except`)? The bag
    /// list does not count: he never sees its stored name ("Containers" — it reads
    /// "Bags"), so refusing that name could only puzzle him.
    public func templateNameTaken(_ name: String, except id: String = "") -> Bool {
        let wanted = normName(name)
        guard !wanted.isEmpty else { return false }
        return templates.contains { $0.id != id && $0.role != CONTAINER_ROLE && normName($0.name) == wanted }
    }

    /// A name for a template that is free: the name itself, else "<name> 2", "3"…
    public func freeTemplateName(_ name: String) -> String {
        let clean = jsTrim(name)
        guard templateNameTaken(clean) else { return clean }
        var n = 2
        while templateNameTaken("\(clean) \(n)") { n += 1 }
        return "\(clean) \(n)"
    }
}
