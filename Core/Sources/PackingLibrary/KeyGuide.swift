import Foundation

// Keyboard shortcuts in How it works (0.103) — his ask of 27 Oct 2026: "make the list visually
// pleasing and easy to read for a human."
//
// Every key the app answers, written from the code, in one place: the guide draws it as cards of
// rows (the action on the left, the keys as small key caps on the right), the search reads the same
// words, and VoiceOver says "Command S", never a symbol. The screen is in the app
// (`Guide/KeysGuide.swift`); WHAT it says, and how the search and VoiceOver read it, is decided here,
// where the model's tests can hold it.
//
// Adding a key to the app means adding it here: `KeyGuideTests` fails when a key the app answers is
// missing (it lists the ones that must be there).

public enum KeyGuide {
    /// One key: what is drawn on its cap, and what VoiceOver says.
    public struct Key: Equatable, Sendable {
        public let cap: String
        public let spoken: String
        public init(_ cap: String, _ spoken: String) {
            self.cap = cap
            self.spoken = spoken
        }

        public static let command = Key("\u{2318}", "Command")
        public static let shift = Key("\u{21E7}", "Shift")
        public static let option = Key("\u{2325}", "Option")
        public static let escape = Key("Esc", "Escape")
        public static let tab = Key("Tab", "Tab")
        public static let space = Key("Space", "Space")
        public static let `return` = Key("Return", "Return")
        public static let up = Key("\u{2191}", "Up arrow")
        public static let down = Key("\u{2193}", "Down arrow")
        public static let left = Key("\u{2190}", "Left arrow")
        public static let right = Key("\u{2192}", "Right arrow")
        /// Any letter keys: "type its first letters".
        public static let letters = Key("A\u{2013}Z", "letters")
        public static let comma = Key(",", "comma")
        public static let period = Key(".", "period")
        /// A letter or a digit, drawn upper-case: "S", "1".
        public static func character(_ c: String) -> Key { Key(c.uppercased(), c.uppercased()) }
    }

    /// Keys pressed together, left to right: ⌘ S.
    public struct Chord: Equatable, Sendable {
        public let keys: [Key]
        public init(_ keys: [Key]) { self.keys = keys }
        /// What VoiceOver says: "Command S".
        public var spoken: String { keys.map(\.spoken).joined(separator: " ") }
        /// The caps run together, as a menu shows them: "⌘S".
        public var symbols: String { keys.map(\.cap).joined() }
    }

    /// One thing the keys do. More than one chord = either will do (Space or ↓).
    public struct Row: Equatable, Sendable {
        public let action: String
        public let chords: [Chord]
        /// A short line under the action, when the action alone leaves a question.
        public let note: String?
        public init(_ action: String, _ chords: [Chord], note: String? = nil) {
            self.action = action
            self.chords = chords
            self.note = note
        }

        /// What VoiceOver says after the action: "Command S", or "Space, or Down arrow".
        public var spoken: String { chords.map(\.spoken).joined(separator: ", or ") }
        /// What VoiceOver reads for the whole row: "Save, or Done, Command S" (one label — the Mac does not hand a
        /// row's separate value on, and a symbol is never read).
        public var voiceOver: String { "\(action), \(spoken)" }
        /// "⌘S", or "Space or ↓" — also what the guide's search reads, so the symbol he sees in a menu finds it.
        public var symbols: String { chords.map(\.symbols).joined(separator: " or ") }
    }

    /// Where the keys of a card work.
    public enum Reach: String, Equatable, Sendable {
        /// The Mac — and an iPhone or iPad with a keyboard attached.
        case withKeyboard
        /// The Mac only.
        case macOnly

        public var words: String {
            switch self {
            case .withKeyboard: return "Mac, and iPhone or iPad with a keyboard"
            case .macOnly: return "Mac only"
            }
        }
    }

