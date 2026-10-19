import XCTest
@testable import PackingLibrary

/// Search in How it works (0.90, his ask of 19 Oct 2026): only the parts and paragraphs that
/// hold the words, matched as the app's other searches match (case and spaces do not count)
/// and, the guide being prose, accents and curly or straight quotes not counting either.
final class GuideSearchTests: XCTestCase {
    private let parts = [
        GuideSearch.Part(title: "Home", paragraphs: ["Grab and go: tick what is in your hand.",
                                                     "Create new trip: a name, then the dates.",
                                                     "The countdown to your next trip."]),
        GuideSearch.Part(title: "Care", paragraphs: ["Your things: every thing you own.",
                                                     "A kit \u{2014} a pouch that stays packed. Take out marks one as out of the kit.",
                                                     "Bags: your bags with max weight."]),
        GuideSearch.Part(title: "iPhone and Mac", paragraphs: ["Both hold the same library through iCloud.",
                                                               "On the Mac, Escape closes the window."]),
    ]

    private func words(_ text: String, _ query: String) -> [String] {
        GuideSearch.ranges(of: GuideSearch.needle(query), in: text).map { String(text[$0]) }
    }

    func testOnlyTheParagraphsHoldingTheWordsEachUnderItsPart() {
        let found = GuideSearch.find("pouch that", in: parts)
        XCTAssertEqual(found, [GuideSearch.Found(part: 1, titleHolds: false, paragraphs: [1], places: 1)])
        let two = GuideSearch.find("TRIP", in: parts)
        XCTAssertEqual(two.map(\.part), [0], "only Home's paragraphs say trip")
        XCTAssertEqual(two.first?.paragraphs, [1, 2], "the two paragraphs that say it, in order — not the first")
        XCTAssertEqual(GuideSearch.placesWords(two), "2 places")
        let across = GuideSearch.find("the", in: parts)
        XCTAssertEqual(across.map(\.part), [0, 1, 2], "every part that says it, in the guide's order")
        XCTAssertEqual(across[1].paragraphs, [1], "Care: only the kit paragraph says \"the\"")
    }

    func testAHeadingAloneShowsItsWholePart() {
        let found = GuideSearch.find("iphone and MAC", in: parts)
        XCTAssertEqual(found, [GuideSearch.Found(part: 2, titleHolds: true, paragraphs: [0, 1], places: 1)],
                       "only the heading says it: the part is about it, so all of it shows")
        XCTAssertEqual(GuideSearch.placesWords(found), "1 place")
        // Heading and paragraphs both: just the paragraphs that say it, and the heading counts.
        let mac = GuideSearch.find("mac", in: parts)
        XCTAssertEqual(mac, [GuideSearch.Found(part: 2, titleHolds: true, paragraphs: [1], places: 2)])
    }

    func testCaseSpacesAccentsAndQuotesDoNotCount() {
        let text = "Don\u{2019}t forget the caf\u{00E9}\u{2019}s \u{201C}blue pouch\u{201D} \u{2014} don't."
        XCTAssertEqual(words(text, "DON'T"), ["Don\u{2019}t", "don't"], "a straight ' finds the curly one too")
        XCTAssertEqual(words(text, "don\u{2019}t"), ["Don\u{2019}t", "don't"], "the iPhone's curly ' finds the straight one too")
        XCTAssertEqual(words(text, "cafe"), ["caf\u{00E9}"], "accents do not count")
        XCTAssertEqual(words(text, "  \"blue   pouch\" "), ["\u{201C}blue pouch\u{201D}"], "spaces as normName counts them; straight \" finds curly")
        XCTAssertEqual(words(text, "zzz"), [])
        XCTAssertTrue(GuideSearch.find("caf\u{00C9}", in: [GuideSearch.Part(title: "x", paragraphs: [text])]).count == 1)
    }

    func testEveryPlaceIsMarkedNoneOverlapping() {
        XCTAssertEqual(words("Kit, kit and KIT.", "kit"), ["Kit", "kit", "KIT"])
        XCTAssertEqual(words("aaaa", "aa"), ["aa", "aa"], "places do not overlap")
        // The ranges are the words as written, even after a curly quote changed nothing in length.
        let text = "A thing\u{2019}s page: Kit."
        let r = GuideSearch.ranges(of: GuideSearch.needle("kit"), in: text)
        XCTAssertEqual(r.map { text.distance(from: text.startIndex, to: $0.lowerBound) }, [16])
    }

    func testNoSearchFindsNothingAndShowsTheWholeGuide() {
        XCTAssertEqual(GuideSearch.find("", in: parts), [])
        XCTAssertEqual(GuideSearch.find("   ", in: parts), [], "spaces alone are no search")
        XCTAssertEqual(GuideSearch.needle("  "), "")
        XCTAssertEqual(GuideSearch.ranges(of: "", in: "anything"), [])
        XCTAssertEqual(GuideSearch.find("qwxz", in: parts), [], "nothing says it: nothing found")
    }
}
