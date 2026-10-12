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

    /// Every icon: a drawing the app can draw, a label, a key of its own — and every
    /// key a template may have stored since 0.46 still there.
    func testEveryIconHasADrawingALabelAndItsOwnKey() {
        let all = TemplateIconCatalog.all
        XCTAssertEqual(all.count, 90, "the picker's count")
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
                     "Skidor", "Cykel", "Löpning", "Simning", "Styrka", "Fiske", "Resa"]
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