    /// One card (a group of keys): a heading, where its keys work, an optional line, and its rows.
    public struct Card: Equatable, Sendable {
        /// The ids' part: "any", "go", …
        public let id: String
        public let title: String
        public let reach: Reach
        public let line: String?
        public let rows: [Row]
    }

    public static let title = "Keyboard shortcuts"

    /// The line at the top: the Mac first, then the iPhone.
    public static let intro =
        "These are the Mac\u{2019}s keys, most of them also in its menu bar. On an iPhone or iPad with a keyboard attached, the same keys work where a card says so."

    private static func chord(_ keys: Key...) -> Chord { Chord(keys) }
    private static func cmd(_ c: String) -> Chord { Chord([.command, .character(c)]) }

    public static let cards: [Card] = [
        Card(id: "any", title: "On any page", reach: .withKeyboard, line: nil, rows: [
            Row("Save, or Done", [cmd("s")],
                note: "On the Mac also on a page that only shows something \u{2014} a trip, How it works, Search \u{2014} where it closes the page."),
            Row("Cancel, or close the page", [chord(.escape), chord(.command, .period)],
                note: "Esc never saves anything. \u{2318}. is Esc on an iPhone."),
            Row("Add what you typed in an Add field", [chord(.return)]),
        ]),
        Card(id: "go", title: "Go to", reach: .macOnly,
              line: "The Mac\u{2019}s Go menu. Switched off while a page is open: finish it with \u{2318}S or Esc first.",
              rows: [
            Row("Home", [cmd("1")]),
            Row("Trips", [cmd("2")]),
            Row("Templates", [cmd("3")]),
            Row("Care", [cmd("4")]),
            Row("To do", [cmd("5")]),
            Row("Settings", [cmd("6"), chord(.command, .comma)]),
        ]),
        // Quick open (0.105, his yes of 28 Oct 2026): ⌘K, a few letters, Return.
        Card(id: "quick", title: "Quick open", reach: .macOnly,
              line: "Type a few letters of a thing, a trip or a template \u{2014} a thing\u{2019}s Swedish name too \u{2014} or of a command: a tab, New thing, Keyboard shortcuts, Sync details. On a trip\u{2019}s page: its Group by choices and Fold all.",
              rows: [
            Row("Open Quick open", [cmd("k")], note: "Also in the Go menu. Off while a page other than a trip is open."),
            Row("Move through what it found", [chord(.up, .down)]),
            Row("Open the lit one, or run it", [chord(.return)]),
            Row("Close it", [chord(.escape)]),
        ]),
        // New (0.105, his words of 28 Oct 2026): "⌘N opens a new, empty thing's page from anywhere in the app … ⌘N
        // currently opens a new window. That would move to ⌥⌘N, Apple's usual alternative."
        Card(id: "new", title: "New", reach: .macOnly,
              line: "The Mac\u{2019}s File menu, as in Notes and Reminders. Off while a page is open \u{2014} except Your things, where \u{2318}N opens a new thing\u{2019}s page too, and a thing\u{2019}s page, where it is Save and New.",
              rows: [
            Row("New thing", [cmd("n")], note: "An empty thing\u{2019}s page, from any tab, the cursor in Name. Save makes the thing; Cancel or Esc makes nothing."),
            Row("New window", [chord(.option, .command, .character("n"))]),
        ]),
        Card(id: "search", title: "Search", reach: .macOnly, line: nil, rows: [
            Row("Search How it works", [chord(.command, .character("f"))]),
            Row("Find an icon, on a template\u{2019}s icon page", [chord(.command, .character("f"))]),
            Row("Empty the search", [chord(.escape)], note: "A second Esc closes the page."),
        ]),
        Card(id: "edit", title: "Editing a list or a page", reach: .withKeyboard, line: nil, rows: [
            Row("Save a grab list, a template, your lists or an activity area", [cmd("s")]),
            Row("Throw away what you changed", [chord(.escape)],
                note: "A grab list stays open. On a template that is being arranged, Esc ends Arrange first; a second Esc closes the page."),
        ]),
        Card(id: "thing", title: "A thing\u{2019}s page", reach: .macOnly,
              line: "Also the Thing menu. Tab walks every field, top to bottom.", rows: [
            Row("Save the thing", [cmd("s")]),
            Row("Save, and start the next thing with the same choices", [cmd("n")]),
            Row("Next thing in the list the page came from", [chord(.command, .down)]),
            Row("Previous thing", [chord(.command, .up)]),
            Row("Jump to a field by its name", [cmd("j")]),
            Row("Next field", [chord(.tab)]),
            Row("Previous field", [chord(.shift, .tab)]),
            Row("Save from any field but Notes", [chord(.return)], note: "In Notes, Return starts a new line."),
        ]),
        Card(id: "lists", title: "Lists and drop-downs", reach: .macOnly,
              line: "On a thing\u{2019}s page, with the field lit.", rows: [
            Row("Open a drop-down", [chord(.space), chord(.down)]),
            Row("Move through its choices", [chord(.up, .down)]),
            Row("Jump to a choice by typing", [chord(.letters)], note: "Its first letters, one after another."),
            Row("Choose the lit one", [chord(.return)]),
            Row("Close the list, and stay on the page", [chord(.escape)]),
            Row("Move along a row of pills", [chord(.left, .right)], note: "Templates, and Only on some trips."),
            Row("Switch the lit pill, or a switch", [chord(.space)]),
        ]),
        Card(id: "mac", title: "The Mac\u{2019}s windows", reach: .macOnly, line: nil, rows: [
            Row("Quit", [cmd("q")],
                note: "Asks first when a page holds a change you have not confirmed."),
            Row("Close the All your things window", [cmd("w")]),
        ]),
        // ⌘Z undo everywhere (0.105, Store/LibraryUndo.swift). The Mac's Edit menu; an iPhone shakes (a keyboard's
        // ⌘Z is not passed on to the app there — tried on the simulator, 28 Oct 2026).
        Card(id: "undo", title: "Undo and Redo", reach: .macOnly,
              line: "The Edit menu, which says what it takes back: \u{201C}Undo Tick Passport\u{201D}. On an iPhone, shake it, or swipe left with three fingers.",
              rows: [
            Row("Undo the last change, whatever page it was on", [cmd("z")],
                note: "Up to 50 steps. What your other device changed since stays. On a page with its own fields \u{2318}Z undoes your typing there."),
            Row("Redo what Undo took back", [chord(.shift, .command, .character("z"))]),
        ]),
    ]

