import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Reminders without the kind "Reminders" (0.107 — his words, 30 Oct 2026: "I don't understand why I defined
/// Reminders. I want them gone, because I dont know how to use them"). Once he has taken it off his kinds of thing,
/// the app never brings it back: a reminder made after — on a template, or a trip's own To do — gets his Other, else
/// the app's own catch-all, else the first of his kinds. And a reminder stays a reminder: it is known by its
/// `itemType`, never by its kind. Invented data only — this repository is public.
final class ReminderKindTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-13T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    private let today = "2026-10-13"
    private let withoutReminders = CATEGORIES.filter { $0 != REMINDERS_CATEGORY }

    /// The base template with a Kettle, a workout Rowing, his kinds as given, and the trip "Lake week" (20–24 Oct)
    /// from Rowing.
    private func library(kinds: [String]) -> (Library, base: String, trip: String) {
        var lib = Library()
        var base = newList(name: "Base", role: "base")
        base.items = [newItem(name: "Kettle")]
        lib.saveTemplate(base)
        lib.saveTemplate(newList(name: "Rowing", group: "WET"))
        lib.setCategories(kinds)
        let baseId = lib.templates.first { $0.role == "base" }!.id
        let rowing = lib.templates.first { $0.name == "Rowing" }!.id
        let trip = lib.createTrip(newEvent(name: "Lake week", activities: [rowing], startDate: "2026-10-20", endDate: "2026-10-24")).id
        return (lib, baseId, trip)
    }

    func testAReminderMadeOnceRemindersIsGoneGetsHisOtherAndIsStillAReminder() {
        let kinds = withoutReminders + ["Other"]
        var (lib, base, trip) = library(kinds: kinds)
        XCTAssertNotNil(lib.addReminder(templateId: base, name: "Fill the flask", when: "daybefore"))
        let made = lib.items.first { $0.name == "Fill the flask" }!
        XCTAssertEqual(made.category, "Other", "the kind he removed came back with a new reminder")
        XCTAssertTrue(Library.isReminder(made), "no longer a reminder")
        XCTAssertEqual(lib.reminders(templateId: base).map(\.name), ["Fill the flask"], "no longer its template's reminder")
        XCTAssertFalse(lib.ownThings().contains { $0.id == made.id }, "a template's reminder shows among his things")
        // A trip's own To do too.
        let todo = lib.addTripTodo(tripId: trip, name: "Buy euros", today: today)
        XCTAssertEqual(todo?.category, "Other", "a To do brought the removed kind back")
        XCTAssertTrue(todo.map(Library.isReminder) ?? false, "the To do is no reminder")
        XCTAssertEqual(lib.dueReminders(tripId: trip, today: today).map(\.name), ["Buy euros"], "the To do is not due at once")
        XCTAssertEqual(lib.categories(), kinds, "making a reminder changed his kinds")
        // A new trip carries the template's reminder as a reminder, of the kind it has.
        let next = lib.createTrip(newEvent(name: "Autumn week", startDate: "2026-11-02", endDate: "2026-11-06"))
        let line = next.entries.first { $0.name == "Fill the flask" }
        XCTAssertNotNil(line, "the new trip lost the reminder")
        XCTAssertTrue(line.map(Library.isReminder) ?? false, "on the trip it is no reminder")
        XCTAssertEqual(line?.category, "Other")
    }

    func testWithNoOtherItIsTheAppsOwnCatchAll() {
        var (lib, base, trip) = library(kinds: withoutReminders)
        _ = lib.addReminder(templateId: base, name: "Fill the flask")
        XCTAssertEqual(lib.items.first { $0.name == "Fill the flask" }?.category, CATEGORY_DEFAULT)
        XCTAssertEqual(lib.addTripTodo(tripId: trip, name: "Buy euros", today: today)?.category, CATEGORY_DEFAULT)
    }

    func testWithNeitherItIsTheFirstOfHisKinds() {
        var (lib, base, trip) = library(kinds: ["Gear", "Clothes"])
        _ = lib.addReminder(templateId: base, name: "Fill the flask")
        XCTAssertEqual(lib.items.first { $0.name == "Fill the flask" }?.category, "Gear", "a kind he does not have")
        XCTAssertEqual(lib.addTripTodo(tripId: trip, name: "Buy euros", today: today)?.category, "Gear")
    }

    func testWhileHeHasRemindersAReminderIsReminders() {
        var (lib, base, trip) = library(kinds: CATEGORIES)
        _ = lib.addReminder(templateId: base, name: "Fill the flask")
        XCTAssertEqual(lib.items.first { $0.name == "Fill the flask" }?.category, REMINDERS_CATEGORY)
        XCTAssertEqual(lib.addTripTodo(tripId: trip, name: "Buy euros", today: today)?.category, REMINDERS_CATEGORY)
        // His own list with Reminders on it: still Reminders, spelt as his list spells it.
        lib.setCategories(["Gear", "reminders", "Other"])
        _ = lib.addReminder(templateId: base, name: "Wax the skis")
        XCTAssertEqual(lib.items.first { $0.name == "Wax the skis" }?.category, "reminders")
    }
}
