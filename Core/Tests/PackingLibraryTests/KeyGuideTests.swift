import XCTest
@testable import PackingLibrary

/// Keyboard shortcuts in How it works (0.103, his ask of 27 Oct 2026): every key the app answers is in
/// the topic, VoiceOver says "Command S" and never a symbol, and the guide's search finds the keys by the
/// words he would type — the key names, the symbols he sees in a menu, and the actions.
final class KeyGuideTests: XCTestCase {
    private var rows: [(card: String, row: KeyGuide.Row)] {
        KeyGuide.cards.flatMap { card in card.rows.map { (card.id, $0) } }
    }

    /// The keys the code answers (read from `keyboardShortcut`, `ThingKeys`, `DropDown`, the Go menu, the
    /// Guide's and the icon picker's ⌘F, `QuitCommand`): card id, a word of the action, the keys.
    func testEveryKeyTheAppAnswersIsInTheTopic() {
        let must: [(card: String, action: String, symbols: String)] = [
            ("any", "Save, or Done", "⌘S"), ("any", "Cancel", "Esc or ⌘."), ("any", "Add what you typed", "Return"),
            ("go", "Home", "⌘1"), ("go", "Trips", "⌘2"), ("go", "Templates", "⌘3"),
            ("go", "Care", "⌘4"), ("go", "To do", "⌘5"), ("go", "Settings", "⌘6 or ⌘,"),
            ("search", "Search How it works", "⌘F"), ("search", "Find an icon", "⌘F"), ("search", "Empty the search", "Esc"),
            ("edit", "Save a grab list", "⌘S"), ("edit", "Throw away", "Esc"),
            ("thing", "Save the thing", "⌘S"), ("thing", "start the next thing", "⌘N"),
            ("thing", "Next thing", "⌘↓"), ("thing", "Previous thing", "⌘↑"), ("thing", "Jump to a field", "⌘J"),
            ("thing", "Next field", "Tab"), ("thing", "Previous field", "⇧Tab"), ("thing", "any field but Notes", "Return"),
            ("lists", "Open a drop-down", "Space or ↓"), ("lists", "Move through", "↑↓"),
            ("lists", "Jump to a choice", "A–Z"), ("lists", "Choose the lit one", "Return"),
            ("lists", "Close the list", "Esc"), ("lists", "row of pills", "←→"), ("lists", "Switch the lit pill", "Space"),
            ("trip", "Select a line, or let it go", "⌘Click"), ("trip", "Select the lines between", "⇧Click"),
            ("trip", "Select every line shown", "⌘A"), ("trip", "Tick the selected lines", "Space"),
            ("trip", "Clear the selection", "Esc"),
            ("mac", "Quit", "⌘Q"), ("mac", "New window", "⌘N"), ("mac", "Close the All your things window", "⌘W"),
        ]
        var missing: [String] = []
        for key in must {
            let hit = rows.first { $0.card == key.card && $0.row.action.contains(key.action) }
            if hit == nil { missing.append("\(key.card): no row for \(key.action)") }
            else if hit!.row.symbols != key.symbols { missing.append("\(key.action) says \(hit!.row.symbols), not \(key.symbols)") }
        }
        XCTAssertEqual(missing, [], "keys the app answers that the topic leaves out or gets wrong")
    }

    /// The six tabs, in the tab bar's order, ⌘1 to ⌘6 (Apple's own convention).
    func testTheGoCardListsTheSixTabsInTheirOrder() throws {
        let go = try XCTUnwrap(KeyGuide.cards.first { $0.id == "go" })
        XCTAssertEqual(go.rows.map(\.action), ["Home", "Trips", "Templates", "Care", "To do", "Settings"])
        XCTAssertEqual(go.rows.map { $0.chords.first?.symbols }, ["⌘1", "⌘2", "⌘3", "⌘4", "⌘5", "⌘6"])
    }