    /// One paragraph as the guide's search reads and shows it: a lead (an action, or a card's heading) and the words after it.
    public struct Paragraph: Equatable, Sendable {
        public let lead: String?
        public let text: String
        /// As it is searched and shown: "Save, or Done — Command S (⌘S) …".
        public var said: String { lead.map { "\($0) \u{2014} \(text)" } ?? text }
    }

    /// Everything the topic says, in order, as paragraphs: the line at the top, then for each card its
    /// heading with where its keys work (and its line), then each row — the action, the keys in words
    /// and in symbols (so the symbol he sees in a menu finds it), its note, and the card it is on.
    /// The guide's search is built from these, so it can never miss a word the cards show.
    public static let paragraphs: [Paragraph] = {
        var out = [Paragraph(lead: nil, text: intro)]
        for card in cards {
            out.append(Paragraph(lead: card.title, text: ([card.reach.words + "."] + (card.line.map { [$0] } ?? [])).joined(separator: " ")))
            for row in card.rows {
                let note = row.note.map { " " + $0 } ?? ""
                out.append(Paragraph(lead: row.action, text: "\(row.spoken) (\(row.symbols)).\(note) \(card.title)."))
            }
        }
        return out
    }()

    /// The topic as the guide's search takes it.
    public static var searchPart: GuideSearch.Part {
        GuideSearch.Part(title: title, paragraphs: paragraphs.map(\.said))
    }
}
