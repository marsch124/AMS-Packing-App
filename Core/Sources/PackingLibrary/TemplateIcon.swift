import PackingCore

// A template's icon (his test H.1; the 50 icons and these suggestions approved
// 2 Oct 2026: "Your suggestions are fine. Please implement."; 40 more icons and
// their suggestions in 0.74 — the drawings are in TemplateIconCatalog.swift). The icon he picks
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
    /// "breath" before "mobility" (his "Mobility & Breath work" is breath),
    /// "motorbike" before "bike", "kitesurf" before "surf".
    ///
    /// 0.74 (his "On the Beach" showed the plain umbrella; he asked for an icon that
    /// says "on the beach"): a beach now suggests the lounger under its parasol, and
    /// the 40 new icons have their words — English, and Swedish where he might name a
    /// template so. Rules that are new for an OLD icon stand at the end, so a template
    /// that had a suggestion keeps it unless a new icon fits it better.
    public static func suggestedIcon(for list: PackList) -> String? {
        if list.role == CONTAINER_ROLE { return "box" }
        let name = normName(list.name)
        let words = Set(name.split { !$0.isLetter }.map(String.init))
        func has(_ part: String) -> Bool { name.contains(part) }
        func word(_ w: String) -> Bool { words.contains(w) }
        // A short trip (0.78): the weekend bag, not the big Travel suitcase — English and Swedish.
        let short = word("short") || has("weekend") || has("small core") || word("kort") || has("kortresa")
            || word("helg") || has("helgresa")
        let rules: [(Bool, String)] = [
            (has("freediv") || has("fridyk"), "fin"),
            (has("diving") || word("dive") || has("scuba") || has("snorkel") || has("dykning"), "diving"),
            (word("car"), "car"),
            (has("plane") || has("flight") || word("fly"), "plane"),
            (word("rv") || has("camper") || has("motorhome") || has("caravan"), "rv"),
            // Before "bike" and "cycl" (0.74): a motorbike is no bicycle.
            (has("motorbike") || has("motorcycl") || has("motorcykel") || word("mc"), "motorbike"),
            // Whole words: "Strength training" and "Swim training" are not trains,
            // and "Campus" is no tent (the spec pass, 5 Oct 2026).
            (word("train") || word("trains") || has("railway"), "train"),
            // Before "boat" (0.74): a sailing boat is no ferry.
            (has("sail") || has("segl") || has("segel") || has("yacht"), "sail"),
            (has("ferry") || has("boat"), "ferry"),
            (word("bus") || word("buses") || word("buss") || word("coach"), "bus"),
            (has("golf"), "golf"),
            (has("hik") || has("trek"), "hiking"),
            (has("climb"), "climb"),
            (word("ski") || has("skiing"), "ski"),
            (word("camp") || word("camping") || word("camps") || has("campsite") || has("campground") || has("campfire"), "tent"),
            // Before swim, bike and run (0.74): a triathlon is all three.
            (has("triathlon") || has("ironman") || word("tri"), "triathlon"),
            (has("bike") || has("cycl"), "bike"),
            (word("run") || has("running"), "run"),
            (has("ice bath") || has("icebath") || has("isbad") || has("cold plunge") || has("kallbad"), "icebath"),
            (has("swim"), "swim"),
            (has("strength") || word("gym"), "strength"),
            (has("breath"), "breath"),
            (has("yoga"), "lotus"),
            (has("mobility") || has("stretch"), "mobility"),
            (has("padel") || has("tennis"), "racket"),
            (has("kite"), "kite"),
            (has("surf"), "surf"),
            // "On the beach" — the lounger under its parasol (0.74; was the umbrella).
            (has("beach") || word("strand") || has("sunbath") || has("solsemester"), "lounger"),
            (has("tropic") || word("palm") || word("palms") || word("island"), "palm"),
            (has("fish"), "fishing"),
            (has("business") || has("conference") || has("konferens") || has("tjänsteresa"), "briefcase"),
            (word("work") || word("jobb") || word("arbete"), "laptop"),
            (has("hotel"), "hotel"),
            (has("city") || word("town") || word("stad") || has("storstad"), "city"),
            (has("restaurant") || has("restaurang") || has("dinner") || has("middag"), "restaurant"),
            (has("wine") || word("vin") || has("vingård"), "wine"),
            (has("concert") || has("konsert") || has("festival") || has("music") || has("musik"), "music"),
            (has("party") || word("fest") || has("kalas") || has("wedding") || has("bröllop"), "party"),
            (has("birthday") || has("födelsedag") || has("christmas") || word("jul"), "gift"),
            (has("shopping") || word("shop") || has("shoppa") || has("handla"), "shopping"),
            (has("picnic") || has("picknick"), "picnic"),
            (has("bbq") || has("barbecue") || has("grill"), "bbq"),
            (word("kids") || has("children") || has("family") || word("barn") || has("barnen") || has("familj"), "kids"),
            (has("walk") || has("promenad"), "walk"),
            // Just before "travel" (0.78): "Short travel kit" is the weekend bag. Only a name that
            // also says travel ("resa") is taken here; every other short word waits at the end,
            // so no name that had a suggestion loses it.
            (short && (has("travel") || word("resa") || word("resor")), "weekendbag"),
            (has("travel"), "suitcase"),
            // Old icons that had no words until 0.74 — last, so nothing above changes.
            (has("summer") || has("sommar"), "sun"),
            (has("winter") || has("vinter"), "snow"),
            (has("sauna") || has("bastu"), "sauna"),
            (has("kayak") || has("canoe") || has("paddl") || has("kajak") || has("kanot"), "kayak"),
            (has("orienteer") || has("orientering"), "compass"),
            (word("dog") || word("dogs") || word("hund"), "paw"),
            (has("coffee") || has("kaffe") || word("fika"), "coffee"),
            (has("photo") || has("foto"), "camera"),
            (has("kettlebell"), "kettlebell"),
            // Swedish for the old ones (0.74) — whole words, last.
            (word("bil") || word("bilen"), "car"),
            (has("flyg"), "plane"),
            (word("tåg") || word("tåget"), "train"),
            (has("färja") || word("båt") || word("båten"), "ferry"),
            (has("vandr"), "hiking"),
            (has("skidor") || has("skidåkning"), "ski"),
            (has("cykel") || has("cykling"), "bike"),
            (has("löpning") || word("löp"), "run"),
            (has("simning") || word("sim"), "swim"),
            (has("styrka"), "strength"),
            (has("fiske"), "fishing"),
            (word("resa") || word("resor"), "suitcase"),
            // After the Swedish hiking word: "Fjällvandring" is a hike.
            (has("mountain") || has("summit") || has("fjäll"), "mountain"),
            // The weekend bag's own words (0.78) — last, so nothing above changes.
            (short, "weekendbag"),
        ]
        if let hit = rules.first(where: { $0.0 }) { return hit.1 }
        return list.role == "base" ? "suitcase" : nil
    }
}
