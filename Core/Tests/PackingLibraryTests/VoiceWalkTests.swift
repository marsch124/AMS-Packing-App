import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Hands-free packing, a test version (spec 07 part 10, 0.71): the five words and their
/// forgiving list, the order the lines come in, and what the walk says after each word.
/// Invented things only — the repository is public.
final class VoiceWalkTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-07T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    // MARK: - The words

    func testEachOfTheFiveWordsIsUnderstoodAsItIsWritten() {
        for word in VoiceWord.allCases {
            XCTAssertEqual(VoiceWord.heard(word.rawValue), word, "\(word.rawValue) itself was not understood")
            XCTAssertEqual(VoiceWord.heard(word.rawValue.capitalized + "."), word, "\(word.rawValue) with a capital and a full stop")
        }
    }

    /// The forgiving part: what a recogniser writes for the word, and what he says naturally.
    func testWhatIsHeardIsMatchedForgivingly() {
        let cases: [(String, VoiceWord)] = [
            ("Packed it", .packed), ("pack", .packed), ("Pack it.", .packed), ("Packet", .packed), ("pact", .packed),
            ("got it", .packed), ("Done", .packed), ("yes", .packed), ("OK", .packed),
            ("Skip it", .skip), ("skipped", .skip), ("Not this time", .skip), ("set aside", .skip), ("Nope", .skip),
            ("Next", .later), ("next one", .later), ("Later on", .later), ("not yet", .later), ("pass", .later),
            ("Where's that?", .where), ("where is it", .where), ("wear", .where), ("Repeat", .where), ("again", .where),
            ("Stop!", .stop), ("That's all", .stop), ("I\u{2019}m done", .stop), ("all done", .stop), ("finished", .stop),
            ("um packed", .packed), ("  PACKED  ", .packed),
        ]
        for (said, word) in cases {
            XCTAssertEqual(VoiceWord.heard(said), word, "\u{201C}\(said)\u{201D} was not understood as \(word.rawValue)")
        }
    }

    func testOtherWordsAreNotUnderstood() {
        for said in ["", "   ", "hello", "garage", "no", "wait", "back", "goggles", "the", "not", "set"] {
            XCTAssertNil(VoiceWord.heard(said), "\u{201C}\(said)\u{201D} was taken for a word")
        }
    }

    /// The first word in what was heard wins, and at one place the longest phrase.
    func testTheFirstWordWinsAndTheLongestPhrase() {
        XCTAssertEqual(VoiceWord.heard("where did I pack it"), .where)
        XCTAssertEqual(VoiceWord.heard("packed, next"), .packed)
        XCTAssertEqual(VoiceWord.heard("all done"), .stop, "\u{201C}all done\u{201D} is stop, not \u{201C}done\u{201D}")
        XCTAssertEqual(VoiceWord.heard("done"), .packed)
        XCTAssertEqual(VoiceWord.heard("not this time"), .skip, "\u{201C}not this time\u{201D} is skip")
        XCTAssertEqual(VoiceWord.heard("not yet"), .later)
    }

    /// The list is ONE list: no phrase in two words' lists, each written as `normalised`
    /// makes what is heard — or it could never match.
    func testTheListIsOneListAndEveryPhraseCanBeHeard() {
        var owner: [String: VoiceWord] = [:]
        for (word, says) in VoiceWord.accepted {
            XCTAssertFalse(says.isEmpty)
            for phrase in says {
                XCTAssertNil(owner[phrase], "\u{201C}\(phrase)\u{201D} is in two lists: \(owner[phrase]?.rawValue ?? "") and \(word.rawValue)")
                owner[phrase] = word
                XCTAssertEqual(VoiceWord.normalised(phrase).joined(separator: " "), phrase, "\u{201C}\(phrase)\u{201D} is not written as it is heard")
                XCTAssertEqual(VoiceWord.heard(phrase), word, "\u{201C}\(phrase)\u{201D} is not understood as \(word.rawValue)")
            }
        }
        XCTAssertEqual(Set(VoiceWord.accepted.map(\.word)), Set(VoiceWord.allCases), "a word has no list")
        XCTAssertEqual(VoiceWord.expected.count, owner.count)
    }

    // MARK: - The order

    /// Bathroom cabinet: Toothbrush · Chest of drawers: Passport, Phone charger · Garage:
    /// Headlamp, Map · Hall closet: Hiking boots, Rain jacket · no place: Goggles — listed
    /// in a different order on the trip, as a trip's lines are.
    private func trip() -> TripEvent {
        var t = newEvent(name: "Weekend", startDate: "2026-11-06", endDate: "2026-11-08")
        t.nights = 2
        let lines: [(String, String)] = [("Passport", "Chest of drawers"), ("Phone charger", "Chest of drawers"),
                                         ("Toothbrush", "Bathroom cabinet"), ("Headlamp", "Garage"),
                                         ("Hiking boots", "Hall closet"), ("Rain jacket", "Hall closet"),
                                         ("Map", "Garage"), ("Goggles", "")]
        t.entries = lines.map { newItem(id: "e-\($0.0)", name: $0.0, storage: $0.1) }
        return t
    }

    private func library(_ t: TripEvent) -> Library {
        var lib = Library()
        lib.trips = [t]
        return lib
    }

    func testTheWalkGoesFromWhereAndLeavesOutWhatIsDone() {
        var t = trip()
        XCTAssertEqual(VoiceWalk(trip: t).steps.map(\.name),
                       ["Toothbrush", "Passport", "Phone charger", "Headlamp", "Map", "Hiking boots", "Rain jacket", "Goggles"])
        XCTAssertEqual(VoiceWalk(trip: t).steps.map(\.place).last, "No place set")
        t.entries[0].checked = true          // Passport packed
        t.entries[6].skipped = true          // Map set aside
        XCTAssertEqual(VoiceWalk(trip: t).steps.map(\.name),
                       ["Toothbrush", "Phone charger", "Headlamp", "Hiking boots", "Rain jacket", "Goggles"])
    }

    /// A place opened by its printed code (part 3) starts the walk there and goes round.
    func testAWalkCanStartAtAPlace() {
        let t = trip()
        XCTAssertEqual(VoiceWalk(trip: t, startAt: "garage").steps.map(\.name),
                       ["Headlamp", "Map", "Hiking boots", "Rain jacket", "Goggles", "Toothbrush", "Passport", "Phone charger"],
                       "the walk did not start at the Garage (named in small letters)")
        XCTAssertEqual(VoiceWalk(trip: t, startAt: "Attic").steps.first?.name, "Toothbrush", "a place the trip lacks moved the start")
        XCTAssertEqual(VoiceWalk(trip: t, startAt: "").steps.first?.name, "Toothbrush")
    }

    func testAThingOfSeveralSaysHowMany() {
        var t = trip()
        t.entries[3].qty = "2"
        t.entries[4].perNight = true
        let steps = VoiceWalk(trip: t).steps
        XCTAssertEqual(steps.first { $0.name == "Headlamp" }?.says, "Headlamp, 2")
        XCTAssertEqual(steps.first { $0.name == "Hiking boots" }?.says, "Hiking boots, 2", "a thing per night counts the nights")
        XCTAssertEqual(steps.first { $0.name == "Map" }?.says, "Map")
    }

    // MARK: - What is said

    /// The app's loop, as `VoiceWalker` runs it: the word's action on the library, then the
    /// walk moves on with the trip as it now is.
    private func say(_ word: VoiceWord, _ walk: inout VoiceWalk, _ lib: inout Library, heard: String? = "") -> String {
        lib.apply(walk.action(for: word), tripId: walk.tripId)
        return walk.answer(word, heard: heard == "" ? word.rawValue : heard, trip: lib.trip(walk.tripId))
    }

    func testTheWalkSaysThePlaceThenTheThingAndTheCountAtEachNewPlace() {
        var lib = library(trip())
        var walk = VoiceWalk(trip: lib.trips[0])
        XCTAssertEqual(walk.opening(), "8 to pack. Bathroom cabinet. Toothbrush.")
        XCTAssertEqual(walk.action(for: .packed), .tick(entryId: "e-Toothbrush"))
        XCTAssertEqual(say(.packed, &walk, &lib), "Bathroom cabinet done, 1 of 8. Chest of drawers. Passport.")
        XCTAssertTrue(lib.trips[0].entries[2].checked, "packed did not tick the line")
        XCTAssertEqual(walk.action(for: .skip), .setAside(entryId: "e-Passport"))
        XCTAssertEqual(say(.skip, &walk, &lib), "Phone charger.", "the same place is not said again")
        XCTAssertTrue(lib.trips[0].entries[0].skipped, "skip did not set the line aside")
        XCTAssertEqual(walk.action(for: .later), .none)
        XCTAssertEqual(say(.later, &walk, &lib), "Chest of drawers done, 1 of 7. Garage. Headlamp.",
                       "the count leaves out what was set aside, as the trip's own does")
        XCTAssertFalse(lib.trips[0].entries[1].checked, "later ticked the line")
        XCTAssertEqual(walk.action(for: .where), .none)
        XCTAssertEqual(say(.where, &walk, &lib), "Garage. Headlamp.", "where did not say the place again")
        XCTAssertEqual(walk.current?.name, "Headlamp", "where moved on")
        XCTAssertEqual(walk.action(for: .stop), .none)
        XCTAssertEqual(say(.stop, &walk, &lib), "Stopped. 1 of 7 packed.")
        XCTAssertTrue(walk.isOver)
        XCTAssertEqual(walk.action(for: .packed), .none, "a stopped walk still ticks")
        XCTAssertEqual(walk.summary, "Packed 1 · set aside 1 · later 1")
        XCTAssertEqual(walk.leftForLater, ["Phone charger"])
    }

    func testEveryFiveThingsInOnePlaceItSaysTheCount() {
        var t = newEvent(name: "Shelf")
        t.entries = (1...7).map { newItem(id: "s\($0)", name: "Thing \($0)", storage: "Garage") }
        var lib = library(t)
        var walk = VoiceWalk(trip: t)
        XCTAssertEqual(walk.opening(), "7 to pack. Garage. Thing 1.")
        var said: [String] = []
        for _ in 0..<6 { said.append(say(.packed, &walk, &lib)) }
        XCTAssertEqual(said, ["Thing 2.", "Thing 3.", "Thing 4.", "Thing 5.", "5 of 7. Thing 6.", "Thing 7."])
        XCTAssertEqual(say(.later, &walk, &lib), "That was everything. 6 of 7 packed. 1 left for later \u{2014} once more?")
        XCTAssertFalse(walk.isOver, "the walk ended without asking once more")
    }

    // MARK: - Once more (his yes of 7 Oct 2026)

    /// Left for later at the end: "N left for later — once more?"; yes (or packed) walks them
    /// again, and the summary counts both rounds.
    func testWhatWasLeftForLaterIsAskedOnceMore() {
        var lib = library(trip())
        var walk = VoiceWalk(trip: lib.trips[0])
        let first: [VoiceWord] = [.later, .packed, .later, .packed, .packed, .packed, .packed]
        var said = ""
        for w in first { said = say(w, &walk, &lib) }
        XCTAssertEqual(said, "Hall closet done, 5 of 8. No place set. Goggles.")
        said = say(.packed, &walk, &lib)
        XCTAssertEqual(said, "That was everything. 6 of 8 packed. 2 left for later \u{2014} once more?")
        XCTAssertTrue(walk.askingOnceMore)
        XCTAssertNil(walk.current)
        XCTAssertEqual(walk.action(for: .packed), .none, "yes to once more ticked something")
        XCTAssertEqual(say(.where, &walk, &lib), "2 left for later \u{2014} once more?", "where did not ask again")
        XCTAssertEqual(say(.packed, &walk, &lib, heard: "yes"), "Once more. Bathroom cabinet. Toothbrush.")
        XCTAssertEqual(walk.round, 2)
        XCTAssertEqual(walk.steps.map(\.name), ["Toothbrush", "Phone charger"])
        XCTAssertEqual(say(.packed, &walk, &lib), "Bathroom cabinet done, 7 of 8. Chest of drawers. Phone charger.")
        XCTAssertEqual(say(.later, &walk, &lib), "That was everything. 7 of 8 packed. 1 left for later.",
                       "the second round asked once more again")
        XCTAssertTrue(walk.isOver)
        XCTAssertEqual(walk.summary, "Packed 7 · set aside 0 · later 1", "the summary does not count both rounds")
    }

    /// Stop (or skip, or later) at "once more?" ends the walk; a line ticked meanwhile is not
    /// asked again, and with none left waiting there is no question.
    func testOnceMoreCanBeDeclinedAndOnlyAsksForWhatStillWaits() {
        var t = newEvent(name: "Two")
        t.entries = [newItem(id: "a", name: "Hat", storage: "Hall closet"), newItem(id: "b", name: "Cap", storage: "Hall closet")]
        var lib = library(t)
        var walk = VoiceWalk(trip: t)
        _ = say(.later, &walk, &lib)
        XCTAssertEqual(say(.later, &walk, &lib), "That was everything. 0 of 2 packed. 2 left for later \u{2014} once more?")
        XCTAssertEqual(say(.stop, &walk, &lib), "Stopped. 0 of 2 packed. 2 left for later.")
        XCTAssertTrue(walk.isOver)

        lib = library(t)
        walk = VoiceWalk(trip: t)
        _ = say(.later, &walk, &lib)
        lib.setChecked(true, tripId: t.id, entryId: "a")          // the hat packed by hand meanwhile
        XCTAssertEqual(say(.packed, &walk, &lib), "That was everything. 2 of 2 packed.", "asked once more for nothing")
        XCTAssertTrue(walk.isOver)
    }

    func testTheEndOfTheListSaysSo() {
        var t = newEvent(name: "Small")
        t.entries = [newItem(id: "a", name: "Hat", storage: "Hall closet")]
        var lib = library(t)
        var walk = VoiceWalk(trip: t)
        XCTAssertEqual(say(.packed, &walk, &lib), "That was everything. 1 of 1 packed.")
        XCTAssertTrue(walk.isOver)
        XCTAssertEqual(VoiceWalk(trip: lib.trips[0]).opening(), "Nothing left to pack.")
        XCTAssertTrue(VoiceWalk(trip: lib.trips[0]).isOver)
    }

    /// A line ticked meanwhile — on the other device, or by a tap — is passed over.
    func testALineTickedMeanwhileIsPassedOver() {
        var lib = library(trip())
        var walk = VoiceWalk(trip: lib.trips[0])
        lib.setChecked(true, tripId: walk.tripId, entryId: "e-Passport")
        lib.setAside(true, tripId: walk.tripId, entryId: "e-Phone charger")
        XCTAssertEqual(say(.packed, &walk, &lib), "Bathroom cabinet done, 2 of 7. Garage. Headlamp.")
    }

    /// His measure: how often a word was understood, taps apart; and the log of each answer.
    func testItCountsWhatItUnderstoodAndWhatWasTapped() {
        var lib = library(trip())
        var walk = VoiceWalk(trip: lib.trips[0])
        XCTAssertEqual(walk.understoodLine, "Nothing heard")
        _ = say(.packed, &walk, &lib, heard: "packed it")
        XCTAssertEqual(walk.notUnderstood(), "Sorry?")
        _ = say(.skip, &walk, &lib, heard: nil)
        XCTAssertEqual(walk.understoodLine, "Understood 1 of 2 times · 1 tapped")
        XCTAssertEqual(walk.log.map(VoiceWalk.line),
                       ["Toothbrush · packed · \u{201C}packed it\u{201D}", "Passport · skip · tapped"])
    }
}
