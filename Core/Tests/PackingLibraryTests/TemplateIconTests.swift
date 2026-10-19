import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A template's icon (his H.1, approved 2 Oct 2026): suggested from its role and
/// name, his choice kept through every later edit, a backup and the stored records.
final class TemplateIconTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    private func list(_ name: String, role: String = "", group: String = "") -> PackList {
        var l = newList(name: name, group: group); l.role = role; return l
    }

    func testTheSuggestionsComeFromRoleAndName() {
        let cases: [(PackList, String?)] = [
            (list("Car (base)", role: "transport"), "car"), (list("Plane (base)", role: "transport"), "plane"),
            (list("RV something (base)", role: "transport"), "rv"), (list("Travel", role: "base"), "suitcase"),
            (list("Containers", role: CONTAINER_ROLE), "box"), (list("Diving"), "diving"),
            (list("Freediving"), "fin"), (list("Golf"), "golf"), (list("Hiking"), "hiking"),
            (list("Bike"), "bike"), (list("Mobility & Breath work"), "breath"), (list("Mobility"), "mobility"),
            (list("Run"), "run"), (list("Strength"), "strength"), (list("Swim"), "swim"),
            (list("Carry-on things"), nil), (list("Brunch"), nil), (list("Common base", role: "base"), "suitcase"),
        ]
        for (l, want) in cases { XCTAssertEqual(Library.suggestedIcon(for: l), want, l.name) }
    }

    /// Whole words (the spec pass, 5 Oct 2026): "training" is no train, "Campus" no tent.
    func testATrainAndATentNeedTheirWholeWord() {
        let cases: [(String, String?)] = [
            ("Strength training", "strength"), ("Swim training", "swim"), ("Mobility training", "mobility"),
            ("Brain training", nil), ("Night train", "train"), ("Trains and buses", "train"),
            ("Campus visit", nil), ("Camping", "tent"), ("Training camp", "tent"), ("Campsite week", "tent"),
        ]
        for (name, want) in cases { XCTAssertEqual(Library.suggestedIcon(for: list(name)), want, name) }
    }

    /// His request (12 Oct 2026, the picker open on "On the Beach"): an icon that says
    /// "on the beach" — and a template of that name is given it without asking (0.74).
    func testOnTheBeachSuggestsTheLoungerUnderItsParasol() {
        for name in ["On the beach", "On the Beach", "Beach", "Beach week", "Strand", "Sunbathing"] {
            XCTAssertEqual(Library.suggestedIcon(for: list(name)), "lounger", name)
        }
        XCTAssertEqual(TemplateIconCatalog.icon("lounger")?.label, "On the beach")
    }

    /// The 40 icons of 0.74 have their words, English and Swedish; the old ones keep theirs.
    func testTheNewIconsAreSuggestedByTheirWords() {
        let cases: [(String, String?)] = [
            ("Motorbike tour", "motorbike"), ("Motorcycle", "motorbike"), ("MC-resa", "motorbike"),
            ("Sailing", "sail"), ("Sailing boat", "sail"), ("Segling", "sail"), ("Boat trip", "ferry"),
            ("Bus trip", "bus"), ("Triathlon", "triathlon"), ("Ironman", "triathlon"), ("Yoga", "lotus"),
            ("Mobility & yoga", "lotus"), ("Stretching", "mobility"), ("Kitesurf", "kite"), ("Surf trip", "surf"),
            ("Ice bath", "icebath"), ("Isbad", "icebath"), ("Tropical island", "palm"),
            ("Business trip", "briefcase"), ("Konferens", "briefcase"), ("Work trip", "laptop"),
            ("Hotel", "hotel"), ("City break", "city"), ("Restaurant", "restaurant"), ("Wine tasting", "wine"),
            ("Concert", "music"), ("Festival", "music"), ("Wedding", "party"), ("Christmas", "gift"),
            ("Shopping", "shopping"), ("Picnic", "picnic"), ("BBQ", "bbq"), ("With the kids", "kids"),
            ("City walk", "city"), ("Evening walk", "walk"),
            // Old icons that had no words before 0.74 — and Swedish names for old ones.
            ("Summer", "sun"), ("Sommar", "sun"), ("Winter", "snow"), ("Sauna", "sauna"), ("Bastu", "sauna"),
            ("Kayak", "kayak"), ("Kanot", "kayak"), ("Orienteering", "compass"), ("Dog", "paw"),
            ("Fika", "coffee"), ("Fridykning", "fin"), ("Dykning", "diving"), ("Snorkelling", "diving"),
            ("Fjällvandring", "hiking"), ("Cykel", "bike"), ("Löpning", "run"), ("Simning", "swim"),
            ("Bil", "car"), ("Flygresa", "plane"), ("Tåg", "train"), ("Färja", "ferry"), ("Skidor", "ski"),
            // Unchanged by 0.74.
            ("Carry-on things", nil), ("Brunch", nil), ("Brain training", nil), ("Campus visit", nil),
            ("Snowshoe", nil), ("Electronics", nil),
        ]
        for (name, want) in cases { XCTAssertEqual(Library.suggestedIcon(for: list(name)), want, name) }
    }

    /// His ask (13 Oct 2026): a short trip's template gets "a nice unique icon — not the same as
    /// Travel" (0.78) — the weekend bag, a drawing of its own right after Travel in the picker,
    /// suggested by a short trip's words in English and Swedish; Travel keeps the suitcase and
    /// no name that had a suggestion loses it.
    func testAShortTripSuggestsTheWeekendBagNotTheTravelSuitcase() {
        let bag = TemplateIconCatalog.icon("weekendbag")
        XCTAssertEqual(bag?.label, "Weekend bag", "no weekend bag in the catalog")
        XCTAssertEqual(bag?.group, .travel)
        let keys = TemplateIconCatalog.all.map(\.key)
        XCTAssertEqual(keys.firstIndex(of: "weekendbag"), keys.firstIndex(of: "suitcase").map { $0 + 1 }, "not right after Travel")
        XCTAssertEqual(keys.filter { $0 == "weekendbag" }.count, 1, "the key is used twice")
        XCTAssertNotEqual(bag?.path, TemplateIconCatalog.icon("suitcase")?.path, "the same drawing as Travel")
        XCTAssertEqual(Set(TemplateIconCatalog.all.map(\.path)).count, TemplateIconCatalog.all.count, "two icons share a drawing")
        XCTAssertNil(bag.flatMap { Self.drawingFault($0.path) }, "the weekend bag cannot be drawn")
        let cases: [(PackList, String?)] = [
            (list("Short travel kit", role: "base"), "weekendbag"), (list("Short trip"), "weekendbag"),
            (list("Short"), "weekendbag"), (list("Weekend"), "weekendbag"), (list("Weekend away", role: "base"), "weekendbag"),
            (list("Small core", role: "base"), "weekendbag"), (list("Kort resa"), "weekendbag"),
            (list("Helg"), "weekendbag"), (list("Helgresa"), "weekendbag"), (list("Weekendresa"), "weekendbag"),
            // Unchanged: Travel and an always-packed template keep the suitcase, shorts are no
            // short trip, and a word with an icon of its own keeps it.
            (list("Travel", role: "base"), "suitcase"), (list("Common base", role: "base"), "suitcase"),
            (list("Resa"), "suitcase"), (list("Shorts"), nil), (list("Summer weekend"), "sun"),
            (list("Weekend hike"), "hiking"),
        ]
        for (l, want) in cases { XCTAssertEqual(Library.suggestedIcon(for: l), want, l.name) }
    }

    /// 0.92 — his words (19 Oct 2026): "Could we add some icons again. Love the one we have." 41 new
    /// drawings in the same hand, each at the END of its heading: every icon he knows keeps its key,
    /// its heading and its order, and the new ones are where the picker shows them.
    func testTheFortyOneIconsOf092CloseTheirHeadingsAndTheOldOnesKeepTheirPlaces() {
        let all = TemplateIconCatalog.all
        let old = TemplateIconCatalog.firstNinetyOne
        XCTAssertEqual(old.count, 91)
        XCTAssertEqual(all.map(\.key).filter(old.contains), old, "an icon he knows moved or went")
        let added: [(key: String, label: String, group: TemplateIconGroup)] = [
            ("cottage", "Cottage", .travel), ("globe", "Abroad", .travel), ("pillow", "Neck pillow", .travel),
            ("scooter", "E-scooter", .travel),
            ("xcski", "Cross-country", .outdoors), ("skate", "Ice skating", .outdoors), ("sled", "Sled", .outdoors),
            ("sleepingbag", "Sleeping bag", .outdoors), ("binoculars", "Binoculars", .outdoors),
            ("thermos", "Thermos", .outdoors), ("mittens", "Mittens", .outdoors), ("jacket", "Jacket", .outdoors),
            ("mushroom", "Mushrooms", .outdoors),
            ("rowing", "Rowing", .sport), ("stopwatch", "Stopwatch", .sport), ("pulse", "Heart rate", .sport),
            ("trophy", "Trophy", .sport), ("helmet", "Bike helmet", .sport), ("pump", "Bike pump", .sport),
            ("wetsuit", "Wetsuit", .sport), ("tank", "Scuba tank", .sport), ("yogamat", "Yoga mat", .sport),
            ("sup", "Paddleboard", .sport), ("lifejacket", "Life jacket", .sport),
            ("icecream", "Ice cream", .beach), ("bucket", "Sand toys", .beach), ("anchor", "Anchor", .beach),
            ("midsummer", "Midsummer", .beach),
            ("pizza", "Pizza", .city), ("museum", "Museum", .city), ("cake", "Birthday", .city),
            ("rings", "Wedding", .city), ("xmastree", "Christmas", .city), ("cinema", "Cinema", .city),
            ("ferriswheel", "Fun fair", .city),
            ("toothbrush", "Toothbrush", .everyday), ("battery", "Battery", .everyday), ("badge", "Name badge", .everyday),
            ("notebook", "Notes", .everyday), ("suit", "Suit", .everyday), ("pram", "Pram", .everyday),
        ]
        XCTAssertEqual(added.count, 41)
        XCTAssertEqual(all.count, old.count + added.count, "not the 91 and the 41: \(all.count)")
        for a in added {
            let icon = TemplateIconCatalog.icon(a.key)
            XCTAssertNotNil(icon, "no \(a.key) in the catalog")
            XCTAssertEqual(icon?.label, a.label, a.key)
            XCTAssertEqual(icon?.group, a.group, a.key)
            XCTAssertFalse(old.contains(a.key), "\(a.key) is an old key")
        }
        // Under each heading the old ones first, in their order, then the new ones, in this order.
        for section in TemplateIconCatalog.grouped {
            let keys = section.icons.map(\.key)
            let newHere = added.filter { $0.group == section.group }.map(\.key)
            XCTAssertEqual(Array(keys.suffix(newHere.count)), newHere, "\(section.group): the new ones do not close the heading")
            XCTAssertEqual(Array(keys.prefix(keys.count - newHere.count)),
                           old.filter { TemplateIconCatalog.icon($0)?.group == section.group },
                           "\(section.group): an old icon moved")
        }
        // Each a drawing of its own, the app can draw it, and it keeps to the 24 box.
        XCTAssertEqual(Set(all.map(\.path)).count, all.count, "two icons share a drawing")
        for a in added { XCTAssertNil(TemplateIconCatalog.icon(a.key).flatMap { Self.drawingFault($0.path) }, a.key) }
    }

    /// 0.92's icons have words of their own — at the very end, so they only reach a name that
    /// suggested nothing until now; every name that had a suggestion keeps it.
    func testTheNewIconsOf092OnlyReachANameThatSuggestedNothing() {
        let cases: [(String, String?)] = [
            ("Rowing", "rowing"), ("Rodd", "rowing"), ("Erg", "rowing"), ("Ice skating", "skate"),
            ("Skridskor", "skate"), ("Långfärdsskridsko", "skate"), ("Pulka", "sled"), ("Sledding", "sled"),
            ("Cross-country", "xcski"), ("Langlauf", "xcski"), ("Wetsuit", "wetsuit"), ("SUP", "sup"),
            ("Race day", "trophy"), ("Tävling", "trophy"), ("Svampplockning", "mushroom"),
            ("Mushroom picking", "mushroom"), ("Stuga", "cottage"), ("Cottage", "cottage"), ("Utomlands", "globe"),
            ("Abroad", "globe"), ("Museum", "museum"), ("Cinema", "cinema"), ("Bio", "cinema"), ("Tivoli", "ferriswheel"),
            ("Liseberg", "ferriswheel"), ("Gröna Lund", "ferriswheel"), ("Barnvagn", "pram"), ("Stroller", "pram"),
            // Unchanged: a name that had a suggestion keeps it.
            ("Längdskidor", "ski"), ("Cross-country skiing", "ski"), ("Sommarstuga", "sun"), ("Midsommar", "sun"),
            ("Midsummer", "sun"), ("Wedding", "party"), ("Christmas", "gift"), ("Birthday", "gift"), ("Bike race", "bike"),
            ("Paddleboard", "kayak"), ("Ice bath", "icebath"), ("Weekend cabin", "weekendbag"),
            ("Electronics", nil), ("Snowshoe", nil), ("Brunch", nil), ("Carry-on things", nil), ("Shorts", nil),
            ("Program", nil), ("Brain training", nil),
        ]
        for (name, want) in cases { XCTAssertEqual(Library.suggestedIcon(for: list(name)), want, name) }
    }

    /// Every icon: a drawing the app can draw, a label, a key of its own — and every
    /// key a template may have stored since 0.46 still there.
    func testEveryIconHasADrawingALabelAndItsOwnKey() {
        let all = TemplateIconCatalog.all
        XCTAssertEqual(all.count, 132, "the picker's count (91 until 0.92)")
        XCTAssertEqual(Set(all.map(\.key)).count, all.count, "a key used twice: \(Dictionary(grouping: all.map(\.key), by: { $0 }).filter { $0.value.count > 1 }.keys.sorted())")
        XCTAssertEqual(Set(all.map(\.label)).count, all.count, "two icons with the same label")
        for key in TemplateIconCatalog.firstFifty {
            XCTAssertNotNil(TemplateIconCatalog.icon(key), "\(key) was there since 0.46 — a template may have it stored")
        }
        for icon in all {
            XCTAssertFalse(icon.key.isEmpty || icon.key == Library.letterIcon, "a key that means something else: '\(icon.key)'")
            XCTAssertFalse(icon.label.trimmingCharacters(in: .whitespaces).isEmpty, "\(icon.key) has no label")
            XCTAssertNil(icon.label.unicodeScalars.first { $0.properties.isEmojiPresentation }, "\(icon.key)'s label has an emoji")
            XCTAssertNil(Self.drawingFault(icon.path), "\(icon.key): \(Self.drawingFault(icon.path) ?? "")")
            XCTAssertTrue(TemplateIconCatalog.icon(icon.key) == icon)
        }
        // The headings hold every icon once, in the order of `all`.
        XCTAssertEqual(TemplateIconCatalog.grouped.flatMap { $0.icons.map(\.key) }, all.map(\.key))
        XCTAssertEqual(TemplateIconCatalog.grouped.map(\.group), TemplateIconGroup.allCases)
        XCTAssertNil(TemplateIconCatalog.icon("nope")); XCTAssertNil(TemplateIconCatalog.icon(nil))
    }

    /// Whatever a name suggests is an icon that exists (a suggestion with no drawing
    /// would show the letter while the picker says "Suggested").
    func testEverySuggestionIsAnIconThatExists() {
        let names = ["Car", "Plane", "RV", "Train", "Ferry", "Bus", "Motorbike", "Golf", "Hiking", "Climbing", "Ski",
                     "Camping", "Triathlon", "Bike", "Run", "Ice bath", "Swim", "Strength", "Breath", "Yoga", "Mobility",
                     "Tennis", "Kite", "Surf", "Beach", "Palm", "Fishing", "Business", "Work", "Hotel", "City",
                     "Restaurant", "Wine", "Concert", "Party", "Birthday", "Shopping", "Picnic", "Grill", "Kids", "Walk",
                     "Travel", "Summer", "Winter", "Sauna", "Kayak", "Orienteering", "Mountain", "Dog", "Coffee",
                     "Photo", "Kettlebell", "Freediving", "Diving", "Sailing", "Bil", "Flyg", "Tåg", "Färja", "Vandring",
                     "Skidor", "Cykel", "Löpning", "Simning", "Styrka", "Fiske", "Resa", "Weekend"]
        var seen = Set<String>()
        for name in names {
            guard let key = Library.suggestedIcon(for: list(name)) else { XCTFail("\(name) suggests nothing"); continue }
            XCTAssertNotNil(TemplateIconCatalog.icon(key), "\(name) suggests '\(key)', which has no drawing")
            seen.insert(key)
        }
        XCTAssertNotNil(TemplateIconCatalog.icon(Library.suggestedIcon(for: list("Containers", role: CONTAINER_ROLE))))
        XCTAssertGreaterThanOrEqual(seen.count, 50, "the probe names should reach most rules")
    }

    /// The path data SVGPath draws: only M L H V C S Q A Z, each with its numbers, every
    /// point inside the 24-point box (a stroke 1.9 wide needs ~1 point of room).
    static func drawingFault(_ d: String) -> String? {
        let counts: [Character: Int] = ["M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "A": 7, "Z": 0]
        var tokens: [String] = []
        var cur = ""
        func flush() { if !cur.isEmpty { tokens.append(cur); cur = "" } }
        for ch in d {
            if ch.isLetter { flush(); tokens.append(String(ch)) }
            else if ch == " " || ch == "," { flush() }
            else if ch == "-" || ch == "+" { flush(); cur = String(ch) }
            else if ch == "." && cur.contains(".") { flush(); cur = "." }
            else { cur.append(ch) }
        }
        flush()
        guard let first = tokens.first, first == "M" || first == "m" else { return "does not start with M" }
        var i = 0, cmd: Character = " ", x = 0.0, y = 0.0, sx = 0.0, sy = 0.0, drew = 0
        func inBox(_ px: Double, _ py: Double) -> Bool { px >= 1 && px <= 23 && py >= 1 && py <= 23 }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter {
                guard counts[Character(c.uppercased())] != nil else { return "cannot draw '\(c)'" }
                cmd = c; i += 1
                if c == "Z" || c == "z" { x = sx; y = sy; continue }
            }
            let up = Character(cmd.uppercased())
            guard let n = counts[up], n > 0 else { return "numbers after Z" }
            var nums: [Double] = []
            for _ in 0..<n {
                guard i < tokens.count, let v = Double(tokens[i]) else { return "'\(cmd)' is short of numbers" }
                nums.append(v); i += 1
            }
            let rel = cmd.isLowercase
            switch up {
            case "H": x = rel ? x + nums[0] : nums[0]
            case "V": y = rel ? y + nums[0] : nums[0]
            case "A":
                guard nums[3] == 0 || nums[3] == 1, nums[4] == 0 || nums[4] == 1 else { return "an arc flag that is not 0 or 1" }
                x = rel ? x + nums[5] : nums[5]; y = rel ? y + nums[6] : nums[6]
            default:
                x = rel ? x + nums[n - 2] : nums[n - 2]; y = rel ? y + nums[n - 1] : nums[n - 1]
            }
            if up == "M" { sx = x; sy = y; if cmd == "M" { cmd = "L" } else { cmd = "l" } }
            guard inBox(x, y) else { return "a point outside the box: (\(x), \(y))" }
            drew += 1
        }
        return drew > 1 ? nil : "nothing drawn"
    }

    func testHisChoiceIsKeptThroughEditsBackupsAndRecords() {
        var lib = Library()
        var hiking = list("Hiking", group: "GA"); hiking.items = [newItem(name: "Map")]
        lib.saveTemplate(hiking)
        let id = lib.templates[0].id
        XCTAssertEqual(lib.icon(for: lib.resolvedTemplate(id: id)!), "hiking", "the suggestion before any choice")

        XCTAssertTrue(lib.setTemplateIcon(id: id, key: "tent"))
        XCTAssertEqual(lib.icon(for: lib.resolvedTemplate(id: id)!), "tent")
        XCTAssertEqual(Library.icon(of: lib.resolvedTemplate(id: id)!), "tent", "a resolved template does not carry the choice")
        XCTAssertEqual(Library.icon(of: lib.resolvedTemplates()[0]), "tent")
        // Later edits save the whole template again — the choice must survive them.
        _ = lib.addToTemplate(templateId: id, name: "Headlamp")
        XCTAssertTrue(lib.renameTemplate(id: id, to: "Hiking & camping"))
        XCTAssertEqual(lib.chosenIcon(templateId: id), "tent", "an edit to the template lost the icon")
        // …and the stored records and a backup carry it.
        let back = Library(records: lib.records())
        XCTAssertEqual(back.chosenIcon(templateId: id), "tent", "the stored records lost the icon")
        let (restored, report) = Importer.library(from: lib.backupFile())
        XCTAssertTrue(report.isFaithful, "the backup does not come back the same: \(report.mismatches.prefix(3))")
        XCTAssertEqual(restored.chosenIcon(templateId: id), "tent", "a backup lost the icon")

        XCTAssertTrue(lib.setTemplateIcon(id: id, key: Library.letterIcon))
        XCTAssertNil(lib.icon(for: lib.resolvedTemplate(id: id)!), "letter means no icon")
        XCTAssertTrue(lib.setTemplateIcon(id: id, key: nil))
        XCTAssertEqual(lib.icon(for: lib.resolvedTemplate(id: id)!), "hiking", "back to the suggestion (the name says hiking first)")
        XCTAssertFalse(lib.setTemplateIcon(id: "nope", key: "tent"))
    }
}
