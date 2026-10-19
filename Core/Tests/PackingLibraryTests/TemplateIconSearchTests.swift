import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Search in the icon picker (0.91) — his words, 19 Oct 2026: "Also add the possibility to search
/// for icons, and also add alternative names so that the search is easier to perform. But I don't
/// know if the alternative names need to be visible, but it would be good to get more hits when
/// searching." An icon is found by its label and by hidden other words — English, Swedish, German.
final class TemplateIconSearchTests: XCTestCase {
    private func keys(_ query: String) -> [String] { TemplateIconCatalog.find(query).map(\.key) }

    func testHisWordsFindTheIconInEnglishSwedishAndGerman() {
        // The words he might type, each finding the icon he means.
        let wanted: [(String, String)] = [
            ("flyg", "plane"), ("Flug", "plane"), ("airport", "plane"), ("flight", "plane"),
            ("bil", "car"), ("Auto", "car"),
            ("husbil", "rv"), ("Wohnmobil", "rv"), ("camper", "rv"),
            ("cykel", "bike"), ("Fahrrad", "bike"), ("cycling", "bike"),
            ("simma", "swim"), ("schwimmen", "swim"), ("pool", "swim"), ("bad", "swim"),
            ("vandring", "hiking"), ("wandern", "hiking"), ("trek", "hiking"),
            ("strand", "lounger"), ("strand", "beach"), ("sea", "beach"),
            ("tåg", "train"), ("Zug", "train"), ("färja", "ferry"), ("tält", "tent"), ("Zelt", "tent"),
            ("skidor", "ski"), ("löpning", "run"), ("styrka", "strength"), ("gym", "strength"),
            ("bastu", "sauna"), ("isbad", "icebath"), ("solkräm", "suncream"), ("Sonnencreme", "suncream"),
            ("kaffe", "coffee"), ("fika", "coffee"), ("hund", "paw"), ("dog", "paw"), ("barn", "kids"),
            ("laddare", "plug"), ("charger", "plug"), ("medicin", "pill"), ("tvätt", "laundry"),
            ("jobb", "laptop"), ("work", "laptop"), ("helg", "weekendbag"), ("weekend", "weekendbag"),
        ]
        for (typed, key) in wanted {
            XCTAssertTrue(keys(typed).contains(key), "'\(typed)' does not find \(key): \(keys(typed))")
        }
        // Case, spaces and accents do not count; the words are one phrase anywhere in a word.
        XCTAssertEqual(keys("FLYG"), keys("flyg"))
        XCTAssertEqual(keys("  flyg  "), keys("flyg"))
        XCTAssertTrue(keys("fjall").contains("mountain"), "an accent left out does not find fjäll")
        XCTAssertTrue(keys("schlussel").contains("keys"), "an accent left out does not find Schlüssel")
        // …but an accent typed counts: in Swedish å is a letter of its own — a boat is no bath.
        XCTAssertEqual(keys("båt"), ["ferry", "sail"], "båt found a bath or sunbathing")
        XCTAssertEqual(keys("Båt"), ["ferry", "sail"])
        XCTAssertEqual(keys("flyg"), ["plane"], "flyg finds more than the plane")
        // His label still finds it, and what is written under the tile counts as before.
        XCTAssertTrue(keys("on the beach").contains("lounger"))
        XCTAssertTrue(keys("Racket").contains("racket"))
        // Nothing for nonsense; everything for nothing typed — in the picker's order.
        XCTAssertEqual(keys("zzz"), [], "zzz finds an icon")
        XCTAssertEqual(keys(""), TemplateIconCatalog.all.map(\.key))
        XCTAssertEqual(keys("   "), TemplateIconCatalog.all.map(\.key), "spaces alone are a search")
        // The headings are not searched: "food" is the Food icon (and the meal words), not all of City, food and fun.
        XCTAssertFalse(keys("food").contains("camera"), "a heading's words brought its whole group")
    }

    func testTheResultsKeepTheirHeadingsInThePickersOrder() {
        let found = TemplateIconCatalog.grouped(matching: "strand")
        XCTAssertEqual(found.map(\.group), [.beach], "strand: \(found.map(\.group))")
        XCTAssertEqual(found.first?.icons.map(\.key), ["lounger", "beach", "towel", "beachball"], "strand")
        let boat = TemplateIconCatalog.grouped(matching: "båt")
        XCTAssertEqual(boat.map(\.group), [.travel, .beach], "a boat is a ferry and a sail, under their own headings")
        XCTAssertEqual(boat.flatMap(\.icons).map(\.key), ["ferry", "sail"])
        XCTAssertTrue(TemplateIconCatalog.grouped(matching: "zzz").isEmpty)
        XCTAssertEqual(TemplateIconCatalog.grouped(matching: "").map(\.group), TemplateIconCatalog.grouped.map(\.group))
    }