    /// VoiceOver reads words: "Command S", never ⌘ — every key has a spoken name.
    func testVoiceOverSaysCommandSAndNeverASymbol() {
        let save = rows.first { $0.card == "any" && $0.row.action == "Save, or Done" }?.row
        XCTAssertEqual(save?.spoken, "Command S")
        XCTAssertEqual(save?.voiceOver, "Save, or Done, Command S", "one label for the whole row")
        XCTAssertEqual(rows.first { $0.row.action == "Previous field" }?.row.spoken, "Shift Tab")
        XCTAssertEqual(rows.first { $0.row.action == "Next thing in the list the page came from" }?.row.spoken, "Command Down arrow")
        XCTAssertEqual(rows.first { $0.row.action == "Open a drop-down" }?.row.spoken, "Space, or Down arrow")
        XCTAssertEqual(rows.first { $0.row.action == "Cancel, or close the page" }?.row.spoken, "Escape, or Command period")
        let symbols = CharacterSet(charactersIn: "⌘⇧⌥⌃↑↓←→⎋⏎⇥–")
        for (card, row) in rows {
            XCTAssertNil(row.spoken.rangeOfCharacter(from: symbols), "\(card): \(row.action) is read out as '\(row.spoken)'")
        }
    }

    /// Found by the words he would type: a key's name, the symbol in the menu, the action.
    func testTheSearchFindsTheKeysByNameSymbolAndAction() {
        let part = KeyGuide.searchPart
        func found(_ words: String) -> [String] {
            guard let f = GuideSearch.find(words, in: [part]).first else { return [] }
            return f.paragraphs.map { part.paragraphs[$0] }
        }
        XCTAssertTrue(found("command s").contains { $0.hasPrefix("Save, or Done") }, "Command S")
        XCTAssertTrue(found("⌘s").contains { $0.hasPrefix("Save, or Done") }, "the symbol")
        XCTAssertTrue(found("⌘1").contains { $0.hasPrefix("Home") }, "⌘1")
        XCTAssertTrue(found("escape").contains { $0.hasPrefix("Cancel, or close the page") }, "Escape")
        XCTAssertTrue(found("esc").contains { $0.hasPrefix("Empty the search") }, "Esc")
        XCTAssertTrue(found("shift tab").contains { $0.hasPrefix("Previous field") }, "Shift Tab")
        XCTAssertTrue(found("down arrow").contains { $0.hasPrefix("Open a drop-down") }, "Down arrow")
        XCTAssertTrue(found("quit").contains { $0.hasPrefix("Quit") }, "an action")
        XCTAssertTrue(found("jump").contains { $0.hasPrefix("Jump to a field") }, "an action")
        XCTAssertTrue(found("go menu").contains { $0.hasPrefix("Go to") }, "the Go menu")
        XCTAssertTrue(found("keyboard attached").contains { $0.contains("iPhone or iPad") }, "the line at the top")
        XCTAssertEqual(GuideSearch.find("keyboard shortcuts", in: [part]).first?.titleHolds, true, "the heading")
        XCTAssertTrue(found("qxzqxz").isEmpty)
    }

    /// The line at the top: the Mac first, then the iPhone and iPad with a keyboard.
    func testTheLineAtTheTopSaysTheMacFirstThenTheIPhone() {
        XCTAssertTrue(KeyGuide.intro.hasPrefix("These are the Mac"))
        XCTAssertTrue(KeyGuide.intro.contains("iPhone or iPad with a keyboard attached"))
        XCTAssertEqual(KeyGuide.cards.map(\.id), ["any", "go", "search", "edit", "thing", "trip", "lists", "mac"])
        XCTAssertEqual(KeyGuide.cards.first?.reach.words, "Mac, and iPhone or iPad with a keyboard")
        XCTAssertEqual(KeyGuide.cards.first { $0.id == "thing" }?.reach.words, "Mac only")
        // The tab keys are the Mac's Go menu; an iPhone or iPad keeps ⌘S only where a page has a real Save.
        XCTAssertEqual(KeyGuide.cards.first { $0.id == "go" }?.reach.words, "Mac only")
        XCTAssertEqual(KeyGuide.cards.first { $0.id == "edit" }?.reach.words, "Mac, and iPhone or iPad with a keyboard")
    }
}
