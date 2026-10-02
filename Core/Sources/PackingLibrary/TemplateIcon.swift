import PackingCore

// A template's icon (his test H.1; the 50 icons and these suggestions approved
// 2 Oct 2026: "Your suggestions are fine. Please implement."). The icon he picks
// is kept in the template's own extra keys, so it travels with backups and
// iCloud and the web app's model is untouched. Until he picks one, the icon is
// suggested from the template's role and name; "letter" keeps the first letter.

extension Library {
    /// The template key the choice is stored under.
    public static let iconKey = "iconKey"
    /// Picked to show the first letter instead of any icon.
    public static let letterIcon = "letter"

    /// What he picked for this template, if anything ("letter" included).
    public func chosenIcon(templateId: String) -> String? {
        templates.first { $0.id == templateId }?.extra[Library.iconKey]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The same, read from the template itself (a resolved one carries its extra
    /// keys) — for a cover drawn where the library is not at hand.
    public static func icon(of list: PackList) -> String? {
        let chosen = list.extra[Library.iconKey]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        if chosen == Library.letterIcon { return nil }
        return chosen ?? suggestedIcon(for: list)
    }

    /// The icon to show: his choice, else the suggestion; nil = the first letter.
    public func icon(for list: PackList) -> String? {
        let chosen = chosenIcon(templateId: list.id)
        if chosen == Library.letterIcon { return nil }
        return chosen ?? Library.suggestedIcon(for: list)
    }

    /// Pick an icon ("letter" for none); nil goes back to the suggestion.
    @discardableResult
    public mutating func setTemplateIcon(id: String, key: String?) -> Bool {
        guard let n = templates.firstIndex(where: { $0.id == id }) else { return false }
        if let key, !key.isEmpty { templates[n].extra[Library.iconKey] = .string(key) }
        else { templates[n].extra.removeValue(forKey: Library.iconKey) }
        templates[n].updatedAt = nowISO()
        return true
    }

    /// The suggestion: by role first (the everyday base and the bags), then by
    /// the words in the name. Order matters — "freediving" before "diving",
    /// "breath" before "mobility" (his "Mobility & Breath work" is breath).
    public static func suggestedIcon(for list: PackList) -> String? {
        if list.role == CONTAINER_ROLE { return "box" }
        let name = normName(list.name)
        let words = Set(name.split { !$0.isLetter }.map(String.init))
        func has(_ part: String) -> Bool { name.contains(part) }
        func word(_ w: String) -> Bool { words.contains(w) }
        let rules: [(Bool, String)] = [
            (has("freediv"), "fin"),
            (has("diving") || word("dive") || has("scuba") || has("snorkel"), "diving"),
            (word("car"), "car"),
            (has("plane") || has("flight") || word("fly"), "plane"),
            (word("rv") || has("camper") || has("motorhome") || has("caravan"), "rv"),
            (has("train"), "train"),
            (has("ferry") || has("boat"), "ferry"),
            (has("golf"), "golf"),
            (has("hik") || has("trek"), "hiking"),
            (has("climb"), "climb"),
            (word("ski") || has("skiing"), "ski"),
            (has("camp"), "tent"),
            (has("bike") || has("cycl"), "bike"),
            (word("run") || has("running"), "run"),
            (has("swim"), "swim"),
            (has("strength") || word("gym"), "strength"),
            (has("breath"), "breath"),
            (has("mobility") || has("stretch") || has("yoga"), "mobility"),
            (has("padel") || has("tennis"), "racket"),
            (has("beach"), "beach"),
            (has("fish"), "fishing"),
            (word("work") || has("business"), "laptop"),
            (has("travel"), "suitcase"),
        ]
        if let hit = rules.first(where: { $0.0 }) { return hit.1 }
        return list.role == "base" ? "suitcase" : nil
    }
}