    /// 0.92 (his "Could we add some icons again. Love the one we have."): the 41 new icons are found
    /// by their own other words — Swedish as he types them, English and German too — and no search
    /// he relies on grows: "flyg", "båt", "strand" and "fahrrad" find what they found before.
    func testTheNewIconsAreFoundByTheirOtherNamesAndNoOldSearchGrows() {
        let wanted: [(String, String)] = [
            ("skridskor", "skate"), ("pulka", "sled"), ("längdskidor", "xcski"), ("vasaloppet", "xcski"),
            ("sovsäck", "sleepingbag"), ("kikare", "binoculars"), ("termos", "thermos"), ("vantar", "mittens"),
            ("regnjacka", "jacket"), ("svamp", "mushroom"), ("stuga", "cottage"), ("utomlands", "globe"),
            ("nackkudde", "pillow"), ("elsparkcykel", "scooter"), ("roddmaskin", "rowing"), ("erg", "rowing"),
            ("stoppur", "stopwatch"), ("puls", "pulse"), ("tävling", "trophy"), ("cykelhjälm", "helmet"),
            ("cykelpump", "pump"), ("våtdräkt", "wetsuit"), ("dykflaska", "tank"), ("yogamatta", "yogamat"),
            ("sup", "sup"), ("flytväst", "lifejacket"), ("glass", "icecream"), ("hink", "bucket"),
            ("skärgård", "anchor"), ("midsommar", "midsummer"), ("pizzeria", "pizza"), ("utställning", "museum"),
            ("tårta", "cake"), ("bröllop", "rings"), ("julgran", "xmastree"), ("bio", "cinema"),
            ("tivoli", "ferriswheel"), ("tandborste", "toothbrush"), ("powerbank", "battery"), ("namnbricka", "badge"),
            ("anteckningar", "notebook"), ("slips", "suit"), ("barnvagn", "pram"),
            ("Schlittschuh", "skate"), ("Riesenrad", "ferriswheel"), ("Kinderwagen", "pram"), ("Neoprenanzug", "wetsuit"),
            ("rowing machine", "rowing"), ("heart rate", "pulse"), ("maypole", "midsummer"), ("lanyard", "badge"),
        ]
        for (typed, key) in wanted {
            XCTAssertTrue(keys(typed).contains(key), "'\(typed)' does not find \(key): \(keys(typed))")
        }
        // A word that is only theirs finds them alone.
        XCTAssertEqual(keys("skridskor"), ["skate"])
        XCTAssertEqual(keys("midsommar"), ["midsummer"])
        XCTAssertEqual(keys("barnvagn"), ["pram"])
        // The searches he relies on are as they were.
        XCTAssertEqual(keys("flyg"), ["plane"], "flyg finds more than the plane")
        XCTAssertEqual(keys("båt"), ["ferry", "sail"], "båt finds more than the ferry and the sail")
        XCTAssertEqual(keys("fahrrad"), ["bike"], "fahrrad finds more than the bike")
        XCTAssertEqual(TemplateIconCatalog.grouped(matching: "strand").flatMap(\.icons).map(\.key),
                       ["lounger", "beach", "towel", "beachball"], "strand finds more than the four beach icons")
    }

    /// Every icon has other words to be found by, and every list of them belongs to an icon.
    func testEveryIconHasItsOtherWordsAndNoneIsLost() {
        let known = Set(TemplateIconCatalog.all.map(\.key))
        for key in TemplateIconCatalog.keywords.keys {
            XCTAssertTrue(known.contains(key), "other words for an icon that is not there: \(key)")
        }
        for icon in TemplateIconCatalog.all {
            let words = TemplateIconCatalog.keywords[icon.key] ?? []
            XCTAssertGreaterThanOrEqual(words.count, 3, "\(icon.key) has only \(words.count) other words")
            let norm = words.map { normName($0) }
            XCTAssertEqual(Set(norm).count, norm.count, "\(icon.key) has a word twice: \(norm)")
            for w in words {
                XCTAssertFalse(jsTrim(w).isEmpty, "\(icon.key) has a blank word")
                XCTAssertEqual(w, normName(w), "\(icon.key): '\(w)' is not written as it is matched")
                XCTAssertNil(w.unicodeScalars.first { $0.properties.isEmojiPresentation }, "\(icon.key): an emoji")
                // A word is found by itself — it would be no use otherwise.
                XCTAssertTrue(keys(w).contains(icon.key), "\(icon.key): its word '\(w)' does not find it")
            }
        }
    }
}
